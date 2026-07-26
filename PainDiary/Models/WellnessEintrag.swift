import Foundation
import SwiftData

// CloudKit-Sync verlangt Inline-Defaults an jeder Property (Defaults nur im
// init reichen nicht fürs Schema) — sonst lädt der Store auf Geräten mit
// aktivem iCloud nicht.
@Model
class WellnessEintrag {
    var datum: Date = Calendar.current.startOfDay(for: Date())
    var wasserMl: Int = 0
    var wasserZielMl: Int = 2000
    var koffeinTassen: Int = 0
    var alkoholGlaeser: Int = 0
    var fruehstueck: Bool = false
    var mittag: Bool = false
    var abend: Bool = false
    var stimmung: Int = 0       // 1–5, 0 = nicht erfasst
    var stressLevel: Int = 0    // 1–5, 0 = nicht erfasst
    var energielevel: Int = 0   // 1–5, 0 = nicht erfasst
    var schlafStunden: Double = 0 // 0 = nicht erfasst
    var notizen: String = ""

    init(datum: Date = Calendar.current.startOfDay(for: Date())) {
        self.datum = datum
        self.wasserMl = 0
        let gespeichertesZiel = UserDefaults.standard.integer(forKey: "wasserZielMl")
        self.wasserZielMl = gespeichertesZiel > 0 ? gespeichertesZiel : 2000
        self.koffeinTassen = 0
        self.alkoholGlaeser = 0
        self.fruehstueck = false
        self.mittag = false
        self.abend = false
        self.stimmung = 0
        self.stressLevel = 0
        self.energielevel = 0
        self.schlafStunden = 0
        self.notizen = ""
    }
}
