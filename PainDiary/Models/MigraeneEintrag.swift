import Foundation
import SwiftData

@Model final class MigraeneEintrag {
    var datum: Date
    var dauer: Int          // in Minuten
    var staerke: Int        // 1–10
    var seite: String       // "Einseitig links", "Einseitig rechts", "Beidseitig"
    var charakter: String   // kommagetrennt
    var begleitsymptome: String  // kommagetrennt
    var hatAura: Bool
    var ausloeser: String   // kommagetrennt
    var akutmedikament: String
    var medikamentWirksam: String  // "Ja", "Teilweise", "Nein"
    var notizen: String

    init(datum: Date = Date(), dauer: Int = 0, staerke: Int = 6,
         seite: String = "Einseitig links", charakter: String = "",
         begleitsymptome: String = "", hatAura: Bool = false,
         ausloeser: String = "", akutmedikament: String = "",
         medikamentWirksam: String = "", notizen: String = "") {
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
    }

    var dauerText: String {
        guard dauer > 0 else { return "–" }
        let h = dauer / 60; let m = dauer % 60
        if h == 0 { return "\(m) Min." }
        return m == 0 ? "\(h) Std." : "\(h) Std. \(m) Min."
    }

    var charakterListe: [String]       { charakter.components(separatedBy: ", ").filter { !$0.isEmpty } }
    var begleitsymptomeListe: [String] { begleitsymptome.components(separatedBy: ", ").filter { !$0.isEmpty } }
    var ausloeserListe: [String]       { ausloeser.components(separatedBy: ", ").filter { !$0.isEmpty } }
}
