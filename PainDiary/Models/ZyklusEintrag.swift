import Combine
import Foundation
import SwiftData

@Model final class ZyklusEintrag {
    var datum: Date = Date()
    // Legacy field — kept for backward compat
    var typ: String = ""
    var notizen: String = ""

    // Period
    var istPeriode: Bool = false
    var blutungsfluss: String = "" // "schmierblutung" | "leicht" | "mittel" | "stark"
    var nurHalberTag: Bool = false

    // Symptoms (comma-separated)
    var symptome: String = ""

    // Ovulation
    var ovulationstest: String = ""  // "positiv" | "negativ" | "unklar"

    // Cervical mucus
    var zervixschleim: String = ""   // "trocken" | "klebrig" | "cremig" | "wässrig" | "eiweiss"

    // Basal body temperature (0 = not set)
    var basaltemperatur: Double = 0

    // Sexual activity
    var sexuelleAktivitaet: String = "" // "geschützt" | "ungeschützt"

    init(datum: Date = .now) {
        self.datum = datum
    }
}

// MARK: - Ovulationstest-Messungen (mehrere pro Tag)
//
// Das Feld `ovulationstest` speichert eine Liste: "negativ@09:12|positiv@18:30".
// Legacy-Werte ohne "@" ("positiv", "negativ", "unklar") bleiben gültig und
// erben als Zeit die Erfassungszeit des Eintrags (falls vorhanden).

struct OvulationstestMessung: Identifiable {
    let id = UUID()
    let ergebnis: String   // "positiv" | "negativ" | "unklar"
    let zeit: Date?        // nil = keine Uhrzeit bekannt
}

extension ZyklusEintrag {
    var ovulationstestMessungen: [OvulationstestMessung] {
        guard !ovulationstest.isEmpty else { return [] }
        let kal = Calendar.current
        let tagesbeginn = kal.startOfDay(for: datum)
        return ovulationstest.components(separatedBy: "|").compactMap { teil in
            let t = teil.trimmingCharacters(in: .whitespaces)
            guard !t.isEmpty else { return nil }
            let parts = t.components(separatedBy: "@")
            let ergebnis = parts[0]
            if parts.count > 1 {
                let hm = parts[1].components(separatedBy: ":")
                if hm.count == 2, let h = Int(hm[0]), let m = Int(hm[1]),
                   let zeit = kal.date(bySettingHour: h, minute: m, second: 0, of: tagesbeginn) {
                    return OvulationstestMessung(ergebnis: ergebnis, zeit: zeit)
                }
                return OvulationstestMessung(ergebnis: ergebnis, zeit: nil)
            }
            // Legacy ohne Zeit: Erfassungszeit des Eintrags übernehmen (wenn ≠ 00:00)
            return OvulationstestMessung(ergebnis: ergebnis, zeit: tagesbeginn != datum ? datum : nil)
        }
    }

    static func kodiereOvulationstests(_ messungen: [OvulationstestMessung]) -> String {
        messungen.map { m in
            guard let zeit = m.zeit else { return m.ergebnis }
            let c = Calendar.current.dateComponents([.hour, .minute], from: zeit)
            return m.ergebnis + "@" + String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
        }.joined(separator: "|")
    }
}
