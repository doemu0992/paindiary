import Foundation
import SwiftData

/// Zugriff auf Schmerzeinträge mit gezielten Abfragen (Predicate/FetchLimit) statt „alles laden und filtern".
@MainActor
struct PainRepository {
    let context: ModelContext

    /// Einträge im Zeitraum `von ..< bis`, neueste zuerst. `art` filtert nach Eintragstyp.
    func eintraege(von: Date? = nil, bis: Date? = nil, art: EintragArt? = nil, limit: Int? = nil) throws -> [PainEntry] {
        let start = von ?? .distantPast
        let ende = bis ?? .distantFuture
        var d = FetchDescriptor<PainEntry>(
            predicate: #Predicate<PainEntry> { $0.datum >= start && $0.datum < ende },
            sortBy: [SortDescriptor(\.datum, order: .reverse)]
        )
        if art == nil, let limit { d.fetchLimit = limit }
        var ergebnis = try context.fetch(d)
        if let art {
            ergebnis = ergebnis.filter { $0.eintragsArt == art }
            if let limit { ergebnis = Array(ergebnis.prefix(limit)) }
        }
        return ergebnis
    }

    /// Volltextsuche über Körperstelle, Schmerzart, Auslöser und Notizen (datenbankseitig).
    func suche(_ text: String, von: Date? = nil, bis: Date? = nil) throws -> [PainEntry] {
        let begriff = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !begriff.isEmpty else { return try eintraege(von: von, bis: bis) }
        let start = von ?? .distantPast
        let ende = bis ?? .distantFuture
        let d = FetchDescriptor<PainEntry>(
            predicate: #Predicate<PainEntry> {
                $0.datum >= start && $0.datum < ende && (
                    $0.koerperstelle.localizedStandardContains(begriff) ||
                    $0.schmerzart.localizedStandardContains(begriff) ||
                    $0.ausloeser.localizedStandardContains(begriff) ||
                    $0.notizen.localizedStandardContains(begriff))
            },
            sortBy: [SortDescriptor(\.datum, order: .reverse)]
        )
        return try context.fetch(d)
    }

    func anzahl(seit datum: Date) throws -> Int {
        try context.fetchCount(FetchDescriptor<PainEntry>(predicate: #Predicate<PainEntry> { $0.datum >= datum }))
    }

    func letzter() throws -> PainEntry? {
        var d = FetchDescriptor<PainEntry>(sortBy: [SortDescriptor(\.datum, order: .reverse)])
        d.fetchLimit = 1
        return try context.fetch(d).first
    }

    /// Eintragsdaten als Domain-Datensätze (für Statistik, Zusammenfassung, Export).
    func datensaetze(von: Date? = nil, bis: Date? = nil) throws -> [SchmerzDatensatz] {
        try eintraege(von: von, bis: bis)
            .filter { $0.eintragsArt != .haut }
            .map { SchmerzDatensatz(tag: $0.tag, staerke: $0.schmerzstaerke,
                                    koerperstellen: $0.koerperstellenListe, ausloeser: $0.ausloeserListe) }
    }
}
