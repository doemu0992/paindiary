import Foundation
import SwiftData

@Model final class Allergie {
    var substanz: String = ""
    var typ: String = ""
    var reaktion: String = ""
    var schwere: String = ""
    var benutzerprofil: Benutzerprofil?

    init(substanz: String = "", typ: String = "Allergie", reaktion: String = "", schwere: String = "Mittel") {
        self.substanz = substanz
        self.typ = typ
        self.reaktion = reaktion
        self.schwere = schwere
    }
}
