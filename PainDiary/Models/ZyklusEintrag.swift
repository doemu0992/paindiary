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

    init(datum: Date = .now) {
        self.datum = datum
    }
}
