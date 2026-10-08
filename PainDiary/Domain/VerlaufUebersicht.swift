import Foundation

nonisolated struct VerlaufMesspunkt: Equatable, Sendable {
    let datum: Date
    let tag: DayKey
    let staerke: Int
    let istSchub: Bool
    let ausloeser: [String]
    /// 0 = nicht erfasst
    let stimmung: Int
    let stress: Int
    let schlafStunden: Double
}

/// Kennzahlen der „Einblicke" (Hero „Letzte 7 Tage" + Kennzahl-Kacheln). Eine Quelle für alle Durchschnitte.
nonisolated struct VerlaufUebersicht: Equatable, Sendable {
    var anzahl7 = 0
    var tage7 = 0
    var schnitt7: Double?
    var trend: TrendErgebnis?
    /// Tagesschnitte der letzten 7 Tage (nur Tage mit Einträgen).
    var verlauf7: [Double] = []
    var schuebe7 = 0
    var letzterSchub: Date?
    var letzterSchubVorTagen: Int?
    var haeufigsterAusloeser: String?
    var haeufigsterAusloeserAnzahl = 0
    var stimmungSchnitt7: Double?
    var stressSchnitt7: Double?
    var schlafSchnitt7: Double?

    var trendText: String? {
        guard let t = trend else { return nil }
        if abs(t.differenz) < 0.05 { return "= wie letzte Woche" }
        return "\(t.differenz < 0 ? "↓" : "↑") \(String(format: "%.1f", abs(t.differenz))) zur Vorwoche"
    }

    static func berechne(punkte: [VerlaufMesspunkt], heute: DayKey) -> VerlaufUebersicht {
        var u = VerlaufUebersicht()
        let von = heute.addiere(tage: -6)
        let woche = punkte.filter { $0.tag >= von && $0.tag <= heute }
        u.anzahl7 = woche.count
        u.tage7 = Set(woche.map(\.tag)).count

        let reihe = Statistik.tagesDurchschnitte(punkte.map { (tag: $0.tag, wert: Double($0.staerke)) })
        u.verlauf7 = reihe.filter { $0.tag >= von && $0.tag <= heute }.map(\.wert)
        u.trend = Statistik.trend(reihe, heute: heute, tage: 7)
        if !woche.isEmpty { u.schnitt7 = Double(woche.map(\.staerke).reduce(0, +)) / Double(woche.count) }

        u.schuebe7 = woche.filter(\.istSchub).count
        if let schub = punkte.filter(\.istSchub).max(by: { $0.datum < $1.datum }) {
            u.letzterSchub = schub.datum
            u.letzterSchubVorTagen = max(0, schub.tag.tage(bis: heute))
        }

        var zaehler: [String: Int] = [:]
        for p in woche { for a in Set(p.ausloeser) where !a.isEmpty { zaehler[a, default: 0] += 1 } }
        if let top = zaehler.sorted(by: { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }).first {
            u.haeufigsterAusloeser = top.key
            u.haeufigsterAusloeserAnzahl = top.value
        }

        func mittel(_ werte: [Double]) -> Double? { werte.isEmpty ? nil : werte.reduce(0, +) / Double(werte.count) }
        u.stimmungSchnitt7 = mittel(woche.filter { $0.stimmung > 0 }.map { Double($0.stimmung) })
        u.stressSchnitt7 = mittel(woche.filter { $0.stress > 0 }.map { Double($0.stress) })
        u.schlafSchnitt7 = mittel(woche.filter { $0.schlafStunden > 0 }.map(\.schlafStunden))
        return u
    }

    static func stimmungWort(_ wert: Double) -> String {
        switch Int(wert.rounded()) {
        case ...1: return "Schlecht"
        case 2: return "Mässig"
        case 3: return "Okay"
        case 4: return "Gut"
        default: return "Super"
        }
    }

    static func stressWort(_ wert: Double) -> String {
        switch Int(wert.rounded()) {
        case ...1: return "Entspannt"
        case 2: return "Leicht"
        case 3: return "Mässig"
        case 4: return "Hoch"
        default: return "Extrem"
        }
    }
}
