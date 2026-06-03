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

        // CloudKit ist hier bewusst NICHT aktiviert.
        // cloudKitDatabase: .automatic wirft bei Schemainkompatibilität eine
        // NSException (Objective-C), die Swift-try/catch nicht fängt → Crash.
        // iCloud-Sync kann nach einem stabilen Release gezielt reaktiviert werden.
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!

        func storeLoeschen() {
            for name in ["default.store", "default.store-shm", "default.store-wal",
                         "PainDiaryLocal.store", "PainDiaryLocal.store-shm", "PainDiaryLocal.store-wal"] {
                try? FileManager.default.removeItem(at: appSupport.appendingPathComponent(name))
            }
        }

        // Versuch 1: Normaler Start
        if let c = try? ModelContainer(for: schema, configurations: [config]) { return c }

        // Versuch 2: Korrupten Store löschen und nochmals versuchen
        storeLoeschen()
        if let c = try? ModelContainer(for: schema, configurations: [config]) { return c }

        // Notfall: In-Memory — App startet immer, Daten werden nicht gespeichert
        return try! ModelContainer(for: schema,
                                   configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
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
    }
}
