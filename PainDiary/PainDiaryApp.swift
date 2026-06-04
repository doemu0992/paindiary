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
            ZyklusEintrag.self
        ])

        // 1. Try CloudKit — wrapped in ObjC @try/@catch because
        //    NSPersistentCloudKitContainer throws NSException (not Swift.Error),
        //    which bypasses do/catch and crashes the app.
        let cloudConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false,
                                             cloudKitDatabase: .automatic)
        var container: ModelContainer? = nil
        let cloudException = catchObjCException {
            container = try? ModelContainer(for: schema, configurations: [cloudConfig])
        }
        if cloudException == nil, let c = container {
            return c
        }

        // 2. CloudKit failed — delete corrupt local stores and try local-only.
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        for name in ["default.store", "default.store-shm", "default.store-wal",
                     "PainDiaryLocal.store", "PainDiaryLocal.store-shm", "PainDiaryLocal.store-wal"] {
            try? FileManager.default.removeItem(at: appSupport.appendingPathComponent(name))
        }
        var localContainer: ModelContainer? = nil
        _ = catchObjCException {
            localContainer = try? ModelContainer(for: schema,
                                                 configurations: [ModelConfiguration(schema: schema,
                                                                                     isStoredInMemoryOnly: false)])
        }
        if let c = localContainer { return c }

        // 3. Absolute last resort — in-memory. App always starts.
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
