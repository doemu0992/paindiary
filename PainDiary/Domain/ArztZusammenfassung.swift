import Foundation

/// Minimaler Datensatz für die Auswertung (ohne SwiftData-Abhängigkeit).
nonisolated struct SchmerzDatensatz: Equatable, Sendable {
    let tag: DayKey
    let staerke: Int
    let koerperstellen: [String]
    let ausloeser: [String]
}

nonisolated struct HaeufigerEintrag: Equatable, Sendable {
    let name: String
    let anzahl: Int
}

/// Kompakte Kennzahlen für Arztgespräch/Export. Eine Quelle für PDF, CSV/JSON und Anzeige.
nonisolated struct ArztZusammenfassung: Equatable, Sendable {
    let von: DayKey
    let bis: DayKey
    let eintraege: Int
    let erfassteTage: Int
    let mittlereStaerke: Double?
    let maximaleStaerke: Int?
    let schmerzfreieTage: Int
    let laengsteSchmerzfreieSerie: Int
    let trend: TrendErgebnis?
    let topKoerperstellen: [HaeufigerEintrag]
    let topAusloeser: [HaeufigerEintrag]

    static func erstelle(datensaetze: [SchmerzDatensatz], von: DayKey, bis: DayKey, topAnzahl: Int = 5) -> ArztZusammenfassung {
        let imZeitraum = datensaetze.filter { $0.tag >= von && $0.tag <= bis }
        let reihe = Statistik.tagesDurchschnitte(imZeitraum.map { (tag: $0.tag, wert: Double($0.staerke)) })
        let laenge = max(1, von.tage(bis: bis) + 1)
        return ArztZusammenfassung(
            von: von, bis: bis,
            eintraege: imZeitraum.count,
            erfassteTage: reihe.count,
            mittlereStaerke: Statistik.mittelwert(imZeitraum.map { Double($0.staerke) }),
            maximaleStaerke: imZeitraum.map(\.staerke).max(),
            schmerzfreieTage: Statistik.schmerzfreieTage(reihe),
            laengsteSchmerzfreieSerie: Statistik.laengsteSchmerzfreieSerie(reihe),
            trend: Statistik.trend(Statistik.tagesDurchschnitte(datensaetze.map { (tag: $0.tag, wert: Double($0.staerke)) }), heute: bis, tage: laenge),
            topKoerperstellen: Statistik.haeufigkeiten(imZeitraum.flatMap(\.koerperstellen), limit: topAnzahl)
                .map { HaeufigerEintrag(name: $0.name, anzahl: $0.anzahl) },
            topAusloeser: Statistik.haeufigkeiten(imZeitraum.flatMap(\.ausloeser), limit: topAnzahl)
                .map { HaeufigerEintrag(name: $0.name, anzahl: $0.anzahl) }
        )
    }
}
