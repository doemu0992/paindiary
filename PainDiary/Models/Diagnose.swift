import Foundation
import SwiftData

@Model final class Diagnose {
    var bezeichnung: String = ""
    var icdCode: String = ""
    var datum: Date?
    var aktiv: Bool = true
    var notizen: String = ""
    var benutzerprofil: Benutzerprofil?

    init(bezeichnung: String = "", icdCode: String = "", datum: Date? = nil, aktiv: Bool = true, notizen: String = "") {
        self.bezeichnung = bezeichnung
        self.icdCode = icdCode
        self.datum = datum
        self.aktiv = aktiv
        self.notizen = notizen
    }

    static let rheumaDiagnosen = [
        "Rheumatoide Arthritis (RA)",
        "Psoriasis-Arthritis (PsA)",
        "Ankylosierende Spondylitis (AS)",
        "Systemischer Lupus erythematodes (SLE)",
        "Sjögren-Syndrom",
        "Polymyalgia rheumatica",
        "Gicht / Hyperurikämie",
        "Fibromyalgie",
        "Reaktive Arthritis",
        "Juvenile idiopathische Arthritis (JIA)",
    ]
}
