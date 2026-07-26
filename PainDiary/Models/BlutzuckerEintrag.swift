import Foundation
import SwiftData

// CloudKit-Sync verlangt Inline-Defaults an jeder Property (Defaults nur im
// init reichen nicht fürs Schema) — sonst lädt der Store auf Geräten mit
// aktivem iCloud nicht.
@Model final class BlutzuckerEintrag {
    var datum: Date = Date()
    var wert: Double = 5.5   // in mmol/L
    var messZeitpunkt: String = "Nüchtern"
    var insulinEinheiten: Double = 0
    var insulinTyp: String = ""   // "Kurzzeit", "Langzeit", "Mischung"
    var kohlenhydrate: Int = 0    // in Gramm, 0 = nicht erfasst
    var notizen: String = ""

    init(datum: Date = Date(), wert: Double = 5.5,
         messZeitpunkt: String = "Nüchtern",
         insulinEinheiten: Double = 0, insulinTyp: String = "",
         kohlenhydrate: Int = 0, notizen: String = "") {
        self.datum = datum
        self.wert = wert
        self.messZeitpunkt = messZeitpunkt
        self.insulinEinheiten = insulinEinheiten
        self.insulinTyp = insulinTyp
        self.kohlenhydrate = kohlenhydrate
        self.notizen = notizen
    }

    var wertText: String { String(format: "%.1f mmol/L", wert) }

    var zielbereich: Bool { wert >= 3.9 && wert <= 7.8 }

    var bewertung: String {
        switch wert {
        case ..<3.9:    return "Hypo"
        case 3.9..<6.0: return "Normal"
        case 6.0..<7.8: return "Erhöht"
        case 7.8..<10:  return "Zu hoch"
        default:        return "Sehr hoch"
        }
    }
}
