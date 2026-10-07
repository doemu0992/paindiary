import Foundation

// Typisierte Sicht auf die String-Felder von `ZyklusEintrag`.
// Die Datenbank speichert weiterhin die Rohwerte (keine Schema-Migration nötig);
// die Enums normalisieren Altdaten (z. B. "Eiweiss" vs. "eiweiss") an einer Stelle.

private func normalisiert(_ roh: String) -> String {
    roh.trimmingCharacters(in: .whitespacesAndNewlines)
        .precomposedStringWithCanonicalMapping
        .lowercased()
}

// MARK: - Blutung (HealthKit: menstrualFlow / intermenstrualBleeding)

enum Blutungsfluss: String, CaseIterable, Identifiable {
    case keine = ""
    case schmierblutung
    case leicht
    case mittel
    case stark

    var id: String { rawValue }

    init(roh: String) {
        self = Blutungsfluss(rawValue: normalisiert(roh)) ?? .keine
    }

    var titel: String {
        switch self {
        case .keine:          return "Keine"
        case .schmierblutung: return "Schmierblutung"
        case .leicht:         return "Leicht"
        case .mittel:         return "Mittel"
        case .stark:          return "Stark"
        }
    }

    /// Schmierblutungen sind Spotting und markieren keinen Zyklusstart.
    var istSpotting: Bool { self == .schmierblutung }
}

// MARK: - Zervixschleim (HealthKit: cervicalMucusQuality)

enum Zervixschleim: String, CaseIterable, Identifiable {
    case keine = ""
    case trocken
    case klebrig
    case cremig
    case waessrig = "wässrig"
    case eiweiss

    var id: String { rawValue }

    init(roh: String) {
        let n = normalisiert(roh)
        switch n {
        case "waessrig", "wassrig": self = .waessrig
        case "eiweiß":             self = .eiweiss
        default:                    self = Zervixschleim(rawValue: n) ?? .keine
        }
    }

    var titel: String {
        switch self {
        case .keine:    return "Nicht erfasst"
        case .trocken:  return "Trocken"
        case .klebrig:  return "Klebrig"
        case .cremig:   return "Cremig"
        case .waessrig: return "Wässrig"
        case .eiweiss:  return "Eiweiß"
        }
    }

    /// Wässrig und Eiweiß gelten als fertil (Symptothermale Methode / Billings).
    var istFruchtbar: Bool { self == .waessrig || self == .eiweiss }
}

// MARK: - Ovulationstest (HealthKit: ovulationTestResult)

enum LHTest: String, CaseIterable, Identifiable {
    case keine = ""
    case positiv
    case negativ
    case unklar

    var id: String { rawValue }

    init(roh: String) {
        let n = normalisiert(roh)
        if n.isEmpty { self = .keine; return }
        if let exakt = LHTest(rawValue: n) { self = exakt; return }
        // Tolerant: ältere/importierte Werte ("Positiv (LH-Anstieg)", "+", "peak" …) nie als „kein Test“ verwerfen
        if n.contains("neg") || n.contains("niedrig") || n == "-" {
            self = .negativ
        } else if n.contains("pos") || n.contains("+") || n.contains("surge")
                    || n.contains("anstieg") || n.contains("peak") || n.contains("hoch") {
            self = .positiv
        } else {
            self = .unklar
        }
    }

    var titel: String {
        switch self {
        case .keine:   return "Kein Test"
        case .positiv: return "Positiv"
        case .negativ: return "Negativ"
        case .unklar:  return "Unklar"
        }
    }
}

// MARK: - Sexuelle Aktivität (HealthKit: sexualActivity + ProtectionUsed)

enum SexAktivitaet: String, CaseIterable, Identifiable {
    case keine = ""
    case geschuetzt = "geschützt"
    case ungeschuetzt = "ungeschützt"

    var id: String { rawValue }

