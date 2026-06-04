import SwiftUI
import SwiftData

@main
struct PainDiaryApp: App {
    var sharedModelContainer: ModelContainer = makeContainer()

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

private func makeContainer() -> ModelContainer {
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

    // Stufe 1: iCloud + lokaler Store (Normalfall)
    if let c = try? ModelContainer(for: schema, configurations: [
        ModelConfiguration(schema: schema, isStoredInMemoryOnly: false,
                           cloudKitDatabase: .automatic)
    ]) { return c }

    // Stufe 2: Korrupte Stores löschen und ohne iCloud neu starten
    let appSupport = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    for name in ["default.store", "default.store-shm", "default.store-wal"] {
        try? FileManager.default.removeItem(at: appSupport.appendingPathComponent(name))
    }
    if let c = try? ModelContainer(for: schema, configurations: [
        ModelConfiguration(schema: schema, isStoredInMemoryOnly: false,
                           cloudKitDatabase: .automatic)
    ]) { return c }

    // Stufe 3: Lokal ohne iCloud
    if let c = try? ModelContainer(for: schema, configurations: [
        ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
    ]) { return c }

    // Stufe 4: In-Memory — App startet immer
    return try! ModelContainer(for: schema,
                               configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
}
