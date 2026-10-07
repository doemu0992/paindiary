import Foundation
import SwiftData

@Model final class MigraeneEintrag {
    var datum: Date = Date()
    var dauer: Int = 0          // in Minuten
    var staerke: Int = 6        // 1–10
    var seite: String = "Einseitig links"       // "Einseitig links", "Einseitig rechts", "Beidseitig"
    var charakter: String = ""   // kommagetrennt
    var begleitsymptome: String = ""  // kommagetrennt
    var hatAura: Bool = false
    var ausloeser: String = ""   // kommagetrennt
    var akutmedikament: String = ""
    var medikamentWirksam: String = ""  // "Ja", "Teilweise", "Nein"
    var notizen: String = ""
    var wetterTemperatur: Double?
    var wetterCode: Int?
    var wetterWind: Double?

    // Extended fields (lightweight migration — default values)
    var kopfschmerzTyp: String = ""     // "Migräne", "Spannungskopfschmerz", "Cluster"
    var prodromsymptome: String = ""    // kommagetrennt
    var postdrom: String = ""           // kommagetrennt
    var endZeit: Date? = nil            // optionaler Endzeitpunkt
    var zyklusPhase: String = ""        // "Menstruation", "Fruchtbar", "Eisprung", ""
    var schlafStunden: Double = 0
    var stimmung: Int = 0               // 1–5, 0 = nicht erfasst
    var stressLevel: Int = 0            // 1–5, 0 = nicht erfasst
    var timeZoneID: String = ""         // IANA-Zeitzone bei Erfassung
    var fatigue: Int = 0
    var energielevel: Int = 0

    init(datum: Date = Date(), dauer: Int = 0, staerke: Int = 6,
         seite: String = "Einseitig links", charakter: String = "",
         begleitsymptome: String = "", hatAura: Bool = false,
         ausloeser: String = "", akutmedikament: String = "",
         medikamentWirksam: String = "", notizen: String = "",
         wetterTemperatur: Double? = nil, wetterCode: Int? = nil,
         wetterWind: Double? = nil) {
        self.datum = datum
        self.dauer = dauer
        self.staerke = staerke
        self.seite = seite
        self.charakter = charakter
        self.begleitsymptome = begleitsymptome
        self.hatAura = hatAura
        self.ausloeser = ausloeser
        self.akutmedikament = akutmedikament
        self.medikamentWirksam = medikamentWirksam
        self.notizen = notizen
        self.wetterTemperatur = wetterTemperatur
        self.wetterCode = wetterCode
        self.wetterWind = wetterWind
        self.timeZoneID = TimeZone.current.identifier
    }

    var dauerText: String {
        guard dauer > 0 else { return "–" }
        let h = dauer / 60; let m = dauer % 60
        if h == 0 { return "\(m) Min." }
        return m == 0 ? "\(h) Std." : "\(h) Std. \(m) Min."
    }

    var charakterListe: [String]       { ListenFeld.parse(charakter) }
    var begleitsymptomeListe: [String] { ListenFeld.parse(begleitsymptome) }
    var ausloeserListe: [String]       { ListenFeld.parse(ausloeser) }
    var prodromListe: [String]         { ListenFeld.parse(prodromsymptome) }
    var postdromListe: [String]        { ListenFeld.parse(postdrom) }

    var zeitzone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }
    var tag: DayKey { DayKey(datum, zeitzone: zeitzone) }
}
