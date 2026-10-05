import Foundation
import SwiftData
import os

/// Zustand der Datenhaltung. Wird dem Nutzer sichtbar gemacht, damit nie unbemerkt
/// „im Speicher" gearbeitet wird.
enum StoreStatus: Equatable {
    /// Lokaler Store mit iCloud-Sync.
    case cloud
    /// Lokaler Store ohne Sync (`cloudFehler`: Grund, falls der Sync nicht aktiviert werden konnte).
    case lokal(cloudFehler: String?)
    /// Der Store ließ sich nicht öffnen. Die App läuft **ohne Persistenz**, die Dateien bleiben unverändert.
    case notfall(grund: String)
    /// Nicht einmal der Notfall-Container ließ sich erstellen.
    case unbrauchbar(grund: String)

    var istNotfall: Bool {
        switch self {
        case .notfall, .unbrauchbar: return true
        default: return false
        }
    }
}

struct PersistenceResult {
    let container: ModelContainer?
    let status: StoreStatus
}

/// Öffnet den SwiftData-Store sicher.
///
/// Grundsätze:
/// 1. **Nie Daten löschen.** Schlägt das Öffnen fehl, bleiben die Store-Dateien unverändert.
/// 2. Vor dem ersten Öffnen einer neuen App-Version wird eine Sicherungskopie angelegt.
/// 3. Der Notfall-Modus (ohne Persistenz) wird dem Nutzer immer angezeigt.
@MainActor
enum PersistenceController {
    static let logger = Logger(subsystem: "com.doemu0992.paindiary", category: "persistence")
    private static let storeName = "default.store"
    private static let storeDateien = ["default.store", "default.store-shm", "default.store-wal"]
    private static let maxSnapshots = 3

    static let alleTypen: [any PersistentModel.Type] = [
        PainEntry.self, Dauermedikation.self, EinnahmeLog.self, MIDASBewertung.self,
        ZyklusEintrag.self, Benutzerprofil.self, Diagnose.self, Allergie.self,
        ArztKontakt.self, NotfallKontakt.self, Laborwert.self, Arztbesuch.self,
        HAQEintrag.self, Impftermin.self, BiologikaInjektion.self, KortisonEintrag.self,
        FACITEintrag.self, PhysioSession.self, Remissionsphase.self, MigraeneEintrag.self,
        BlutzuckerEintrag.self, WellnessEintrag.self,
    ]