    init(roh: String) {
        let n = normalisiert(roh)
        switch n {
        case "geschuetzt":   self = .geschuetzt
        case "ungeschuetzt": self = .ungeschuetzt
        default:             self = SexAktivitaet(rawValue: n) ?? .keine
        }
    }

    var titel: String {
        switch self {
        case .keine:        return "Keine Angabe"
        case .geschuetzt:   return "Geschützt"
        case .ungeschuetzt: return "Ungeschützt"
        }
    }
}

// MARK: - Plausibilitätsgrenzen

enum ZyklusGrenzen {
    /// Basaltemperatur in °C — alles außerhalb ist ein Tippfehler.
    static let bbtBereich: ClosedRange<Double> = 34.0...42.0
    /// Zyklen außerhalb dieses Bereichs (Tage) fließen nicht in Statistik/Prognose ein.
    static let gueltigeZyklusLaenge: ClosedRange<Int> = 15...90
    /// Standard-Lutealphase (Tage nach dem Eisprung bis zum Tag vor der Periode), solange keine persönliche
    /// gelernt werden konnte. Real gemessene Mittelwerte liegen bei ca. 12–13 Tagen; 14 ist der Lehrbuchwert.
    static let standardLutealphase = 13
    /// Plausibler Bereich einer gemessenen Lutealphase.
    static let gueltigeLutealphase: ClosedRange<Int> = 8...18
}


// MARK: - Tagessicht (mehrere Einträge eines Kalendertags zusammengeführt)

/// Alle Einträge eines Kalendertags in einer Sicht. Sonst ginge z. B. ein positiver LH-Test unter, wenn am
/// selben Tag ein zweiter Eintrag (etwa von der Periode oder aus einem früheren Duplikat) existiert.
/// Regeln: stärkste Blutung gewinnt, Symptome werden vereinigt, ein positiver LH-Test überstimmt andere Ergebnisse,
/// bei Schleim/Temperatur/Sex gilt der jeweils spätere Eintrag.
struct ZyklusTagesSicht {
    private(set) var hatBlutung = false
    private(set) var fluss: Blutungsfluss = .keine
    private(set) var symptome = ""
    private(set) var schleim: Zervixschleim = .keine
    private(set) var lhTest: LHTest = .keine
    private(set) var basaltemperatur: Double = 0
    private(set) var sexAktivitaet: SexAktivitaet = .keine
    private(set) var notizen = ""
    private(set) var anzahl = 0
    private(set) var eisprungBestaetigt = false

    private static func rang(_ f: Blutungsfluss) -> Int {
        switch f {
        case .keine: return 0
        case .schmierblutung: return 1
        case .leicht: return 2
        case .mittel: return 3
        case .stark: return 4
        }
    }

    init(_ eintraege: [ZyklusEintrag]) {
        var symptomListe: [String] = []
        var notizListe: [String] = []
        for e in eintraege.sorted(by: { $0.datum < $1.datum }) {
            anzahl += 1
            if e.eisprungBestaetigt { eisprungBestaetigt = true }
            if e.hatBlutung {
                hatBlutung = true
                if Self.rang(e.fluss) > Self.rang(fluss) { fluss = e.fluss }
            }
            symptomListe += ListenFeld.parse(e.symptome)
            if e.schleim != .keine { schleim = e.schleim }
            let l = e.lhTest
            if l != .keine && (l == .positiv || lhTest != .positiv) { lhTest = l }
            if ZyklusGrenzen.bbtBereich.contains(e.basaltemperatur) { basaltemperatur = e.basaltemperatur }
            if e.sexAktivitaet != .keine { sexAktivitaet = e.sexAktivitaet }
            let n = e.notizen.trimmingCharacters(in: .whitespacesAndNewlines)
            if !n.isEmpty && !notizListe.contains(n) { notizListe.append(n) }
        }
        symptome = ListenFeld.join(symptomListe)
        notizen = notizListe.joined(separator: " · ")
    }
}
