import Foundation
import SwiftData

// FACIT-Fatigue Scale – 13 items, each rated 0 (gar nicht) – 4 (sehr)
// Items 7+8 are positive/reversed (energy, ability). Score 0–52, higher = less fatigue.
@Model final class FACITEintrag {
    var datum: Date = Date()
    var item01: Int = 0  // Ich fühle mich müde
    var item02: Int = 0  // Ich fühle mich schwach überall
    var item03: Int = 0  // Ich fühle mich kraftlos / ausgelaugt
    var item04: Int = 0  // Ich bin erschöpft
    var item05: Int = 0  // Ich habe Mühe, Dinge anzufangen (Müdigkeit)
    var item06: Int = 0  // Ich habe Mühe, Dinge zu beenden (Müdigkeit)
    var item07: Int = 4  // Ich habe Energie (positiv – reversed)
    var item08: Int = 4  // Ich kann meinen üblichen Aktivitäten nachgehen (positiv – reversed)
    var item09: Int = 0  // Ich muss tagsüber schlafen
    var item10: Int = 0  // Ich bin zu müde zum Essen
    var item11: Int = 0  // Ich brauche Hilfe bei üblichen Aktivitäten
    var item12: Int = 0  // Ich bin frustriert, weil ich zu müde bin
    var item13: Int = 0  // Ich muss soziale Aktivitäten einschränken (Müdigkeit)
    var notizen: String = ""

    init(datum: Date = .now) { self.datum = datum }

    // 0–52, higher = less fatigued. Cutoff < 30 = significant fatigue.
    var facitScore: Int {
        let belastung = item01 + item02 + item03 + item04 + item05 + item06
            + item09 + item10 + item11 + item12 + item13
        let positiv = item07 + item08
        return positiv + (4 * 11 - belastung)
    }

    var erschoepfungsgradText: String {
        switch facitScore {
        case 41...52: return "Keine relevante Erschöpfung"
        case 31...40: return "Leichte Erschöpfung"
        case 21...30: return "Mässige Erschöpfung"
        default:      return "Schwere Erschöpfung"
        }
    }

    static let fragen: [(text: String, reversed: Bool)] = [
        ("Ich fühle mich müde", false),
        ("Ich fühle mich körperlich schwach", false),
        ("Ich fühle mich kraftlos und ausgelaugt", false),
        ("Ich bin erschöpft", false),
        ("Ich habe Mühe, Dinge anzufangen", false),
        ("Ich habe Mühe, Dinge zu beenden", false),
        ("Ich habe Energie", true),
        ("Ich kann meinen üblichen Aktivitäten nachgehen", true),
        ("Ich muss tagsüber schlafen", false),
        ("Ich bin zu müde zum Essen", false),
        ("Ich brauche Hilfe bei alltäglichen Aufgaben", false),
        ("Ich bin frustriert, weil ich zu müde bin", false),
        ("Ich muss soziale Aktivitäten einschränken", false),
    ]
}
