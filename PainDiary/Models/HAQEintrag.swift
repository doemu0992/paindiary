import Foundation
import SwiftData

// HAQ-DI (Health Assessment Questionnaire Disability Index)
// Each category rated 0–3: 0 = no difficulty, 1 = some, 2 = much, 3 = unable
@Model final class HAQEintrag {
    var datum: Date = Date()
    var ankleiden: Int = 0       // Ankleiden & Körperpflege
    var aufstehen: Int = 0       // Aufstehen
    var essen: Int = 0           // Essen
    var gehen: Int = 0           // Gehen
    var hygiene: Int = 0         // Hygiene
    var greifen: Int = 0         // Greifen
    var aktivitaeten: Int = 0    // Aktivitäten
    var globalBewertung: Int = 0 // Allgemeines Befinden (0–100 VAS)
    var notizen: String = ""

    init(datum: Date = .now) { self.datum = datum }

    // HAQ-DI: average of 8 category scores (0.0 – 3.0)
    var haqScore: Double {
        let werte = [ankleiden, aufstehen, essen, gehen, hygiene, greifen, aktivitaeten]
        return Double(werte.reduce(0, +)) / Double(werte.count)
    }

    var haqGradText: String {
        switch haqScore {
        case 0:          return "Keine Einschränkung"
        case 0.001..<0.5: return "Geringe Einschränkung"
        case 0.5..<1.0:  return "Mässige Einschränkung"
        case 1.0..<1.5:  return "Deutliche Einschränkung"
        case 1.5..<2.0:  return "Erhebliche Einschränkung"
        default:         return "Schwere Einschränkung"
        }
    }
}
