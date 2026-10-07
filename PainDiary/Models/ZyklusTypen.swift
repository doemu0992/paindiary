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
        self = LHTest(rawValue: normalisiert(roh)) ?? .keine
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
    /// Standard-Lutealphase, solange keine persönliche gelernt werden konnte.
    static let standardLutealphase = 14
    /// Plausibler Bereich einer gemessenen Lutealphase.
    static let gueltigeLutealphase: ClosedRange<Int> = 8...18
}
