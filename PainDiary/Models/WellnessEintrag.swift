import Foundation
import SwiftData

@Model
class WellnessEintrag {
    var datum: Date
    var wasserMl: Int
    var wasserZielMl: Int
    var koffeinTassen: Int
    var alkoholGlaeser: Int
    var fruehstueck: Bool
    var mittag: Bool
    var abend: Bool
    var stimmung: Int       // 1–5, 0 = nicht erfasst
    var stressLevel: Int    // 1–5, 0 = nicht erfasst
    var energielevel: Int   // 1–5, 0 = nicht erfasst
    var schlafStunden: Double // 0 = nicht erfasst
    var notizen: String

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
