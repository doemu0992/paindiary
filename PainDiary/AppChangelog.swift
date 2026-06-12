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
    WhatsNewVersion(version: "2.0", build: "10", aenderungen: [
        WhatsNewAenderung(icon: "bell.badge.fill",          farbe: .blue,
                          titel: "Erinnerungen nach Update zuverlässig",
                          beschreibung: "Nach einer Neuinstallation oder einem App-Update werden alle Medikamenten-Erinnerungen, Tages- und Wasser-Erinnerungen automatisch neu geplant."),
        WhatsNewAenderung(icon: "bell.and.waves.left.and.right", farbe: .indigo,
                          titel: "Benachrichtigung testen",
                          beschreibung: "In den Einstellungen unter 'Erinnerungen' gibt es jetzt einen Test-Button – Push kommt nach 5 Sekunden, funktioniert auch wenn die App geöffnet ist."),
        WhatsNewAenderung(icon: "arrow.up.arrow.down",      farbe: .green,
                          titel: "Wochentend sensibler",
                          beschreibung: "Der Trend-Badge zeigt bereits ab einer Veränderung von ±0.05 Farbe – kleine Verbesserungen oder Verschlechterungen werden jetzt sichtbar."),
    ]),
    WhatsNewVersion(version: "2.0", build: "9", aenderungen: [
        WhatsNewAenderung(icon: "calendar.badge.checkmark", farbe: .blue,
                          titel: "Wochenvergleich Mo–So",
                          beschreibung: "Der Trend-Badge und 'Diese Woche' basieren jetzt auf echten Kalenderwochen (Montag bis Sonntag) statt einem rollenden 7-Tage-Fenster."),
        WhatsNewAenderung(icon: "pill.fill",               farbe: .green,
                          titel: "Bewertungs-Push öffnet Medikamente",
                          beschreibung: "Tippe auf 'Hat X gewirkt?' – die Medikamenten-Ansicht öffnet sich direkt mit der Bewertungssektion."),
        WhatsNewAenderung(icon: "wrench.and.screwdriver.fill", farbe: .orange,
                          titel: "Kleinere Bugfixes",
                          beschreibung: "Wöchentliche Injektionen werden korrekt nach Dosierung gefiltert. Ablaufdatum-Anzeige und Einnahme-Zählung im Dashboard präzisiert."),
    ]),
    WhatsNewVersion(version: "2.0", build: "8", aenderungen: [
        WhatsNewAenderung(icon: "bell.badge.fill",        farbe: .blue,
                          titel: "Push-Links immer zuverlässig",
                          beschreibung: "Deep Links funktionieren jetzt in allen Situationen: App geschlossen, im Hintergrund oder aktiv. Wirksamkeits-Abfrage öffnet direkt die Medikamenten-Karte."),
        WhatsNewAenderung(icon: "icloud.fill",            farbe: .cyan,
                          titel: "iCloud-Sync stabiler",
                          beschreibung: "UIBackgroundModes ist jetzt explizit in der Info.plist gesetzt – CloudKit kann Push-Benachrichtigungen für die Synchronisation zuverlässig empfangen."),
    ]),
    WhatsNewVersion(version: "2.0", build: "7", aenderungen: [
        WhatsNewAenderung(icon: "bell.badge.fill",        farbe: .blue,
                          titel: "Smarte Benachrichtigungen",
                          beschreibung: "Tippe auf eine Medikamenten-Erinnerung und die Einnahme-Maske öffnet sich direkt. Schmerz-Erinnerung öffnet die Erfassung."),
        WhatsNewAenderung(icon: "tag.fill",               farbe: .purple,
                          titel: "Eigene Chips werden gemerkt",
                          beschreibung: "Selbst eingegebene Auslöser, Schmerzarten, Begleiterscheinungen und Massnahmen erscheinen beim nächsten Eintrag direkt als Vorschlag."),
        WhatsNewAenderung(icon: "moon.zzz.fill",           farbe: .indigo,
                          titel: "Schlafstunden übernommen",
                          beschreibung: "Beim zweiten Eintrag des Tages werden die Schlafstunden vom ersten Eintrag automatisch vorausgefüllt."),
        WhatsNewAenderung(icon: "figure.walk",            farbe: .orange,
                          titel: "Onboarding verbessert",
                          beschreibung: "Das Textfeld beim Namen-Schritt war hinter der Tastatur versteckt – jetzt scrollt die Ansicht korrekt."),
    ]),
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
