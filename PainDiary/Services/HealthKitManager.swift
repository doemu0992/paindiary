import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

class HealthKitManager {
    static let shared = HealthKitManager()
    private init() {}

    var istVerfuegbar: Bool {
        #if canImport(HealthKit)
        return HKHealthStore.isHealthDataAvailable()
        #else
        return false
        #endif
    }

    #if canImport(HealthKit)
    private let store = HKHealthStore()
    #endif

    func berechtigungAnfordern() async {
        #if canImport(HealthKit)
        guard istVerfuegbar else { return }
        guard let schrittTyp = HKQuantityType.quantityType(forIdentifier: .stepCount),
              let schlafTyp = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        try? await store.requestAuthorization(toShare: [], read: [schrittTyp, schlafTyp])
        #endif
    }

    func schlafStundenLetztteNacht() async -> Double? {
        #if canImport(HealthKit)
        guard istVerfuegbar else { return nil }
        guard let schlafTyp = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let kal = Calendar.current
        let heute = kal.startOfDay(for: Date())
        let gestern = kal.date(byAdding: .day, value: -1, to: heute)!
        let predicate = HKQuery.predicateForSamples(withStart: gestern, end: Date())
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: schlafTyp, predicate: predicate,
                                      limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: nil); return
                }
                let sek = samples
                    .filter { $0.value != HKCategoryValueSleepAnalysis.inBed.rawValue }
                    .map { $0.endDate.timeIntervalSince($0.startDate) }
                    .reduce(0, +)
                continuation.resume(returning: sek > 0 ? sek / 3600 : nil)
            }
            store.execute(query)
        }
        #else
        return nil
        #endif
    }

    func schritteDiesemTag() async -> Int? {
        #if canImport(HealthKit)
        guard istVerfuegbar else { return nil }
        guard let schrittTyp = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return nil }
        let kal = Calendar.current
        let heute = kal.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: heute, end: Date())
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: schrittTyp,
                                          quantitySamplePredicate: predicate,
                                          options: .cumulativeSum) { _, stats, _ in
                guard let sum = stats?.sumQuantity() else {
                    continuation.resume(returning: nil); return
                }
                continuation.resume(returning: Int(sum.doubleValue(for: .count())))
            }
            store.execute(query)
        }
        #else
        return nil
        #endif
    }
}
