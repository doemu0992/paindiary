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
            Dauermedikation.self,
            EinnahmeLog.self,
            MIDASBewertung.self,
            ZyklusEintrag.self,
            TagesWohlbefinden.self
        ])

        // iCloud-Sync reaktiviert. stressLevel ist jetzt Int? (optional) für CloudKit-Kompatibilität.
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false,
                                        cloudKitDatabase: .automatic)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Schema-Migration fehlgeschlagen — lokalen Store löschen und neu starten.
            // CloudKit-Daten bleiben erhalten und werden nach dem Neustart synchronisiert.
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            for name in ["default.store", "default.store-shm", "default.store-wal",
                         "PainDiaryLocal.store", "PainDiaryLocal.store-shm", "PainDiaryLocal.store-wal"] {
                try? FileManager.default.removeItem(at: appSupport.appendingPathComponent(name))
            }
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("ModelContainer konnte nicht erstellt werden: \(error)")
            }
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
        // HealthKit authorization is requested only from WellnessView (user-initiated).
        // Calling requestAuthorization without the HealthKit entitlement throws an
        // NSException that bypasses Swift catch and crashes the app on launch.
    }
}
