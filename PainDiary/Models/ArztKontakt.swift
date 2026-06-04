import Foundation
import SwiftData

@Model final class ArztKontakt {
    var name: String = ""
    var fachgebiet: String = ""
    var praxis: String = ""
    var telefon: String = ""
    var email: String = ""
    var istHausarzt: Bool = false
    var notizen: String = ""
    var benutzerprofil: Benutzerprofil?

    init(
        name: String = "",
        fachgebiet: String = "",
        praxis: String = "",
        telefon: String = "",
        email: String = "",
        istHausarzt: Bool = false,
        notizen: String = ""
    ) {
        self.name = name
        self.fachgebiet = fachgebiet
        self.praxis = praxis
        self.telefon = telefon
        self.email = email
        self.istHausarzt = istHausarzt
        self.notizen = notizen
    }
}
