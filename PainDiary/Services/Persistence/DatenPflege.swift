import Foundation
import SwiftData
import os

/// Idempotente Datenpflege beim App-Start: Backfill neuer Felder und Bereinigung von Duplikaten.
/// Läuft nur auf einem echten Store (nicht im Notfall-Modus) und verändert nie Nutzerinhalte,
/// außer beim Zusammenführen echter Duplikate (gleicher Tag, gleiche Entität).
@MainActor
enum DatenPflege {
    private static let logger = Logger(subsystem: "com.doemu0992.paindiary", category: "datenpflege")
    private static let versionKey = "datenPflegeVersion"
    static let aktuelleVersion = 1

    struct Bericht: Equatable {
        var artGesetzt = 0
        var zeitzonenGesetzt = 0
        var logsVerknuepft = 0
        var wellnessZusammengefuehrt = 0
    }

    @discardableResult
    static func run(context: ModelContext) -> Bericht {
        var bericht = Bericht()
        do {
            if UserDefaults.standard.integer(forKey: versionKey) < aktuelleVersion {
                try backfill(context: context, bericht: &bericht)
                UserDefaults.standard.set(aktuelleVersion, forKey: versionKey)
            }
            bericht.wellnessZusammengefuehrt = try dedupliziereWellness(context: context)
            if context.hasChanges { try context.save() }
        } catch {
            logger.error("Datenpflege fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
        }
        return bericht
    }

    // MARK: - Backfill

    private static func backfill(context: ModelContext, bericht: inout Bericht) throws {
        let tz = TimeZone.current.identifier

        for e in try context.fetch(FetchDescriptor<PainEntry>()) {
            if e.artRaw.isEmpty {
                e.artRaw = EintragArt.ausLegacy(koerperstelle: e.koerperstelle, istHautEintrag: e.istHautEintrag).rawValue
                bericht.artGesetzt += 1
            }
            if e.timeZoneID.isEmpty { e.timeZoneID = tz; bericht.zeitzonenGesetzt += 1 }
        }
        for e in try context.fetch(FetchDescriptor<MigraeneEintrag>()) where e.timeZoneID.isEmpty {
            e.timeZoneID = tz; bericht.zeitzonenGesetzt += 1
        }
        for e in try context.fetch(FetchDescriptor<BlutzuckerEintrag>()) where e.timeZoneID.isEmpty {
            e.timeZoneID = tz; bericht.zeitzonenGesetzt += 1
        }
        for e in try context.fetch(FetchDescriptor<ZyklusEintrag>()) where e.timeZoneID.isEmpty {
            e.timeZoneID = tz; bericht.zeitzonenGesetzt += 1
        }
        for e in try context.fetch(FetchDescriptor<WellnessEintrag>()) where e.timeZoneID.isEmpty {
            e.timeZoneID = tz; bericht.zeitzonenGesetzt += 1
        }

        // Einnahme-Logs über Name + Dosierung mit der stabilen Medikamenten-ID verknüpfen.
        // Nur eindeutige Treffer (genau ein Medikament passt), sonst bleibt der Log unverknüpft.
        let meds = try context.fetch(FetchDescriptor<Dauermedikation>())
        for log in try context.fetch(FetchDescriptor<EinnahmeLog>()) where log.medikamentID.isEmpty {
            let treffer = meds.filter { $0.name == log.medikamentName && $0.dosierung == log.dosierung }
            if treffer.count == 1 { log.medikamentID = treffer[0].notifID; bericht.logsVerknuepft += 1 }
        }
    }

    // MARK: - Wellness: ein Eintrag pro Tag

    /// Führt mehrere `WellnessEintrag` desselben Kalendertags zusammen (z. B. nach Zeitzonenwechsel oder Sync).
    /// Zähler nehmen den höheren Wert, Notizen werden verbunden. Gibt die Anzahl entfernter Duplikate zurück.
    static func dedupliziereWellness(context: ModelContext) throws -> Int {
        let alle = try context.fetch(FetchDescriptor<WellnessEintrag>(sortBy: [SortDescriptor(\.datum)]))
        let gruppen = Dictionary(grouping: alle, by: { $0.tag })
        var entfernt = 0
        for (_, eintraege) in gruppen where eintraege.count > 1 {
            let haupt = eintraege[0]
            for dup in eintraege.dropFirst() {
                haupt.wasserMl = max(haupt.wasserMl, dup.wasserMl)
                haupt.koffeinTassen = max(haupt.koffeinTassen, dup.koffeinTassen)
                haupt.alkoholGlaeser = max(haupt.alkoholGlaeser, dup.alkoholGlaeser)
                haupt.fruehstueck = haupt.fruehstueck || dup.fruehstueck
                haupt.mittag = haupt.mittag || dup.mittag
                haupt.abend = haupt.abend || dup.abend
                if haupt.stimmung == 0 { haupt.stimmung = dup.stimmung }
                if haupt.stressLevel == 0 { haupt.stressLevel = dup.stressLevel }
                if haupt.energielevel == 0 { haupt.energielevel = dup.energielevel }
                haupt.schlafStunden = max(haupt.schlafStunden, dup.schlafStunden)
                if !dup.notizen.isEmpty, !haupt.notizen.contains(dup.notizen) {
                    haupt.notizen = haupt.notizen.isEmpty ? dup.notizen : haupt.notizen + "\n" + dup.notizen
                }
                context.delete(dup)
                entfernt += 1
            }
        }
        return entfernt
    }
}
