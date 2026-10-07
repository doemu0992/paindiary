import CloudKit
import Foundation
import Observation
import UIKit

/// Partner-Sharing des Zyklus über CloudKit-Sharing (CKShare).
///
/// - Besitzerin/Besitzer: legt eine eigene Record-Zone mit **einem** Snapshot-Record an (alle Zyklus-Einträge als JSON,
///   gleiches Format wie das Backup) und teilt sie per `UICloudSharingController`. Bei jeder Änderung wird der Snapshot aktualisiert.
/// - Partner:in: nimmt die Einladung an (`annehmen`) und liest den Snapshot aus der Shared-Database (nur lesen).
///
/// Die geteilten Daten liegen ausschließlich in iCloud der beteiligten Personen. Teilen lässt sich jederzeit beenden.
struct ZyklusPartnerPayload: Codable {
    var stand: Date
    var pausiert: Bool
    var eintraege: [BackupService.ZyklusDTO]
}

@MainActor
@Observable
final class ZyklusPartnerService {
    static let shared = ZyklusPartnerService()

    static let containerID = "iCloud.DG-Software-Solution.PainDiary"
    private static let zoneName = "ZyklusPartner"
    private static let recordType = "ZyklusSnapshot"
    private static let recordName = "snapshot"
    private static let aktivKey = "zyklusPartnerGeteilt"

    let container = CKContainer(identifier: ZyklusPartnerService.containerID)
    private var privat: CKDatabase { container.privateCloudDatabase }
    private var geteilt: CKDatabase { container.sharedCloudDatabase }

    /// Besitzerseite: es existiert eine Freigabe.
    var teiltAktiv: Bool {
        didSet { UserDefaults.standard.set(teiltAktiv, forKey: Self.aktivKey) }
    }
    /// Partnerseite: zuletzt geladener Stand.
    var empfangen: ZyklusPartnerPayload?
    var laedt = false
    var meldung: String?

    private var syncTask: Task<Void, Never>?

    private init() {
        teiltAktiv = UserDefaults.standard.bool(forKey: Self.aktivKey)
    }

    private var zoneID: CKRecordZone.ID { CKRecordZone.ID(zoneName: Self.zoneName) }
    private var recordID: CKRecord.ID { CKRecord.ID(recordName: Self.recordName, zoneID: zoneID) }

    // MARK: - Besitzerseite

    private func payloadDatei(_ eintraege: [ZyklusEintrag], pausiert: Bool) throws -> URL {
        let payload = ZyklusPartnerPayload(
            stand: Date(), pausiert: pausiert,
            eintraege: eintraege.map { BackupService.ZyklusDTO($0) })
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("zyklus-partner-\(UUID().uuidString).json")
        try enc.encode(payload).write(to: url, options: .atomic)
        return url
    }

    private func setzeDaten(_ record: CKRecord, eintraege: [ZyklusEintrag]) throws {
        let pausiert = UserDefaults.standard.bool(forKey: "zyklusPrognosenPausiert")
        record["daten"] = CKAsset(fileURL: try payloadDatei(eintraege, pausiert: pausiert))
        record["stand"] = Date() as NSDate
    }

    /// Vorhandene Freigabe (zum Verwalten der Teilnehmer) oder nil.
    func vorhandeneFreigabe() async -> CKShare? {
        guard let record = try? await privat.record(for: recordID), let ref = record.share else { return nil }
        return (try? await privat.record(for: ref.recordID)) as? CKShare
    }

    /// Legt Zone, Snapshot und Freigabe an (idempotent) und liefert die Freigabe zum Einladen.
    func erstelleFreigabe(eintraege: [ZyklusEintrag]) async throws -> CKShare {
        _ = try await privat.save(CKRecordZone(zoneID: zoneID))

        let record = (try? await privat.record(for: recordID))
            ?? CKRecord(recordType: Self.recordType, recordID: recordID)
        try setzeDaten(record, eintraege: eintraege)

        if let ref = record.share, let share = (try? await privat.record(for: ref.recordID)) as? CKShare {
            _ = try await privat.modifyRecords(saving: [record], deleting: [])
            teiltAktiv = true
            return share
        }

        let share = CKShare(rootRecord: record)
        share[CKShare.SystemFieldKey.title] = "Mein Zyklus" as CKRecordValue
        share.publicPermission = .none
        let ergebnis = try await privat.modifyRecords(saving: [record, share], deleting: [])
        for (_, r) in ergebnis.saveResults {
            if case .failure(let fehler) = r { throw fehler }
        }
        teiltAktiv = true
        return share
    }

    /// Nach jeder Änderung: Snapshot aktualisieren (entprellt). Ohne aktive Freigabe passiert nichts.
    func synchronisieren(eintraege: [ZyklusEintrag]) {
        guard teiltAktiv else { return }
        syncTask?.cancel()
        syncTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, let self else { return }
            do {
                guard let record = try? await self.privat.record(for: self.recordID) else { return }
                try self.setzeDaten(record, eintraege: eintraege)
                _ = try await self.privat.modifyRecords(saving: [record], deleting: [], savePolicy: .changedKeys)
            } catch {
                self.meldung = "Partner-Sync fehlgeschlagen: \(error.localizedDescription)"
            }
        }
    }

    /// Beendet das Teilen: löscht die Zone samt Freigabe in iCloud.
    func teilenBeenden() async {
        do {
            _ = try await privat.deleteRecordZone(withID: zoneID)
            teiltAktiv = false
        } catch {
            meldung = "Teilen konnte nicht beendet werden: \(error.localizedDescription)"
        }
    }

    // MARK: - Partnerseite

    func annehmen(_ metadata: CKShare.Metadata) async {
        do {
            _ = try await container.accept(metadata)
            meldung = "Einladung angenommen. Der geteilte Zyklus ist jetzt unter Profil verfügbar."
            await laden()
        } catch {
            meldung = "Einladung konnte nicht angenommen werden: \(error.localizedDescription)"
        }
    }

    func laden() async {
        laedt = true
        defer { laedt = false }
        do {
            let zonen = try await geteilt.allRecordZones()
            var neuester: ZyklusPartnerPayload?
            for zone in zonen where zone.zoneID.zoneName == Self.zoneName {
                let id = CKRecord.ID(recordName: Self.recordName, zoneID: zone.zoneID)
                guard let record = try? await geteilt.record(for: id),
                      let url = (record["daten"] as? CKAsset)?.fileURL,
                      let daten = try? Data(contentsOf: url) else { continue }
                let dec = JSONDecoder()
                dec.dateDecodingStrategy = .iso8601
                if let p = try? dec.decode(ZyklusPartnerPayload.self, from: daten),
                   neuester == nil || p.stand > neuester!.stand { neuester = p }
            }
            empfangen = neuester
        } catch {
            meldung = "Geteilter Zyklus konnte nicht geladen werden: \(error.localizedDescription)"
        }
    }
}

// MARK: - Einladung annehmen (Szenen-Delegate)

final class PartnerAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let konfig = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        konfig.delegateClass = PartnerSceneDelegate.self
        return konfig
    }
}

final class PartnerSceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene,
                     userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        Task { @MainActor in await ZyklusPartnerService.shared.annehmen(cloudKitShareMetadata) }
    }
}
