import Foundation

// MARK: - Haut

nonisolated struct HautMesspunkt: Equatable, Sendable {
    let datum: Date
    let tag: DayKey
    let stellen: [String]
    let arten: [String]
}

/// Kennzahlen für das Haut-Dashboard (Körperkarte, Kacheln).
nonisolated struct HautUebersicht: Equatable, Sendable {
    struct Zaehler: Equatable, Sendable {
        let name: String
        let anzahl: Int
    }

    var anzahl30 = 0
    var haeufigsteArt: String?
    var haeufigsteStelle: String?
    var letzterEintrag: Date?
    var letzterVorTagen: Int?
    /// Häufigste Stellen der letzten 30 Tage (absteigend, höchstens 3).
    var topStellen: [Zaehler] = []
    /// Relative Häufigkeit je Stelle (0…1) für die Körper-Heatmap.
    var stellenIntensitaeten: [String: Double] = [:]

    static func berechne(punkte: [HautMesspunkt], heute: DayKey) -> HautUebersicht {
        var u = HautUebersicht()
        let von = heute.addiere(tage: -29)
        let monat = punkte.filter { $0.tag >= von && $0.tag <= heute }
        u.anzahl30 = monat.count

        if let letzter = punkte.max(by: { $0.datum < $1.datum }) {
            u.letzterEintrag = letzter.datum
            u.letzterVorTagen = max(0, letzter.tag.tage(bis: heute))
        }

        let stellen = zaehle(monat.flatMap(\.stellen))
        u.topStellen = Array(stellen.prefix(3))
        u.haeufigsteStelle = stellen.first?.name
        if let maximum = stellen.first?.anzahl, maximum > 0 {
            u.stellenIntensitaeten = Dictionary(uniqueKeysWithValues: stellen.map { ($0.name, Double($0.anzahl) / Double(maximum)) })
        }
        u.haeufigsteArt = zaehle(monat.flatMap(\.arten)).first?.name
        return u
    }

    private static func zaehle(_ namen: [String]) -> [Zaehler] {
        var z: [String: Int] = [:]
        for n in namen where !n.isEmpty { z[n, default: 0] += 1 }
        return z.map { Zaehler(name: $0.key, anzahl: $0.value) }
            .sorted { $0.anzahl != $1.anzahl ? $0.anzahl > $1.anzahl : $0.name < $1.name }
    }
}

// MARK: - Rheuma

nonisolated struct RheumaMesspunkt: Equatable, Sendable {
    let datum: Date
    let tag: DayKey
    let staerke: Int
    let istSchub: Bool
    let morgensteifigkeit: Int
}

/// Kennzahlen für das Rheuma-Dashboard (Hero-Ring, Kacheln).
nonisolated struct RheumaUebersicht: Equatable, Sendable {
    var anzahl30 = 0
    var schnitt30: Double?
    var schuebe30 = 0
    /// Ø Morgensteifigkeit in Minuten (nur Einträge mit Wert > 0).
    var steifigkeitSchnitt30: Double?
    var letzterEintrag: Date?

    static func berechne(punkte: [RheumaMesspunkt], heute: DayKey) -> RheumaUebersicht {
        var u = RheumaUebersicht()
        let von = heute.addiere(tage: -29)
        let monat = punkte.filter { $0.tag >= von && $0.tag <= heute }
        u.anzahl30 = monat.count
        if !monat.isEmpty {
            u.schnitt30 = Double(monat.map(\.staerke).reduce(0, +)) / Double(monat.count)
        }
        u.schuebe30 = monat.filter(\.istSchub).count
        let steif = monat.map(\.morgensteifigkeit).filter { $0 > 0 }
        if !steif.isEmpty { u.steifigkeitSchnitt30 = Double(steif.reduce(0, +)) / Double(steif.count) }
        u.letzterEintrag = punkte.map(\.datum).max()
        return u
    }
}

// MARK: - Diabetes

nonisolated struct BlutzuckerMesspunkt: Equatable, Sendable {
    let datum: Date
    let tag: DayKey
    /// mmol/L
    let wert: Double
    let messZeitpunkt: String
    let insulinEinheiten: Double
    let bewertung: String
}

/// Kennzahlen für das Diabetes-Dashboard (Zielbereich-Ring, Kacheln).
nonisolated struct DiabetesUebersicht: Equatable, Sendable {
    /// Zielbereich in mmol/L (wie `BlutzuckerEintrag.zielbereich`).
    static let zielUntergrenze = 3.9
    static let zielObergrenze = 7.8

    var anzahl30 = 0
    /// Anteil der Messungen (30 Tage) im Zielbereich, 0…1.
    var zielAnteil30: Double?
    var nuechternSchnitt30: Double?
    var hypos30 = 0
    var letzteMessung: BlutzuckerMesspunkt?
    var insulinHeute: Double = 0
    /// Tagesschnitte der letzten 7 Tage (chronologisch, nur Tage mit Messungen).
    var verlauf7: [Double] = []

    static func berechne(punkte: [BlutzuckerMesspunkt], heute: DayKey) -> DiabetesUebersicht {
        var u = DiabetesUebersicht()
        let monat = punkte.filter { $0.tag >= heute.addiere(tage: -29) && $0.tag <= heute }
        u.anzahl30 = monat.count
        if !monat.isEmpty {
            let imZiel = monat.filter { $0.wert >= zielUntergrenze && $0.wert <= zielObergrenze }.count
            u.zielAnteil30 = Double(imZiel) / Double(monat.count)
        }
        let nuechtern = monat.filter { $0.messZeitpunkt == "Nüchtern" && $0.wert > 0 }.map(\.wert)
        if !nuechtern.isEmpty { u.nuechternSchnitt30 = nuechtern.reduce(0, +) / Double(nuechtern.count) }
        u.hypos30 = monat.filter { $0.wert < zielUntergrenze }.count
        u.letzteMessung = punkte.max { $0.datum < $1.datum }
        u.insulinHeute = punkte.filter { $0.tag == heute }.map(\.insulinEinheiten).reduce(0, +)

        let reihe = Statistik.tagesDurchschnitte(punkte.map { (tag: $0.tag, wert: $0.wert) })
        let von = heute.addiere(tage: -6)
        u.verlauf7 = reihe.filter { $0.tag >= von && $0.tag <= heute }.map(\.wert)
        return u
    }
}
