import SwiftUI
import SwiftData

struct EinstellungenView: View {
    @AppStorage("akzentFarbe") private var akzentFarbe = "blau"
    @AppStorage("tagesErinnerungAktiv") private var tagesErinnerungAktiv = false
    @AppStorage("tagesErinnerungZeit") private var tagesErinnerungZeitSek = 28800.0 // 08:00

    @Environment(\.modelContext) private var modelContext
    @Query private var profile: [Benutzerprofil]
    @Query private var eintraege: [PainEntry]
    @Query private var medikamente: [Dauermedikation]
    @Query private var logs: [EinnahmeLog]

    @State private var exportURLs: [URL] = []
    @State private var zeigeShareSheet = false
    @State private var exportFehler: String?
    @State private var zeigeExportFehler = false
    @State private var zeigeLoeschenBestaetigung = false

    @State private var testNotifGesendet = false
    @State private var zeigeWhatsNew = false

    private let notif = NotificationManager.shared

    private var tagesErinnerungZeit: Binding<Date> {
        Binding(
            get: { Date(timeIntervalSinceReferenceDate: tagesErinnerungZeitSek) },
            set: { tagesErinnerungZeitSek = $0.timeIntervalSinceReferenceDate }
        )
    }

    private let farben: [(name: String, farbe: Color)] = [
        ("blau",   .blue),
        ("rot",    .red),
        ("orange", .orange),
        ("gruen",  .green),
        ("violett",.purple),
        ("pink",   .pink),
        ("indigo", .indigo),
        ("teal",   .teal)
    ]

