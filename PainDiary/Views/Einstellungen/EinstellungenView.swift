import SwiftUI
import SwiftData

struct EinstellungenView: View {
    @AppStorage("akzentFarbe") private var akzentFarbe = "blau"

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
    @State private var zeigeWhatsNew = false

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

            Section("Erinnerungen") {
                NavigationLink(destination: PushManagerView()) {
                    Label("Benachrichtigungen verwalten", systemImage: "bell.badge")
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

                NavigationLink {
                    ChangelogVerlaufView()
                } label: {
                    Label("Versionsverlauf", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
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
        NotificationManager.shared.loescheAlleGesundheitsDatenErinnerungen()
        do {
            try modelContext.delete(model: PainEntry.self)
            try modelContext.delete(model: MigraeneEintrag.self)
            try modelContext.delete(model: Dauermedikation.self)
            try modelContext.delete(model: EinnahmeLog.self)
            try modelContext.delete(model: BiologikaInjektion.self)
            try modelContext.delete(model: ZyklusEintrag.self)
            try modelContext.delete(model: Laborwert.self)
            try modelContext.delete(model: HAQEintrag.self)
            try modelContext.delete(model: Arztbesuch.self)
            try modelContext.delete(model: PhysioSession.self)
            try modelContext.delete(model: KortisonEintrag.self)
            try modelContext.delete(model: BlutzuckerEintrag.self)
            try modelContext.delete(model: MIDASBewertung.self)
            try modelContext.delete(model: Remissionsphase.self)
            try modelContext.delete(model: Impftermin.self)
            try modelContext.delete(model: FACITEintrag.self)
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
