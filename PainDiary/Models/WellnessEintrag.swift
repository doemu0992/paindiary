import Foundation
import SwiftData

@Model
class WellnessEintrag {
    var datum: Date = Date()
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
    var timeZoneID: String = ""   // IANA-Zeitzone bei Erfassung

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
        self.timeZoneID = TimeZone.current.identifier
    }

    var zeitzone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }
    /// Kalendertag in der Erfassungs-Zeitzone (Eindeutigkeit: ein Eintrag pro Tag).
    var tag: DayKey { DayKey(datum, zeitzone: zeitzone) }
}
