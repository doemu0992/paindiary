import Foundation
import SwiftData

@Model final class EinnahmeLog {
    var datum: Date = Date()
    var medikamentName: String = ""
    var dosierung: String = ""
    var eingenommen: Bool = true
    var notizen: String = ""

    init(datum: Date = .now,
         medikamentName: String = "",
         dosierung: String = "",
         eingenommen: Bool = true,
         notizen: String = "") {
        self.datum = datum
        self.medikamentName = medikamentName
        self.dosierung = dosierung
        self.eingenommen = eingenommen
        self.notizen = notizen
    }
}
