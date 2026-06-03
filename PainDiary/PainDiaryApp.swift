import SwiftUI
import SwiftData

@main
struct PainDiaryApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            PainEntry.self,
            Benutzerprofil.self,
            Diagnose.self,
            Allergie.self,
            ArztKontakt.self,
            NotfallKontakt.self,
            Dauermedikation.self
        ])

        // iCloud-Sync aktivieren:
        // 1. Xcode → Signing & Capabilities → + Capability → iCloud → CloudKit aktivieren
        // 2. CloudKit-Container anlegen (z.B. iCloud.com.deinname.paindiary)
        // 3. Diese Zeile einkommentieren + die lokale config auskommentieren:
        // let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .automatic)

        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("ModelContainer konnte nicht erstellt werden: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task { await berechtigungenAnfordern() }
        }
        .modelContainer(sharedModelContainer)
    }

    private func berechtigungenAnfordern() async {
        _ = await NotificationManager.shared.berechtigungAnfordern()

        // HealthKit aktivieren — erst Info.plist Einträge setzen:
        //   NSHealthShareUsageDescription = "Schlafstunden aus Apple Health übernehmen"
        // Dann einkommentieren:
        // await HealthKitManager.shared.berechtigungAnfordern()
    }
}
