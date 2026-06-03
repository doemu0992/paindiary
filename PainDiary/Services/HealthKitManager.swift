import Foundation

// HealthKit entfernt — wird ohne das HealthKit-Entitlement nicht benötigt.
// Alle Methoden geben nil zurück.
class HealthKitManager {
    static let shared = HealthKitManager()
    private init() {}

    func berechtigungAnfordern() async {}
    func schlafStundenLetztteNacht() async -> Double? { nil }
    func schritteDiesemTag() async -> Int? { nil }
}
