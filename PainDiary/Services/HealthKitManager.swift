import Foundation
import HealthKit
import Observation

@Observable
class HealthKitManager {
    static let shared = HealthKitManager()

    private let store = HKHealthStore()
    var isVerfuegbar: Bool { HKHealthStore.isHealthDataAvailable() }
    var istAutorisiert = false

    private var leseTypen: Set<HKObjectType> {
        var types = Set<HKObjectType>()
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) {
            types.insert(steps)
        }
        return types
    }

    func berechtigungAnfordern() async {
        guard isVerfuegbar else { return }
        do {
            try await store.requestAuthorization(toShare: [], read: leseTypen)
            await MainActor.run { istAutorisiert = true }
        } catch {
            print("HealthKit Fehler: \(error)")
        }
    }

    func schlafStundenLetztteNacht() async -> Double? {
        guard isVerfuegbar,
              let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }

        let kal = Calendar.current
        let heuteStart = kal.startOfDay(for: Date())
        let gesternStart = kal.date(byAdding: .day, value: -1, to: heuteStart)!

        let predicate = HKQuery.predicateForSamples(
            withStart: gesternStart,
            end: Date(),
            options: .strictEndDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: nil)
                    return
                }
                let schlafen = samples.filter {
                    $0.value != HKCategoryValueSleepAnalysis.inBed.rawValue
                }
                let sek = schlafen.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                let std = sek / 3600
                continuation.resume(returning: std > 0.5 ? min(std, 14) : nil)
            }
            self.store.execute(query)
        }
    }

    func schritteDiesemTag() async -> Int? {
        guard isVerfuegbar,
              let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return nil }

        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(
            withStart: start, end: Date(), options: .strictEndDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepsType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                let summe = result?.sumQuantity()?.doubleValue(for: .count())
                continuation.resume(returning: summe.map { Int($0) })
            }
            self.store.execute(query)
        }
    }
}
