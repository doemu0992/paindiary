import Foundation
import SwiftData

@Model final class Arztbesuch {
    var datum: Date = Date()
    var arzt: String = ""
    var fachgebiet: String = ""
    var befund: String = ""
    var therapieaenderung: String = ""
    var naechsterTermin: Date? = nil
    var notizen: String = ""

    init(datum: Date = .now, arzt: String = "", fachgebiet: String = "") {
        self.datum = datum
        self.arzt = arzt
        self.fachgebiet = fachgebiet
    }
}