    static var applicationSupport: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    }

    /// Einstellung „iCloud-Synchronisierung" (Standard: an, wie bisher). Änderung wirkt nach App-Neustart.
    static let iCloudSyncKey = "iCloudSyncAktiv"
    static var iCloudSyncGewuenscht: Bool {
        UserDefaults.standard.object(forKey: iCloudSyncKey) as? Bool ?? true
    }

    static var storeURL: URL? { applicationSupport?.appendingPathComponent(storeName) }

    /// Vorhandene Store-Dateien (für Export/Support).
    static var vorhandeneStoreDateien: [URL] {
        guard let dir = applicationSupport else { return [] }
        return storeDateien
            .map { dir.appendingPathComponent($0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    // MARK: - Öffnen

    static func oeffne() -> PersistenceResult {
        let schema = Schema(alleTypen)

        guard let dir = applicationSupport, let url = storeURL else {
            return notfall(schema: schema, grund: "Kein Speicherort verfügbar")
        }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        sichereStoreVorStart(in: dir)

        var cloudFehler: String? = nil
        if iCloudSyncGewuenscht {
            let cloud = ModelConfiguration("hauptdaten", schema: schema, url: url, cloudKitDatabase: .automatic)
            do {
                let c = try ModelContainer(for: schema, configurations: [cloud])
                logger.info("Store geöffnet (iCloud-Sync)")
                return PersistenceResult(container: c, status: .cloud)
            } catch {
                cloudFehler = error.localizedDescription
                logger.error("Cloud-Store fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
            }
        }

        let lokal = ModelConfiguration("hauptdaten", schema: schema, url: url, cloudKitDatabase: .none)
        do {
            let c = try ModelContainer(for: schema, configurations: [lokal])
            logger.info("Store geöffnet (lokal)")
            return PersistenceResult(container: c, status: .lokal(cloudFehler: cloudFehler))
        } catch {
            logger.error("Lokaler Store fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
            // WICHTIG: keine Dateien löschen. Der Nutzer entscheidet (Wiederherstellung / Support).
            return notfall(schema: schema, grund: error.localizedDescription)
        }
    }

    private static func notfall(schema: Schema, grund: String) -> PersistenceResult {
        do {
            let mem = ModelConfiguration("notfall", schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            let c = try ModelContainer(for: schema, configurations: [mem])
            return PersistenceResult(container: c, status: .notfall(grund: grund))
        } catch {
            logger.fault("Notfall-Container fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
            return PersistenceResult(container: nil, status: .unbrauchbar(grund: error.localizedDescription))
        }
    }

    // MARK: - Sicherungskopien

    static var snapshotOrdner: URL? {
        applicationSupport?.appendingPathComponent("StoreBackups", isDirectory: true)
    }

    /// Kopiert den Store einmal pro App-Build vor dem Öffnen (schützt vor fehlgeschlagenen Migrationen).
    static func sichereStoreVorStart(in dir: URL) {
        let fm = FileManager.default
        let defaults = UserDefaults.standard
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        let schluessel = "storeSnapshotBuild"
        guard defaults.string(forKey: schluessel) != build else { return }

        let quellen = storeDateien
            .map { dir.appendingPathComponent($0) }
            .filter { fm.fileExists(atPath: $0.path) }
        guard !quellen.isEmpty, let basis = snapshotOrdner else {
            defaults.set(build, forKey: schluessel)   // nichts zu sichern (Erstinstallation)
            return
        }

        let groesse = quellen.reduce(Int64(0)) { summe, u in
            summe + Int64((try? u.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        // Nicht kopieren, wenn der Speicher knapp wird (Backup darf die App nicht blockieren)
        if let frei = try? dir.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            .volumeAvailableCapacityForImportantUsage, frei < groesse * 3 {
            logger.error("Snapshot übersprungen: zu wenig freier Speicher")
            return
        }

        let stempel = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let ziel = basis.appendingPathComponent("build\(build)-\(stempel)", isDirectory: true)
        do {
            try fm.createDirectory(at: ziel, withIntermediateDirectories: true)
            for q in quellen { try fm.copyItem(at: q, to: ziel.appendingPathComponent(q.lastPathComponent)) }
            defaults.set(build, forKey: schluessel)
            raeumeSnapshotsAuf(in: basis)
            logger.info("Snapshot erstellt: \(ziel.lastPathComponent, privacy: .public)")
        } catch {
            logger.error("Snapshot fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
            try? fm.removeItem(at: ziel)
        }
    }

    private static func raeumeSnapshotsAuf(in basis: URL) {
        let fm = FileManager.default
        guard let inhalt = try? fm.contentsOfDirectory(at: basis, includingPropertiesForKeys: [.creationDateKey]) else { return }
        let sortiert = inhalt.sorted {
            let a = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            let b = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return a > b
        }
        for alt in sortiert.dropFirst(maxSnapshots) { try? fm.removeItem(at: alt) }
    }

    /// Vorhandene Snapshots (neueste zuerst) für Support/Wiederherstellung.
    static func snapshots() -> [URL] {
        guard let basis = snapshotOrdner,
              let inhalt = try? FileManager.default.contentsOfDirectory(at: basis, includingPropertiesForKeys: [.creationDateKey])
        else { return [] }
        return inhalt.sorted {
            let a = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            let b = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return a > b
        }
    }
}
