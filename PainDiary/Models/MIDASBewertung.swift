import Combine
import Foundation
import SwiftData

@Model final class MIDASBewertung {
    var datum: Date = Date()
    var tageArbeitEingeschraenkt: Int = 0
    var tageArbeitGefehlt: Int = 0
    var tageHaushaltEingeschraenkt: Int = 0
    var tageHaushaltGefehlt: Int = 0
    var tageFreizeit: Int = 0
    var notizen: String = ""

    var score: Int {
        tageArbeitEingeschraenkt + tageArbeitGefehlt +
        tageHaushaltEingeschraenkt + tageHaushaltGefehlt + tageFreizeit
    }

    var gradText: String {
        switch score {
        case 0...5:   return "Grad I – Minimal"
        case 6...10:  return "Grad II – Leicht"
        case 11...20: return "Grad III – Mässig"
        default:      return "Grad IV – Schwer"
        }
    }

    init(datum: Date = .now,
         tageArbeitEingeschraenkt: Int = 0, tageArbeitGefehlt: Int = 0,
         tageHaushaltEingeschraenkt: Int = 0, tageHaushaltGefehlt: Int = 0,
         tageFreizeit: Int = 0, notizen: String = "") {
        self.datum = datum
        self.tageArbeitEingeschraenkt = tageArbeitEingeschraenkt
        self.tageArbeitGefehlt = tageArbeitGefehlt
        self.tageHaushaltEingeschraenkt = tageHaushaltEingeschraenkt
        self.tageHaushaltGefehlt = tageHaushaltGefehlt
        self.tageFreizeit = tageFreizeit
        self.notizen = notizen
    }
}
