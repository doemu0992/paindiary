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
    var stressLevel: Int = 3          // 1–5

    // Wetter zum Zeitpunkt der Erfassung
    var wetterTemperatur: Double?
    var wetterCode: Int?
    var wetterWind: Double?

    var hautStellen: String = ""
    var hautArt: String = ""
    var fotoDateiname: String = ""
    var verlauf: String = ""   // "besser" | "gleich" | "schlechter" | ""

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
        stressLevel: Int = 3,
        wetterTemperatur: Double? = nil,
        wetterCode: Int? = nil,
        wetterWind: Double? = nil,
        hautStellen: String = "",
        hautArt: String = ""
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
        self.stressLevel = stressLevel
        self.wetterTemperatur = wetterTemperatur
        self.wetterCode = wetterCode
        self.wetterWind = wetterWind
        self.hautStellen = hautStellen
        self.hautArt = hautArt
    }
}
