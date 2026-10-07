import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct EinstellungenView: View {
    @AppStorage("akzentFarbe") private var akzentFarbe = "blau"
    @AppStorage("iCloudSyncAktiv") private var iCloudSync = true

    @Environment(\.modelContext) private var modelContext
    @Query private var profile: [Benutzerprofil]
    @Query private var eintraege: [PainEntry]
    @Query private var medikamente: [Dauermedikation]
    @Query private var logs: [EinnahmeLog]
    @Query private var migraeneAnfaelle: [MigraeneEintrag]
    @Query private var blutzucker: [BlutzuckerEintrag]
    @Query private var wellness: [WellnessEintrag]
    @Query private var zyklus: [ZyklusEintrag]

    @State private var exportURLs: [URL] = []
    @State private var zeigeShareSheet = false
    @State private var exportFehler: String?
    @State private var zeigeExportFehler = false
    @State private var zeigeLoeschenBestaetigung = false
    @State private var zeigeWhatsNew = false
    @State private var zeigeImporter = false
    @State private var importBericht: String?
    @State private var zeigeImportBericht = false

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
            .listRowBackground(GlassRowBackground())

            Section("Erinnerungen") {
                NavigationLink(destination: PushManagerView()) {
                    Label("Benachrichtigungen verwalten", systemImage: "bell.badge")
                }
            }
            .listRowBackground(GlassRowBackground())

            Section {
                Button {
                    exportieren()
                } label: {
                    Label("Als CSV exportieren", systemImage: "square.and.arrow.up")
                }

                Button {
                    backupErstellen()
                } label: {
                    Label("Backup erstellen (JSON)", systemImage: "externaldrive.badge.plus")
                }

                Button {
                    zeigeImporter = true
                } label: {
                    Label("Backup wiederherstellen", systemImage: "externaldrive.badge.checkmark")
                }

                Button(role: .destructive) {
                    zeigeLoeschenBestaetigung = true
                } label: {
                    Label("Alle Daten löschen", systemImage: "trash")
                }
            } header: {
                Text("Daten")
            } footer: {
                Text("CSV enthält alle Module (Zeitpunkte als ISO 8601, mit Zeitzone). Das JSON-Backup sichert Schmerz, Migräne, Medikation, Einnahmen, Blutzucker, Wellness und Zyklus; beim Wiederherstellen werden vorhandene Einträge nicht doppelt angelegt. Fotos sind nicht enthalten.")
            }
            .listRowBackground(GlassRowBackground())

            Section {
                Toggle(isOn: $iCloudSync) {
                    Label("iCloud-Synchronisierung", systemImage: "icloud")
                }
            } header: {
                Text("Synchronisierung")
            } footer: {
                Text("Wenn aktiv, werden deine Gesundheitsdaten über deine iCloud auf deine Geräte synchronisiert. Wenn aus, bleiben sie nur auf diesem Gerät. Eine Änderung gilt nach einem Neustart der App.")
            }
            .listRowBackground(GlassRowBackground())

            Section("Sicherheit") {
                if let profil = profile.first {
                    Toggle("Biometrische Sperre", isOn: Bindable(profil).biometrischesLockAktiv)
                        .onChange(of: profil.biometrischesLockAktiv) { _, neu in
                            UserDefaults.standard.set(neu, forKey: "biometrischesLockAktiv")
                        }
                }
            }
            .listRowBackground(GlassRowBackground())

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
            .listRowBackground(GlassRowBackground())
        }
        .glassList(.neutral)
        .navigationTitle("Einstellungen")
        .sheet(isPresented: $zeigeShareSheet) {
            ShareSheet(urls: exportURLs)
        }
        .sheet(isPresented: $zeigeWhatsNew) {
            WhatsNewView { zeigeWhatsNew = false }
        }
        .fileImporter(isPresented: $zeigeImporter, allowedContentTypes: [.json]) { ergebnis in
            backupImportieren(ergebnis)
        }
        .alert("Backup", isPresented: $zeigeImportBericht) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importBericht ?? "")
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
            Text("Alle erfassten Gesundheitsdaten werden permanent gelöscht. Erstelle vorher ein Backup – dieser Vorgang kann nicht rückgängig gemacht werden.")
        }
    }

    // MARK: - Actions

    private func exportieren() {
        do {
            exportURLs = try CSVExportService.erstelleVollExport(quellen: .init(
                eintraege: eintraege,
                medikamente: medikamente,
                logs: logs,
                migraene: migraeneAnfaelle,
                blutzucker: blutzucker,
                wellness: wellness,
                zyklus: zyklus
            ))
            zeigeShareSheet = true
        } catch {
            exportFehler = error.localizedDescription
            zeigeExportFehler = true
        }
    }

    private func backupErstellen() {
        do {
            exportURLs = [try BackupService.erstelleBackup(context: modelContext)]
            zeigeShareSheet = true
        } catch {
            exportFehler = error.localizedDescription
            zeigeExportFehler = true
        }
    }

    private func backupImportieren(_ ergebnis: Result<URL, Error>) {
        switch ergebnis {
        case .success(let url):
            do {
                let bericht = try BackupService.importiere(url: url, context: modelContext)
                importBericht = "\(bericht.hinzugefuegt) Einträge wiederhergestellt, \(bericht.uebersprungen) bereits vorhanden oder ungültig."
                zeigeImportBericht = true
            } catch {
                exportFehler = error.localizedDescription
                zeigeExportFehler = true
            }
        case .failure(let fehler):
            exportFehler = fehler.localizedDescription
            zeigeExportFehler = true
        }
    }

    private func alleDatenLoeschen() {
        NotificationManager.shared.loescheAlleGesundheitsDatenErinnerungen()
        for entry in eintraege where entry.istHautEintrag {
            FotoManager.loeschen(dateiname: entry.fotoDateiname)
        }
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
            try modelContext.delete(model: WellnessEintrag.self)
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
