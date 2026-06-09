import SwiftUI
import SwiftData

@main
struct PainDiaryApp: App {
    @State private var container: ModelContainer? = nil

    var body: some Scene {
        WindowGroup {
            Group {
                if let container {
                    ContentView()
                        .modelContainer(container)
                } else {
                    Color.clear
                }
            }
            .task {
                guard container == nil else { return }
                container = makeContainer()
                await berechtigungenAnfordern()
            }
        }
    }

    private func berechtigungenAnfordern() async {
        _ = await NotificationManager.shared.berechtigungAnfordern()
    }
}

@MainActor
private func makeContainer() -> ModelContainer {
    let alleTypen: [any PersistentModel.Type] = [
        PainEntry.self,
        Dauermedikation.self,
        EinnahmeLog.self,
        MIDASBewertung.self,
        ZyklusEintrag.self,
        Benutzerprofil.self,
        Diagnose.self,
        Allergie.self,
        ArztKontakt.self,
        NotfallKontakt.self
    ]
    let schema = Schema(alleTypen)

    guard let appSupport = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
        return try! ModelContainer(for: schema, configurations: [
            ModelConfiguration("hauptdaten", schema: schema,
                               isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        ])
    }

    func makeConfig(cloudKit: Bool) -> ModelConfiguration {
        ModelConfiguration(
            "hauptdaten",
            schema: schema,
            url: appSupport.appendingPathComponent("default.store"),
            cloudKitDatabase: cloudKit ? .automatic : .none
        )
    }

    func tryMake(cloudKit: Bool) -> ModelContainer? {
        var container: ModelContainer?
        let exception = catchObjCException {
            container = try? ModelContainer(for: schema, configurations: [makeConfig(cloudKit: cloudKit)])
        }
        return exception == nil ? container : nil
    }

    // Stufe 1: Alles mit iCloud
    if let c = tryMake(cloudKit: true) { return c }

    // Stufe 2: Alles lokal, Daten bleiben erhalten
    if let c = tryMake(cloudKit: false) { return c }

    // Stufe 3: Alte Stores löschen + neu starten
    for name in ["default.store", "default.store-shm", "default.store-wal",
                 "profil.store",  "profil.store-shm",  "profil.store-wal"] {
        try? FileManager.default.removeItem(at: appSupport.appendingPathComponent(name))
    }
    if let c = tryMake(cloudKit: true)  { return c }
    if let c = tryMake(cloudKit: false) { return c }

    // Stufe 5: In-Memory — App startet immer
    return try! ModelContainer(for: schema, configurations: [
        ModelConfiguration("hauptdaten", schema: schema,
                           isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    ])
}
