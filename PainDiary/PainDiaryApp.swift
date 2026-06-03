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

        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!

        func storeLoeschen() {
            for name in ["default.store", "default.store-shm", "default.store-wal",
                         "PainDiaryLocal.store", "PainDiaryLocal.store-shm", "PainDiaryLocal.store-wal"] {
                try? FileManager.default.removeItem(at: appSupport.appendingPathComponent(name))
            }
        }

        let cloudConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false,
                                             cloudKitDatabase: .automatic)
        let lokalConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        // Versuch 1: Mit iCloud
        if let c = try? ModelContainer(for: schema, configurations: [cloudConfig]) { return c }

        // Versuch 2: Lokalen Store löschen, nochmals mit iCloud
        storeLoeschen()
        if let c = try? ModelContainer(for: schema, configurations: [cloudConfig]) { return c }

        // Versuch 3: Ohne iCloud (lokaler Store)
        if let c = try? ModelContainer(for: schema, configurations: [lokalConfig]) { return c }

        // Versuch 4: Lokalen Store löschen, ohne iCloud
        storeLoeschen()
        if let c = try? ModelContainer(for: schema, configurations: [lokalConfig]) { return c }

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
