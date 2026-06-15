import Foundation
import SwiftData

@Model final class Remissionsphase {
    var beginn: Date = Date()
    var ende: Date? = nil
    var notizen: String = ""

    init(beginn: Date = .now) { self.beginn = beginn }

    var istAktiv: Bool { ende == nil }

    var dauerTage: Int {
        Calendar.current.dateComponents([.day], from: beginn, to: ende ?? Date()).day ?? 0
    }

    var dauerText: String {
        let t = dauerTage
        if t < 7  { return "\(t) Tag\(t == 1 ? "" : "e")" }
        if t < 30 { let w = t / 7;  return "\(w) Woche\(w == 1 ? "" : "n")" }
        let m = t / 30; return "\(m) Monat\(m == 1 ? "" : "e")"
    }
}
