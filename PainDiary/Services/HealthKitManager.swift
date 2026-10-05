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

    /// Schlafdauer der letzten Nacht (gestern 18:00 – heute 12:00, Ortszeit).
    /// Zählt nur echte Schlafphasen (keine „im Bett"/„wach"-Segmente) und vereinigt überlappende
    /// Segmente mehrerer Quellen (iPhone + Apple Watch), damit nichts doppelt gezählt wird.
    func schlafStundenLetztteNacht() async -> Double? {
        #if canImport(HealthKit)
        guard istVerfuegbar else { return nil }
        guard let schlafTyp = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let fenster = SchlafAggregator.nachtFenster()
        let predicate = HKQuery.predicateForSamples(withStart: fenster.von, end: fenster.bis, options: [])
        let schlafWerte: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ]
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: schlafTyp, predicate: predicate,
                                      limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                guard error == nil, let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: nil); return
                }
                let segmente = samples
                    .filter { schlafWerte.contains($0.value) }
                    .map { SchlafSegment(start: max($0.startDate, fenster.von), ende: min($0.endDate, fenster.bis)) }
                let stunden = SchlafAggregator.stunden(aus: segmente)
                continuation.resume(returning: stunden > 0 ? stunden : nil)
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
