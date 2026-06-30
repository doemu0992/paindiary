import SwiftUI

struct DatenschutzView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                abschnitt(titel: "Verantwortlicher") {
                    Text("Dominik Gerber\nSchweiz\nE-Mail: doemugerber@gmail.com")
                }

                abschnitt(titel: "Welche Daten werden gespeichert?") {
                    Text("""
PainDiary speichert ausschliesslich Daten, die du selbst eingibst:

• Schmerzeinträge (Stärke, Ort, Dauer, Auslöser, Massnahmen)
• Medikamentenpläne und Einnahmezeiten
• Zyklus- und Fruchtbarkeitsdaten
• Wohlbefindensdaten (Stimmung, Stress, Schlaf, Wasser, Ernährung)
• Profildaten (Name, Geburtsdatum, Versicherung, Diagnosen, Allergien, Ärzte)
• MIDAS-Bewertungen
• Wetterdaten (automatisch beim Erfassen eines Eintrags, anonym)
""")
                }

                abschnitt(titel: "Wo werden die Daten gespeichert?") {
                    Text("""
Alle Daten werden lokal auf deinem Gerät gespeichert. Optional werden sie über Apple iCloud auf deine anderen Apple-Geräte synchronisiert — sofern du iCloud in den iOS-Einstellungen aktiviert hast.

Wir (der Entwickler) haben zu keinem Zeitpunkt Zugriff auf deine Daten. Es werden keine Daten an unsere Server übertragen.
""")
                }

                abschnitt(titel: "Drittanbieter-Dienste") {
                    Text("""
Open-Meteo (Wetterdaten)
Beim Erstellen eines Schmerzeintrags wird automatisch eine anonyme Anfrage an api.open-meteo.com gesendet, um aktuelle Wetterdaten (Temperatur, Wettercode, Wind, Luftdruck) abzurufen. Dabei wird dein ungefährer Standort übermittelt. Es werden keine personenbezogenen Daten gespeichert. Datenschutzrichtlinie: open-meteo.com/en/terms

Apple iCloud
Falls iCloud-Sync aktiviert ist, gelten zusätzlich die Datenschutzbestimmungen von Apple: apple.com/legal/privacy
""")
                }

                abschnitt(titel: "Apple HealthKit") {
                    Text("""
Falls du die HealthKit-Integration aktivierst, liest PainDiary mit deiner Erlaubnis folgende Daten aus der Gesundheits-App:
• Schlafdaten (Schlafstunden)
• Schritte (tägliche Aktivität)

Diese Daten werden nur lokal verwendet und nie an Dritte weitergegeben. Du kannst den Zugriff jederzeit in Einstellungen → Datenschutz → Gesundheit widerrufen.
""")
                }

                abschnitt(titel: "Datenaustausch mit SleepBuddy") {
                    Text("""
Wenn du auch die App SleepBuddy desselben Entwicklers nutzt und die Verknüpfung aktivierst, überträgt SleepBuddy eine Zusammenfassung deiner Nacht (z. B. Schlafdauer und -qualität) an PainDiary.

Dieser Austausch findet ausschliesslich lokal auf deinem Gerät über eine gemeinsame, geschützte App-Gruppe statt. Es werden dabei keine Daten an Server des Entwicklers oder an Dritte übertragen. Du kannst die Verknüpfung jederzeit in SleepBuddy deaktivieren.
""")
                }

                abschnitt(titel: "Gesundheitsdaten – besonderer Schutz") {
                    Text("""
PainDiary verarbeitet sensible Gesundheitsdaten gemäss dem Schweizer Datenschutzgesetz (DSG) und der EU-DSGVO. Da alle Daten ausschliesslich auf deinem Gerät bzw. in deinem persönlichen iCloud-Konto gespeichert werden, liegt die Kontrolle vollständig bei dir.
""")
                }

                abschnitt(titel: "Deine Rechte") {
                    Text("""
Da deine Daten lokal auf deinem Gerät liegen, hast du jederzeit vollständige Kontrolle:

• Auskunft & Einsicht: Alle Daten sind direkt in der App einsehbar
• Berichtigung: Daten können jederzeit bearbeitet werden
• Löschung: Einträge können gelöscht werden; vollständige Löschung durch Deinstallation der App
• Datenübertragbarkeit: Export als PDF (oder CSV) jederzeit möglich
• Widerruf: HealthKit- und Standortzugriff jederzeit in iOS-Einstellungen widerrufbar
""")
                }

                abschnitt(titel: "Datensicherheit") {
                    Text("""
• Optionaler Face ID / Touch ID Schutz beim App-Start
• Daten in iCloud werden von Apple verschlüsselt übertragen und gespeichert
• Keine Drittanbieter-Analytics, keine Werbung, kein Tracking
""")
                }

                abschnitt(titel: "Kontakt") {
                    Text("""
Bei Fragen zum Datenschutz:
E-Mail: doemugerber@gmail.com
""")
                }

                abschnitt(titel: "Stand") {
                    Text("Diese Datenschutzerklärung ist gültig ab Juni 2026.")
                }
            }
            .padding()
        }
        .navigationTitle("Datenschutz")
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private func abschnitt(titel: String, @ViewBuilder inhalt: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titel)
                .font(.headline)
            inhalt()
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}
