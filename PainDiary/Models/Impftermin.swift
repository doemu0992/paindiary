import Foundation
import SwiftData

@Model final class Impftermin {
    var impfstoff: String = ""
    var letzteImpfung: Date? = nil
    var intervallMonate: Int = 12    // repeat interval in months
    var notizen: String = ""

    init(impfstoff: String = "", intervallMonate: Int = 12) {
        self.impfstoff = impfstoff
        self.intervallMonate = intervallMonate
    }

    var naechsteFaelligkeit: Date? {
        guard let letzte = letzteImpfung else { return nil }
        return Calendar.current.date(byAdding: .month, value: intervallMonate, to: letzte)
    }

    var istFaellig: Bool {
        guard let naechste = naechsteFaelligkeit else { return letzteImpfung == nil }
        return naechste <= Date()
    }

    var dringlichkeit: ImpfDringlichkeit {
        guard let naechste = naechsteFaelligkeit else { return .ueberfaellig }
        let tage = Calendar.current.dateComponents([.day], from: Date(), to: naechste).day ?? 0
        switch tage {
        case ..<0:   return .ueberfaellig
        case 0..<30: return .bald
        default:     return .ok
        }
    }

    enum ImpfDringlichkeit { case ok, bald, ueberfaellig }
}

extension Impftermin {
    static var standardImpfungen: [Impftermin] {
        [
            { let i = Impftermin(impfstoff: "Influenza", intervallMonate: 12); return i }(),
            { let i = Impftermin(impfstoff: "Pneumokokken", intervallMonate: 60); return i }(),
            { let i = Impftermin(impfstoff: "Herpes Zoster", intervallMonate: 0); i.notizen = "Einmalig (2 Dosen)"; return i }(),
            { let i = Impftermin(impfstoff: "COVID-19", intervallMonate: 12); return i }(),
            { let i = Impftermin(impfstoff: "Hepatitis B", intervallMonate: 0); i.notizen = "3-Dosen-Schema prüfen"; return i }(),
            { let i = Impftermin(impfstoff: "FSME", intervallMonate: 36); return i }(),
            { let i = Impftermin(impfstoff: "Tetanus / Diphtherie", intervallMonate: 120); return i }(),
        ]
    }
}
