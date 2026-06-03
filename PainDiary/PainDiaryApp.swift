import SwiftUI
import SwiftData

@main
struct PainDiaryApp: App {
    var sharedModelContainer: ModelContainer = {
        // Schema identisch mit Stand vor der Health-Integration (d90330c).
        // TagesWohlbefinden ist NICHT im Schema — WellnessView nutzt UserDefaults.
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
            ZyklusEintrag.self
        ])

        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false,
                                        cloudKitDatabase: .automatic)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Korrupten Store löschen und nochmals versuchen
            let appSupport = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            for name in ["default.store", "default.store-shm", "default.store-wal",
                         "PainDiaryLocal.store", "PainDiaryLocal.store-shm", "PainDiaryLocal.store-wal"] {
                try? FileManager.default.removeItem(at: appSupport.appendingPathComponent(name))
            }
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                // Absoluter Notfall: In-Memory, App startet immer
                return try! ModelContainer(for: schema,
                                           configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
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
        // HealthKit wird nur auf expliziten Nutzer-Wunsch angefragt (nie beim Start)
    }
}
