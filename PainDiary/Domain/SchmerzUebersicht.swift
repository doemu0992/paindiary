import Foundation

/// Ein Schmerz-Eintrag als reiner Wert (ohne SwiftData), Eingabe für `SchmerzUebersicht`.
nonisolated struct SchmerzMesspunkt: Equatable, Sendable {
    let datum: Date
    let tag: DayKey
    let staerke: Int
    let istSchub: Bool
    let orte: [String]
}

/// Kennzahlen für das Schmerz-Dashboard (Hero-Ring, Bento-Kacheln, Körperkarte).
nonisolated struct SchmerzUebersicht: Equatable, Sendable {
    struct Schub: Equatable, Sendable {
        let datum: Date
        let staerke: Int
        let vorTagen: Int
    }

    struct Ort: Equatable, Sendable {
        let name: String
        let anzahl: Int
    }

    var heuteSchnitt: Double?
    var heuteAnzahl = 0
    var letzterEintrag: Date?
    var wochenSchnitt: Double?
    var trend: TrendErgebnis?
    /// Tagesschnitte der letzten 7 Tage (chronologisch, nur Tage mit Einträgen).
    var verlauf7: [Double] = []
    var staerkster7Tage: Int?
    var letzterSchub: Schub?
    /// Häufigste Orte der letzten 30 Tage (absteigend, höchstens 3).
    var topOrte: [Ort] = []
    /// Relative Häufigkeit je Ort der letzten 30 Tage (0…1) für die Körper-Heatmap.
    var ortIntensitaeten: [String: Double] = [:]
    var schubHinweis: SchubHinweis?

    var haeufigsterOrt: Ort? { topOrte.first }

    /// Kurztext zum Wochentrend (z. B. „↓ 0.8 zur Vorwoche").
    var trendText: String? {
        guard let t = trend else { return nil }
        if abs(t.differenz) < 0.05 { return "= wie letzte Woche" }
        return "\(t.differenz < 0 ? "↓" : "↑") \(String(format: "%.1f", abs(t.differenz))) zur Vorwoche"
    }

    static func berechne(punkte: [SchmerzMesspunkt], heute: DayKey) -> SchmerzUebersicht {
        var u = SchmerzUebersicht()
        let reihe = Statistik.tagesDurchschnitte(punkte.map { (tag: $0.tag, wert: Double($0.staerke)) })

        u.heuteSchnitt = reihe.first { $0.tag == heute }?.wert
        u.heuteAnzahl = punkte.filter { $0.tag == heute }.count
        u.letzterEintrag = punkte.map(\.datum).max()
        u.trend = Statistik.trend(reihe, heute: heute, tage: 7)
        u.schubHinweis = SchubErkennung.pruefe(reihe, heute: heute)

        let wochenStart = heute.addiere(tage: -6)
        u.verlauf7 = reihe.filter { $0.tag >= wochenStart && $0.tag <= heute }.map(\.wert)
        let woche = punkte.filter { $0.tag >= wochenStart && $0.tag <= heute }
        u.staerkster7Tage = woche.map(\.staerke).max()
        if !woche.isEmpty {
            u.wochenSchnitt = Double(woche.map(\.staerke).reduce(0, +)) / Double(woche.count)
        }

        if let schub = punkte.filter(\.istSchub).max(by: { $0.datum < $1.datum }) {
            u.letzterSchub = Schub(datum: schub.datum, staerke: schub.staerke, vorTagen: max(0, schub.tag.tage(bis: heute)))
        }

        let monatsStart = heute.addiere(tage: -29)
        var zaehler: [String: Int] = [:]
        for p in punkte where p.tag >= monatsStart && p.tag <= heute {
            for ort in Set(p.orte) where !ort.isEmpty { zaehler[ort, default: 0] += 1 }
        }
        let sortiert = zaehler.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
        u.topOrte = sortiert.prefix(3).map { Ort(name: $0.key, anzahl: $0.value) }
        if let maximum = sortiert.first?.value, maximum > 0 {
            u.ortIntensitaeten = zaehler.mapValues { Double($0) / Double(maximum) }
        }
        return u
    }
}
