import Foundation
import SwiftData

@Model final class NotfallKontakt {
    var name: String = ""
    var phone: String = ""
    var beziehung: String = ""
    var benutzerprofil: Benutzerprofil?

    init(name: String = "", phone: String = "", beziehung: String = "") {
        self.name = name
        self.phone = phone
        self.beziehung = beziehung
    }
}
