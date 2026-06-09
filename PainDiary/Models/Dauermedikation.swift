import Foundation
import SwiftData

@Model final class Dauermedikation {
    var notifID: String = UUID().uuidString
    var name: String = ""
    var dosierung: String = ""
    var frequenz: String = ""
    var startDatum: Date = Date()
    var aktiv: Bool = true
    var erinnerungAktiv: Bool = false
    // Komma-getrennte Zeiten "HH:mm,HH:mm" — leer = Standard je nach Frequenz
    var erinnerungsZeiten: String = ""
    var einnahmeHinweis: String = ""
    var vorrat: Int? = nil
    var vorratSchwelle: Int = 7
    var ablaufDatum: Date? = nil

    init(name: String = "", dosierung: String = "", frequenz: String = "",
         startDatum: Date = .now, aktiv: Bool = true) {
        self.name = name
        self.dosierung = dosierung
        self.frequenz = frequenz
        self.startDatum = startDatum
        self.aktiv = aktiv
    }
}
