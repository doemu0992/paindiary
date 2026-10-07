import Combine
import Foundation
import SwiftData

@Model final class ZyklusEintrag {
    var datum: Date = Date()
    // Legacy field — kept for backward compat
    var typ: String = ""
    var notizen: String = ""

    // Period
    var istPeriode: Bool = false
    var blutungsfluss: String = "" // "schmierblutung" | "leicht" | "mittel" | "stark"
    var nurHalberTag: Bool = false

    // Symptoms (comma-separated)
    var symptome: String = ""

    // Ovulation
    var ovulationstest: String = ""  // "positiv" | "negativ" | "unklar"

    // Cervical mucus
    var zervixschleim: String = ""   // "trocken" | "klebrig" | "cremig" | "wässrig" | "eiweiss"

    // Basal body temperature (0 = not set)
    var basaltemperatur: Double = 0

    // Sexual activity
    var sexuelleAktivitaet: String = "" // "geschützt" | "ungeschützt"

    // Herkunft: "" = manuell erfasst, "health" = aus Apple Health importiert.
    // Importierte Einträge werden nicht zurück nach Health geschrieben (kein Echo).
    var quelle: String = ""

    var timeZoneID: String = ""         // IANA-Zeitzone bei Erfassung

    init(datum: Date = .now) {
        self.datum = datum
        self.timeZoneID = TimeZone.current.identifier
    }

    var zeitzone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }
    var tag: DayKey { DayKey(datum, zeitzone: zeitzone) }
}

// MARK: - Typisierte Sicht (nicht persistiert)

extension ZyklusEintrag {
    var fluss: Blutungsfluss {
        get { Blutungsfluss(roh: blutungsfluss) }
        set { blutungsfluss = newValue.rawValue }
    }

    var schleim: Zervixschleim {
        get { Zervixschleim(roh: zervixschleim) }
        set { zervixschleim = newValue.rawValue }
    }

    var lhTest: LHTest {
        get { LHTest(roh: ovulationstest) }
        set { ovulationstest = newValue.rawValue }
    }

    var sexAktivitaet: SexAktivitaet {
        get { SexAktivitaet(roh: sexuelleAktivitaet) }
        set { sexuelleAktivitaet = newValue.rawValue }
    }

    /// Irgendeine Blutung (inkl. Schmierblutung und Legacy-Typ).
    var hatBlutung: Bool { istPeriode || typ == "Periode" }

    /// Echte Menstruationsblutung (Zyklusstart-relevant) — Spotting zählt nicht.
    var istMenstruation: Bool { hatBlutung && !fluss.istSpotting }

    var istSpotting: Bool { hatBlutung && fluss.istSpotting }

    var kommtAusHealth: Bool { quelle == "health" }
}
