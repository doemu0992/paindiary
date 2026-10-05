import Foundation
import SwiftData

@Model final class EinnahmeLog {
    var datum: Date = Date()
    var medikamentName: String = ""
    var dosierung: String = ""
    var eingenommen: Bool = true
    var notizen: String = ""
    // "" = unbewertet, "gut" / "teilweise" / "nicht"
    var wirkung: String = ""
    /// `Dauermedikation.notifID` — stabile Verknüpfung (statt Name + Dosierung). Leer = Altdaten.
    var medikamentID: String = ""

    init(datum: Date = .now,
         medikamentName: String = "",
         dosierung: String = "",
         eingenommen: Bool = true,
         notizen: String = "",
         medikamentID: String = "") {
        self.datum = datum
        self.medikamentName = medikamentName
        self.dosierung = dosierung
        self.eingenommen = eingenommen
        self.notizen = notizen
        self.medikamentID = medikamentID
    }

    /// Gehört dieser Log zur Medikation? Bevorzugt die stabile ID, sonst Name + Dosierung (Altdaten).
    func gehoertZu(_ med: Dauermedikation) -> Bool {
        if !medikamentID.isEmpty { return medikamentID == med.notifID }
        return medikamentName == med.name && dosierung == med.dosierung
    }
}
