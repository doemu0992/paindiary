import Foundation
import SwiftData

@Model final class ArztKontakt {
    var name: String = ""
    var praxis: String = ""
    var fachgebiet: String = ""
    var adresse: String = ""
    var telefon: String = ""
    var email: String = ""
    var istHausarzt: Bool = false
    var notizen: String = ""
    var benutzerprofil: Benutzerprofil?

    init(
        name: String = "",
        praxis: String = "",
        fachgebiet: String = "",
        adresse: String = "",
        telefon: String = "",
        email: String = "",
        istHausarzt: Bool = false,
        notizen: String = ""
    ) {
        self.name = name
        self.praxis = praxis
        self.fachgebiet = fachgebiet
        self.adresse = adresse
        self.telefon = telefon
        self.email = email
        self.istHausarzt = istHausarzt
        self.notizen = notizen
    }
}
