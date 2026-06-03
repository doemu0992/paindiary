import Foundation
import SwiftData

@Model final class ZyklusEintrag {
    var datum: Date = Date()
    var typ: String = "Periode"
    var notizen: String = ""

    init(datum: Date = .now, typ: String = "Periode", notizen: String = "") {
        self.datum = datum
        self.typ = typ
        self.notizen = notizen
    }
}
