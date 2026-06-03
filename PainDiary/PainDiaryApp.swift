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

        // CloudKit removed: schema changes (stressLevel, TagesWohlbefinden) are
        // incompatible with the existing CloudKit container and cause a fatalError
        // on first launch. Local SwiftData handles lightweight migration automatically.
        // "PainDiaryLocal" name avoids conflicts with the old default CloudKit store.
        let config = ModelConfiguration("PainDiaryLocal", schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Migration failed — delete the corrupt store and start fresh
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            for name in ["PainDiaryLocal.store", "PainDiaryLocal.store-shm", "PainDiaryLocal.store-wal",
                         "default.store", "default.store-shm", "default.store-wal"] {
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
