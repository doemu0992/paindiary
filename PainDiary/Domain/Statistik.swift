import Foundation

// MARK: - Grundtypen

/// Tageswert einer Messreihe (z. B. mittlere Schmerzstärke eines Tages).
nonisolated struct TagesWert: Equatable, Sendable {
    let tag: DayKey
    let wert: Double
}

nonisolated enum TrendRichtung: String, Sendable {
    case besser, gleich, schlechter
}

/// Vergleich zweier gleich langer Zeiträume (aktuell vs. direkt davor). Höhere Werte = schlechter (Schmerz).
nonisolated struct TrendErgebnis: Equatable, Sendable {
    let aktuell: Double
    let vorher: Double
    var differenz: Double { aktuell - vorher }

    /// `toleranz`: Änderungen darunter gelten als „gleich" (Standard 0,3 Punkte auf der 0–10-Skala).
    func richtung(toleranz: Double = 0.3) -> TrendRichtung {
        if differenz > toleranz { return .schlechter }
        if differenz < -toleranz { return .besser }
        return .gleich
    }
}

// MARK: - Statistik

/// Reine, testbare Statistikfunktionen. Keine Abhängigkeit von SwiftData oder UI.
nonisolated enum Statistik {

    static func mittelwert(_ werte: [Double]) -> Double? {
        guard !werte.isEmpty else { return nil }
        return werte.reduce(0, +) / Double(werte.count)
    }

    /// Stichproben-Standardabweichung (n−1). `nil` bei weniger als 2 Werten.
    static func standardabweichung(_ werte: [Double]) -> Double? {
        guard werte.count >= 2, let m = mittelwert(werte) else { return nil }
        let summe = werte.reduce(0) { $0 + ($1 - m) * ($1 - m) }
        return (summe / Double(werte.count - 1)).squareRoot()
    }

    /// Fasst Messpunkte pro Tag zu einem Durchschnitt zusammen (aufsteigend nach Tag sortiert).
    static func tagesDurchschnitte(_ punkte: [(tag: DayKey, wert: Double)]) -> [TagesWert] {
        let gruppen = Dictionary(grouping: punkte, by: { $0.tag })
        return gruppen
            .compactMap { tag, werte -> TagesWert? in
                guard let m = mittelwert(werte.map(\.wert)) else { return nil }
                return TagesWert(tag: tag, wert: m)
            }
            .sorted { $0.tag < $1.tag }
    }

    /// Mittelwert der Tageswerte im Zeitraum `von...bis` (inklusive). `nil`, wenn keine Daten vorliegen.
    static func mittelwert(in reihe: [TagesWert], von: DayKey, bis: DayKey) -> Double? {
        mittelwert(reihe.filter { $0.tag >= von && $0.tag <= bis }.map(\.wert))
    }

    /// Vergleicht die letzten `tage` Tage (inkl. `heute`) mit den `tage` Tagen davor.
    static func trend(_ reihe: [TagesWert], heute: DayKey, tage: Int = 7) -> TrendErgebnis? {
        guard tage > 0 else { return nil }
        let aktuellVon = heute.addiere(tage: -(tage - 1))
        let vorherBis = aktuellVon.addiere(tage: -1)
        let vorherVon = vorherBis.addiere(tage: -(tage - 1))
        guard let a = mittelwert(in: reihe, von: aktuellVon, bis: heute),
              let v = mittelwert(in: reihe, von: vorherVon, bis: vorherBis) else { return nil }
        return TrendErgebnis(aktuell: a, vorher: v)
    }

    /// Gleitender Mittelwert über `fenster` Kalendertage (nur vorhandene Tageswerte fließen ein).
    static func gleitenderMittelwert(_ reihe: [TagesWert], fenster: Int) -> [TagesWert] {
        guard fenster > 0 else { return [] }
        return reihe.compactMap { punkt in
            let von = punkt.tag.addiere(tage: -(fenster - 1))
            guard let m = mittelwert(in: reihe, von: von, bis: punkt.tag) else { return nil }
            return TagesWert(tag: punkt.tag, wert: m)
        }
    }

    /// Steigung der Ausgleichsgeraden in Wertpunkten **pro Tag** (Kleinste Quadrate).
    /// Positiv = steigend. `nil` bei weniger als 3 Punkten oder ohne zeitliche Streuung.
    static func steigung(_ reihe: [TagesWert]) -> Double? {
        guard reihe.count >= 3, let start = reihe.first?.tag else { return nil }
        let x = reihe.map { Double(start.tage(bis: $0.tag)) }
        let y = reihe.map(\.wert)
        guard let mx = mittelwert(x), let my = mittelwert(y) else { return nil }
        var zaehler = 0.0, nenner = 0.0
        for i in x.indices {
            zaehler += (x[i] - mx) * (y[i] - my)
            nenner += (x[i] - mx) * (x[i] - mx)
        }
        guard nenner > 0 else { return nil }
        return zaehler / nenner
    }

    /// Pearson-Korrelation zweier gleich langer Reihen. `nil` bei < `minPaare` Paaren oder ohne Streuung.
    static func korrelation(_ x: [Double], _ y: [Double], minPaare: Int = 5) -> Double? {
        guard x.count == y.count, x.count >= minPaare,
              let mx = mittelwert(x), let my = mittelwert(y) else { return nil }
        var sxy = 0.0, sxx = 0.0, syy = 0.0
        for i in x.indices {
            sxy += (x[i] - mx) * (y[i] - my)
            sxx += (x[i] - mx) * (x[i] - mx)
            syy += (y[i] - my) * (y[i] - my)
        }
        guard sxx > 0, syy > 0 else { return nil }
        return sxy / (sxx * syy).squareRoot()
    }

    /// Tage mit dokumentierter Schmerzstärke 0. Tage **ohne** Eintrag zählen nicht (unbekannt ≠ schmerzfrei).
    static func schmerzfreieTage(_ reihe: [TagesWert]) -> Int {
        reihe.filter { $0.wert <= 0 }.count
    }

    /// Längste Serie aufeinanderfolgender dokumentierter schmerzfreier Tage.
    static func laengsteSchmerzfreieSerie(_ reihe: [TagesWert]) -> Int {
        var beste = 0, aktuell = 0
        var letzter: DayKey? = nil
        for p in reihe.sorted(by: { $0.tag < $1.tag }) {
            if p.wert <= 0 {
                if let l = letzter, l.tage(bis: p.tag) == 1 { aktuell += 1 } else { aktuell = 1 }
                letzter = p.tag
                beste = max(beste, aktuell)
            } else {
                aktuell = 0
                letzter = nil
            }
        }
        return beste
    }

    /// Häufigkeiten der Elemente, absteigend sortiert (bei Gleichstand alphabetisch). Für „Top-5"-Listen.
    static func haeufigkeiten(_ elemente: [String], limit: Int? = nil) -> [(name: String, anzahl: Int)] {
        var zaehler: [String: Int] = [:]
        for e in elemente where !e.isEmpty { zaehler[e, default: 0] += 1 }
        let sortiert = zaehler
            .map { (name: $0.key, anzahl: $0.value) }
            .sorted { $0.anzahl == $1.anzahl ? $0.name < $1.name : $0.anzahl > $1.anzahl }
        if let limit { return Array(sortiert.prefix(limit)) }
        return sortiert
    }
}
