import SwiftUI

struct WhatsNewAenderung: Identifiable {
    let id = UUID()
    let icon: String
    let farbe: Color
    let titel: String
    let beschreibung: String
}

struct WhatsNewVersion {
    let version: String  // Anzeige in der UI, z.B. "2.0"
    let build: String    // Matching gegen CFBundleVersion, z.B. "5"
    let aenderungen: [WhatsNewAenderung]
}

/// Pflege hier vor jedem TestFlight-Upload die Neuerungen ein.
/// build muss exakt mit CFBundleVersion (Build-Nummer in Xcode) übereinstimmen.
let appChangelog: [WhatsNewVersion] = [
    WhatsNewVersion(version: "2.0", build: "6", aenderungen: [
        WhatsNewAenderung(icon: "doc.richtext.fill",  farbe: .blue,
                          titel: "Arztbesuch-PDF verbessert",
                          beschreibung: "Vollständiges Einnahme-Protokoll mit allen Logs, unbegrenzt viele Seiten."),
        WhatsNewAenderung(icon: "moon.fill",          farbe: .indigo,
                          titel: "Dark Mode",
                          beschreibung: "PDF-Vorschau funktioniert jetzt korrekt im Dark Mode."),
        WhatsNewAenderung(icon: "bolt.fill",          farbe: .orange,
                          titel: "Schnellere PDF-Erstellung",
                          beschreibung: "PDF wird im Hintergrund erstellt – die App bleibt flüssig."),
        WhatsNewAenderung(icon: "person.fill.viewfinder", farbe: .teal,
                          titel: "Profil-Header überarbeitet",
                          beschreibung: "iOS-Settings-Stil mit Foto, Badges und direktem Bearbeiten."),
        WhatsNewAenderung(icon: "lock.fill",          farbe: .green,
                          titel: "Biometrische Sperre",
                          beschreibung: "Face ID / Touch ID jetzt in den App-Einstellungen."),
    ]),
    WhatsNewVersion(version: "2.0", build: "5", aenderungen: [
        WhatsNewAenderung(icon: "doc.richtext.fill",  farbe: .blue,
                          titel: "Arztbesuch-PDF verbessert",
                          beschreibung: "Vollständiges Einnahme-Protokoll mit allen Logs, unbegrenzt viele Seiten."),
        WhatsNewAenderung(icon: "moon.fill",          farbe: .indigo,
                          titel: "Dark Mode",
                          beschreibung: "PDF-Vorschau funktioniert jetzt korrekt im Dark Mode."),
        WhatsNewAenderung(icon: "bolt.fill",          farbe: .orange,
                          titel: "Schnellere PDF-Erstellung",
                          beschreibung: "PDF wird im Hintergrund erstellt – die App bleibt flüssig."),
        WhatsNewAenderung(icon: "person.fill.viewfinder", farbe: .teal,
                          titel: "Profil-Header überarbeitet",
                          beschreibung: "iOS-Settings-Stil mit Foto, Badges und direktem Bearbeiten."),
        WhatsNewAenderung(icon: "lock.fill",          farbe: .green,
                          titel: "Biometrische Sperre",
                          beschreibung: "Face ID / Touch ID jetzt in den App-Einstellungen."),
    ]),
]

/// Gibt den Changelog-Eintrag für den aktuell installierten Build zurück.
func whatsNewFuerAktuelleVersion() -> WhatsNewVersion? {
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
    return appChangelog.first { $0.build == build }
}
