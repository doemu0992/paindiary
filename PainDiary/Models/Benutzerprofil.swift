import Foundation
import SwiftData

@Model final class Benutzerprofil {
    @Attribute(.unique) var identifier: String = "hauptprofil"

    var vorname: String
    var nachname: String
    var geburtsdatum: Date?
    var geschlecht: String
    var wohnort: String
    var versicherung: String
    var versicherungsNummer: String
    var gewichtKg: Double?
    var groesseCm: Double?
    var fotoData: Data?
    var blutgruppe: String
    var zyklusTrackingAktiv: Bool
    var biometrischesLockAktiv: Bool

    @Relationship(deleteRule: .cascade) var diagnosen: [Diagnose] = []
    @Relationship(deleteRule: .cascade) var allergien: [Allergie] = []
    @Relationship(deleteRule: .cascade) var aerzte: [ArztKontakt] = []
    @Relationship(deleteRule: .cascade) var notfallkontakte: [NotfallKontakt] = []

    var bmi: Double? {
        guard let kg = gewichtKg, let cm = groesseCm, cm > 0 else { return nil }
        let m = cm / 100
        return kg / (m * m)
    }

    var bmiKategorie: String? {
        guard let bmi else { return nil }
        switch bmi {
        case ..<18.5: return "Untergewicht"
        case 18.5..<25: return "Normalgewicht"
        case 25..<30: return "Übergewicht"
        default: return "Adipositas"
        }
    }

    init(
        vorname: String = "",
        nachname: String = "",
        geschlecht: String = "Nicht angegeben",
        wohnort: String = "",
        versicherung: String = "",
        versicherungsNummer: String = "",
        blutgruppe: String = "Unbekannt",
        zyklusTrackingAktiv: Bool = false,
        biometrischesLockAktiv: Bool = false
    ) {
        self.vorname = vorname
        self.nachname = nachname
        self.geschlecht = geschlecht
        self.wohnort = wohnort
        self.versicherung = versicherung
        self.versicherungsNummer = versicherungsNummer
        self.blutgruppe = blutgruppe
        self.zyklusTrackingAktiv = zyklusTrackingAktiv
        self.biometrischesLockAktiv = biometrischesLockAktiv
    }
}