    var body: some View {
        List {
            Section("Erscheinungsbild") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Akzentfarbe")
                        .font(.subheadline)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(farben, id: \.name) { eintrag in
                            Button {
                                akzentFarbe = eintrag.name
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(eintrag.farbe)
                                        .frame(width: 44, height: 44)
                                    if akzentFarbe == eintrag.name {
                                        Image(systemName: "checkmark")
                                            .font(.headline.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                Toggle("Tägliche Erinnerung", isOn: $tagesErinnerungAktiv)
                    .onChange(of: tagesErinnerungAktiv) { _, aktiv in
                        if aktiv {
                            Task {
                                let granted = await notif.berechtigungAnfordern()
                                if granted {
                                    let dc = Calendar.current.dateComponents([.hour, .minute], from: tagesErinnerungZeit.wrappedValue)
                                    notif.planeTagesErinnerung(stunde: dc.hour ?? 8, minute: dc.minute ?? 0)
                                } else {
                                    tagesErinnerungAktiv = false
                                }
                            }
                        } else {
                            notif.loescheTagesErinnerung()
                        }
                    }

                if tagesErinnerungAktiv {
                    DatePicker(
                        "Uhrzeit",
                        selection: tagesErinnerungZeit,
                        displayedComponents: .hourAndMinute
                    )
                    .onChange(of: tagesErinnerungZeit.wrappedValue) { _, neue in
                        let dc = Calendar.current.dateComponents([.hour, .minute], from: neue)
                        notif.planeTagesErinnerung(stunde: dc.hour ?? 8, minute: dc.minute ?? 0)
                    }
                }

                Button {
                    notif.sendeTestBenachrichtigung()
                    testNotifGesendet = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        testNotifGesendet = false
                    }
                } label: {
                    HStack {
                        Label("Testbenachrichtigung senden", systemImage: "bell.badge")
                        Spacer()
                        if testNotifGesendet {
                            Text("Kommt in 5 Sek…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .disabled(notif.status != .authorized)

                if notif.status == .authorized && !notif.timeSensitiveAktiv {
                    Button {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Fokus-Modus ignoriert Erinnerungen")
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                Text("Zeitkritische Mitteilungen in iOS-Einstellungen aktivieren")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Erinnerungen")
            } footer: {
                if notif.status != .authorized {
                    Text("Benachrichtigungen sind in den iOS-Einstellungen deaktiviert.")
                        .foregroundStyle(.orange)
                } else if !notif.timeSensitiveAktiv {
                    Text("Aktiviere 'Zeitkritische Mitteilungen' in den iOS-Einstellungen damit Erinnerungen auch bei aktivem Fokus-Modus (Nicht stören) ankommen.")
                        .foregroundStyle(.orange)
                } else if tagesErinnerungAktiv {
                    Text("Erinnerungen kommen auch bei aktivem Fokus-Modus durch.")
                } else {
                    Text("Tippe auf 'Test senden' und verlasse die App um den Push-Banner zu sehen.")
                }
            }

            Section {
                Button {
                    exportieren()
                } label: {
                    Label("Als CSV exportieren", systemImage: "square.and.arrow.up")
                }

                Button(role: .destructive) {
                    zeigeLoeschenBestaetigung = true
                } label: {
                    Label("Alle Daten löschen", systemImage: "trash")
                }
            } header: {
                Text("Daten")
            } footer: {
                Text("CSV-Dateien enthalten Schmerzeinträge, Medikamente und Einnahme-Logs.")
            }

            Section("Sicherheit") {
                if let profil = profile.first {
                    Toggle("Biometrische Sperre", isOn: Bindable(profil).biometrischesLockAktiv)
                        .onChange(of: profil.biometrischesLockAktiv) { _, neu in
                            UserDefaults.standard.set(neu, forKey: "biometrischesLockAktiv")
                        }
                }
            }

            Section("App") {
                NavigationLink(destination: DatenschutzView()) {
                    Label("Datenschutz", systemImage: "lock.shield")
                }

                Button {
                    zeigeWhatsNew = true
                } label: {
                    Label("Was ist neu", systemImage: "sparkles")
                }

                Button("Onboarding erneut anzeigen") {
                    UserDefaults.standard.set(false, forKey: "onboardingAbgeschlossen")
                }
                .foregroundStyle(.orange)
            }
        }
        .navigationTitle("Einstellungen")
        .sheet(isPresented: $zeigeShareSheet) {
            ShareSheet(urls: exportURLs)
        }
        .sheet(isPresented: $zeigeWhatsNew) {
            WhatsNewView { zeigeWhatsNew = false }
        }
        .alert("Export fehlgeschlagen", isPresented: $zeigeExportFehler) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportFehler ?? "Unbekannter Fehler")
        }
        .confirmationDialog(
            "Alle Daten unwiderruflich löschen?",
            isPresented: $zeigeLoeschenBestaetigung,
            titleVisibility: .visible
        ) {
            Button("Löschen", role: .destructive) { alleDatenLoeschen() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Schmerzeinträge, Medikamente und Einnahme-Logs werden permanent gelöscht. Dieser Vorgang kann nicht rückgängig gemacht werden.")
        }
    }

    // MARK: - Actions

    private func exportieren() {
        do {
            exportURLs = try CSVExportService.erstelleExport(
                eintraege: eintraege,
                medikamente: medikamente,
                logs: logs
            )
            zeigeShareSheet = true
        } catch {
            exportFehler = error.localizedDescription
            zeigeExportFehler = true
        }
    }

    private func alleDatenLoeschen() {
        do {
            try modelContext.delete(model: PainEntry.self)
            try modelContext.delete(model: Dauermedikation.self)
            try modelContext.delete(model: EinnahmeLog.self)
        } catch {
            exportFehler = error.localizedDescription
            zeigeExportFehler = true
        }
    }
}

// MARK: - Farb-Mapping

extension String {
    var alsAkzentFarbe: Color {
        switch self {
        case "rot":     return .red
        case "orange":  return .orange
        case "gruen":   return .green
        case "violett": return .purple
        case "pink":    return .pink
        case "indigo":  return .indigo
        case "teal":    return .teal
        default:        return .blue
        }
    }
}
