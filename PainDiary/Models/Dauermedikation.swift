import Foundation
import SwiftData

@Model final class Dauermedikation {
    var notifID: String = UUID().uuidString
    var name: String
    var dosierung: String
    var frequenz: String
    var startDatum: Date
    var aktiv: Bool
    var erinnerungAktiv: Bool = false

    init(name: String = "", dosierung: String = "", frequenz: String = "", startDatum: Date = .now, aktiv: Bool = true) {
        self.name = name
        self.dosierung = dosierung
        self.frequenz = frequenz
        self.startDatum = startDatum
        self.aktiv = aktiv
    }
}
