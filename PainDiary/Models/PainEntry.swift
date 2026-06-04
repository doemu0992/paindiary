import Foundation
import SwiftData

@Model final class PainEntry {
    var datum: Date = Date()
    var schmerzstaerke: Int = 5       // 0–10
    var koerperstelle: String = ""
    var schmerzart: String = ""
    var dauerMinuten: Int = 0
    var ausloeser: String = ""
    var begleiterscheinungen: String = ""
    var massnahmen: String = ""
    var notizen: String = ""
    var stimmung: Int = 3             // 1–5
    var schlafStunden: Double = 0

    // Wetter zum Zeitpunkt der Erfassung
    var wetterTemperatur: Double?
    var wetterCode: Int?
    var wetterWind: Double?

    init(
        datum: Date = .now,
        schmerzstaerke: Int = 5,
        koerperstelle: String = "",
        schmerzart: String = "",
        dauerMinuten: Int = 0,
        ausloeser: String = "",
        begleiterscheinungen: String = "",
        massnahmen: String = "",
        notizen: String = "",
        stimmung: Int = 3,
        schlafStunden: Double = 0,
        wetterTemperatur: Double? = nil,
        wetterCode: Int? = nil,
        wetterWind: Double? = nil
    ) {
        self.datum = datum
        self.schmerzstaerke = schmerzstaerke
        self.koerperstelle = koerperstelle
        self.schmerzart = schmerzart
        self.dauerMinuten = dauerMinuten
        self.ausloeser = ausloeser
        self.begleiterscheinungen = begleiterscheinungen
        self.massnahmen = massnahmen
        self.notizen = notizen
        self.stimmung = stimmung
        self.schlafStunden = schlafStunden
        self.wetterTemperatur = wetterTemperatur
        self.wetterCode = wetterCode
        self.wetterWind = wetterWind
    }
}
