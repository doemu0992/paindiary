import Foundation
import SwiftData

@Model final class KortisonEintrag {
    var datum: Date = Date()
    var praeparat: String = "Prednison"
    var dosierungMg: Double = 5.0
    var istSchubTherapie: Bool = false
    var notizen: String = ""

    init(datum: Date = .now, dosierungMg: Double = 5.0) {
        self.datum = datum
        self.dosierungMg = dosierungMg
    }

    static let praeparate = ["Prednison", "Prednisolon", "Methylprednisolon", "Dexamethason", "Betamethason"]
}
