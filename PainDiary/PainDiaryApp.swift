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
    // CloudKit-compatible models: no required relationships, all attributes defaulted.
    let hauptdatenTypen: [any PersistentModel.Type] = [
        PainEntry.self,
        Dauermedikation.self,
        EinnahmeLog.self,
        MIDASBewertung.self,
        ZyklusEintrag.self
    ]
    // Profile models have to-many relationships that CoreData marks as non-optional,
    // which CloudKit rejects. Store them local-only to avoid the conflict.
    let profilTypen: [any PersistentModel.Type] = [
        Benutzerprofil.self,
        Diagnose.self,
        Allergie.self,
        ArztKontakt.self,
        NotfallKontakt.self
    ]

    let hauptdatenSchema = Schema(hauptdatenTypen)
    let profilSchema     = Schema(profilTypen)
    let vollSchema       = Schema(hauptdatenTypen + profilTypen)

    let appSupport = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!

    // "hauptdaten" config keeps default.store URL for backward compatibility.
    // "profil" config uses a separate profil.store, local-only.
    func makeHauptdaten(cloudKit: Bool) -> ModelConfiguration {
        ModelConfiguration(
            "hauptdaten",
            schema: hauptdatenSchema,
            url: appSupport.appendingPathComponent("default.store"),
            isStoredInMemoryOnly: false,
            cloudKitDatabase: cloudKit ? .automatic : .none
        )
    }
    let profilKonfig = ModelConfiguration(
        "profil",
        schema: profilSchema,
        isStoredInMemoryOnly: false,
        cloudKitDatabase: .none
    )

    func tryMake(cloudKit: Bool) -> ModelContainer? {
        var container: ModelContainer?
        let exception = catchObjCException {
            container = try? ModelContainer(
                for: vollSchema,
                configurations: [makeHauptdaten(cloudKit: cloudKit), profilKonfig]
            )
        }
        return exception == nil ? container : nil
    }

    // Stufe 1: Hauptdaten mit iCloud, Profil lokal
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
    return try! ModelContainer(for: vollSchema, configurations: [
        ModelConfiguration("hauptdaten", schema: hauptdatenSchema,
                           isStoredInMemoryOnly: true, cloudKitDatabase: .none),
        ModelConfiguration("profil",     schema: profilSchema,
                           isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    ])
}
