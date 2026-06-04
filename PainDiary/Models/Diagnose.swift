import Foundation
import SwiftData

@Model final class Diagnose {
    var bezeichnung: String = ""
    var datum: Date?
    var notizen: String = ""
    var benutzerprofil: Benutzerprofil?

    init(bezeichnung: String = "", datum: Date? = nil, notizen: String = "") {
        self.bezeichnung = bezeichnung
        self.datum = datum
        self.notizen = notizen
    }
}
