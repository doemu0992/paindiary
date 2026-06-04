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

    // ModelConfiguration() defaults to cloudKitDatabase: .automatic, so
    // every fallback stage must specify .none explicitly to avoid CloudKit
    // schema validation on local/in-memory stores.
    func tryMake(_ config: ModelConfiguration) -> ModelContainer? {
        var container: ModelContainer?
        let exception = catchObjCException {
            container = try? ModelContainer(for: schema, configurations: [config])
        }
        return exception == nil ? container : nil
    }

    let withCloud = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false,
                                       cloudKitDatabase: .automatic)
    let localOnly = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false,
                                       cloudKitDatabase: .none)

    // Stufe 1: Mit iCloud — normaler Betrieb, Daten bleiben erhalten
    if let c = tryMake(withCloud) { return c }

    // Stufe 2: Ohne iCloud, aber lokale Daten bleiben erhalten
    if let c = tryMake(localOnly) { return c }

    // Stufe 3: Lokalen Store löschen (korrupt) + mit iCloud neu starten
    let appSupport = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    for name in ["default.store", "default.store-shm", "default.store-wal"] {
        try? FileManager.default.removeItem(at: appSupport.appendingPathComponent(name))
    }
    if let c = tryMake(withCloud) { return c }

    // Stufe 4: Neuer lokaler Store ohne iCloud
    if let c = tryMake(localOnly) { return c }

    // Stufe 5: In-Memory — App startet immer
    return try! ModelContainer(for: schema, configurations: [
        ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    ])
}
