import SwiftUI
import SwiftData

@main
struct PainDiaryApp: App {
    @State private var container: ModelContainer? = nil
    // Initialize early so UNUserNotificationCenter.delegate is set before iOS delivers
    // the pending notification response on cold launch.
    private let _notif = NotificationManager.shared

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
                let c = makeContainer()
                container = c
                await berechtigungenAnfordern()
                await planeAlleErinnerungen(container: c)
            }
        }
    }

    private func berechtigungenAnfordern() async {
        _ = await NotificationManager.shared.berechtigungAnfordern()
    }

    // Re-schedules all notifications after install/update/relaunch
    @MainActor
    private func planeAlleErinnerungen(container: ModelContainer) async {
        let notif = NotificationManager.shared
        guard notif.status == .authorized else { return }

        // Medikament-Erinnerungen
        let context = ModelContext(container)
        let medikamente = (try? context.fetch(FetchDescriptor<Dauermedikation>())) ?? []
        for med in medikamente {
            notif.planeErinnerungen(fuer: med)
            notif.planeAblaufWarnung(fuer: med)
        }

        // Tages-Erinnerung
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "tagesErinnerungAktiv") {
            let sek = defaults.double(forKey: "tagesErinnerungZeit")
            let zeit = Date(timeIntervalSinceReferenceDate: sek > 0 ? sek : 28800)
            let dc = Calendar.current.dateComponents([.hour, .minute], from: zeit)
            notif.planeTagesErinnerung(stunde: dc.hour ?? 8, minute: dc.minute ?? 0)
        }

        // Wasser-Erinnerung
        if defaults.bool(forKey: "wasserErinnerungAktiv") {
            let sek = defaults.double(forKey: "wasserErinnerungZeit")
            let zeit = Date(timeIntervalSinceReferenceDate: sek > 0 ? sek : 54000)
            let dc = Calendar.current.dateComponents([.hour, .minute], from: zeit)
            notif.planeWasserErinnerung(stunde: dc.hour ?? 15, minute: dc.minute ?? 0)
        }
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
        NotfallKontakt.self,
        Laborwert.self,
        Arztbesuch.self,
        HAQEintrag.self,
        Impftermin.self,
        BiologikaInjektion.self,
        KortisonEintrag.self,
        FACITEintrag.self,
        PhysioSession.self,
        Remissionsphase.self,
        MigraeneEintrag.self,
        BlutzuckerEintrag.self,
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
