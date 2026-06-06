import SwiftUI
import SwiftData

struct MedikamenteView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Dauermedikation.name) private var medikamente: [Dauermedikation]
    @Query(sort: \EinnahmeLog.datum, order: .reverse) private var logs: [EinnahmeLog]

    @State private var formAnzeigen = false
    @State private var zuBearbeiten: Dauermedikation? = nil
    @State private var logAnzeigen = false
    @State private var tagesstart = Calendar.current.startOfDay(for: Date())

    private let notif = NotificationManager.shared
    private var aktive: [Dauermedikation] { medikamente.filter(\.aktiv) }
    private var inaktive: [Dauermedikation] { medikamente.filter { !$0.aktiv } }

    private var heutigeLogsHeute: [EinnahmeLog] {
        logs.filter { $0.datum >= tagesstart }
    }

    var body: some View {
        List {
            berechtigungBanner
            uebergebrauchWarnung
            heuteSektion
            if !aktive.isEmpty {
                Section("Aktiv") {
                    ForEach(aktive) { med in
                        MedikamentZeile(medikament: med, notif: notif)
                            .contentShape(Rectangle())
                            .onTapGesture { zuBearbeiten = med }
                    }
                    .onDelete { loeschen(aus: aktive, offsets: $0) }
                }
            }
            if !inaktive.isEmpty {
                Section("Pausiert / Abgesetzt") {
                    ForEach(inaktive) { med in
                        MedikamentZeile(medikament: med, notif: notif)
                            .contentShape(Rectangle())
                            .onTapGesture { zuBearbeiten = med }
                    }
                    .onDelete { loeschen(aus: inaktive, offsets: $0) }
                }
            }
            if !logs.isEmpty {
                Section {
                    NavigationLink("Einnahme-Verlauf anzeigen") {
                        EinnahmeLogView()
                    }
                }
            }
        }
        .navigationTitle("Medikamente")
        .toolbar {
#if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) { EditButton() }
#endif
            ToolbarItem(placement: .primaryAction) {
                Button { formAnzeigen = true } label: {
                    Label("Hinzufügen", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $formAnzeigen) { MedikamentFormView() }
        .sheet(item: $zuBearbeiten) { med in MedikamentFormView(medikament: med) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                tagesstart = Calendar.current.startOfDay(for: Date())
            }
        }
    }

    // Warn if any med was logged > 10x in the last 30 days (medication overuse threshold)
    @ViewBuilder
    private var uebergebrauchWarnung: some View {
        let grenze = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let letzter30Tage = logs.filter { $0.datum >= grenze && $0.eingenommen }
        let zaehlung = Dictionary(grouping: letzter30Tage, by: \.medikamentName).mapValues(\.count)
        let probleme = zaehlung.filter { $0.value > 10 }.sorted { $0.value > $1.value }

        if !probleme.isEmpty {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Möglicher Medikamenten-Übergebrauch", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                    Text("Folgende Medikamente wurden in den letzten 30 Tagen mehr als 10-mal eingenommen. Häufiger Gebrauch von Schmerzmedikamenten kann Übergebrauchskopfschmerzen verursachen. Bitte sprich mit deinem Arzt.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(probleme, id: \.key) { name, anzahl in
                        HStack {
                            Text(name).font(.caption.bold())
                            Spacer()
                            Text("\(anzahl)× in 30 Tagen").font(.caption).foregroundStyle(.orange)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private var heuteSektion: some View {
        if !aktive.isEmpty {
            Section("Heute") {
                ForEach(aktive) { med in
                    HStack(spacing: 12) {
                        Image(systemName: "pill.fill")
                            .foregroundStyle(.blue)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(med.name).font(.subheadline).fontWeight(.medium)
                            if !med.dosierung.isEmpty {
                                Text(med.dosierung).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        einnahmeKontrolle(med: med)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    @ViewBuilder
    private func einnahmeKontrolle(med: Dauermedikation) -> some View {
        let anzahlErwartet = notif.anzahlDosen(med.frequenz)
        let anzahlHeute = heutigeLogsHeute.filter { $0.medikamentName == med.name }.count

        if anzahlErwartet == 0 {
            // Bei Bedarf: Freitext-Zähler + Plus-Button
            HStack(spacing: 8) {
                if anzahlHeute > 0 {
                    Text("\(anzahlHeute)× heute")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Button {
                    modelContext.insert(EinnahmeLog(
                        medikamentName: med.name, dosierung: med.dosierung, eingenommen: true))
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.title3).foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
        } else {
            // Reguläre Dosen: ein Kreis pro erwarteter Dosis
            HStack(spacing: 6) {
                ForEach(0..<anzahlErwartet, id: \.self) { i in
                    let bestaetigt = i < anzahlHeute
                    Button {
                        guard !bestaetigt else { return }
                        modelContext.insert(EinnahmeLog(
                            medikamentName: med.name, dosierung: med.dosierung, eingenommen: true))
                    } label: {
                        Image(systemName: bestaetigt ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(bestaetigt ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var berechtigungBanner: some View {
        if notif.status == .denied {
            Section {
                Label("Push-Benachrichtigungen deaktiviert.", systemImage: "bell.slash")
                    .font(.caption).foregroundStyle(.orange)
                Button("Einstellungen öffnen") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.caption)
            }
        } else if notif.status == .notDetermined {
            Section {
                Button {
                    Task { await notif.berechtigungAnfordern() }
                } label: {
                    Label("Benachrichtigungen aktivieren", systemImage: "bell.badge")
                }
            }
        }
    }

    private func loeschen(aus liste: [Dauermedikation], offsets: IndexSet) {
        offsets.forEach { i in
            notif.loescheErinnerungen(fuer: liste[i])
            modelContext.delete(liste[i])
        }
    }
}

// MARK: - Zeile

private struct MedikamentZeile: View {
    let medikament: Dauermedikation
    let notif: NotificationManager

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(medikament.aktiv ? Color.blue.opacity(0.15) : Color.secondary.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: "pill.fill")
                    .foregroundStyle(medikament.aktiv ? .blue : .secondary)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(medikament.name).font(.headline)
                    if medikament.erinnerungAktiv {
                        Image(systemName: "bell.fill").font(.caption).foregroundStyle(.orange)
                    }
                    if !medikament.aktiv {
                        Text("Pausiert").font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2)).clipShape(Capsule())
                            .foregroundStyle(.secondary)
                    }
                }
                if !medikament.dosierung.isEmpty {
                    Text(medikament.dosierung).font(.subheadline).foregroundStyle(.secondary)
                }
                if !medikament.frequenz.isEmpty {
                    let zeiten = notif.gueltigeZeiten(fuer: medikament)
                    let zeitText = zeiten.isEmpty ? medikament.frequenz : zeiten.map(\.anzeigeText).joined(separator: ", ")
                    Label(zeitText, systemImage: "clock").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Formular

struct MedikamentFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var medikament: Dauermedikation? = nil

    @State private var name = ""
    @State private var dosierung = ""
    @State private var frequenz = ""
    @State private var startDatum = Date()
    @State private var aktiv = true
    @State private var erinnerungAktiv = false
    @State private var erinnerungsZeiten: [Date] = [defaultZeit(8)]

    private let notif = NotificationManager.shared
    private let frequenzOptionen = [
        "1× täglich", "2× täglich", "3× täglich",
        "Morgens", "Abends", "Morgens & Abends",
        "Bei Bedarf", "Wöchentlich"
    ]

    private var anzahlZeiten: Int { notif.anzahlDosen(frequenz) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Medikament") {
                    TextField("Name (z.B. Ibuprofen)", text: $name)
                    TextField("Dosierung (z.B. 400 mg)", text: $dosierung)
                }

                Section("Einnahme") {
                    Picker("Frequenz", selection: $frequenz) {
                        Text("Bitte wählen").tag("")
                        ForEach(frequenzOptionen, id: \.self) { Text($0).tag($0) }
                    }
                    .onChange(of: frequenz) { old, neue in
                        // old is "" during initial load from ladeWerte() — skip to preserve saved times
                        guard medikament == nil || !old.isEmpty else { return }
                        aktualisiereStandardZeiten(neue)
                    }
                    DatePicker("Seit", selection: $startDatum, displayedComponents: .date)
                }

                Section { Toggle("Aktiv / Wird eingenommen", isOn: $aktiv) }

                if !frequenz.isEmpty && frequenz != "Bei Bedarf" {
                    Section {
                        Toggle(isOn: $erinnerungAktiv) {
                            Label("Push-Erinnerung", systemImage: "bell.badge")
                        }
                        .onChange(of: erinnerungAktiv) { _, an in
                            if an && notif.status == .notDetermined {
                                Task { await notif.berechtigungAnfordern() }
                            }
                        }

                        if erinnerungAktiv {
                            ForEach(0..<max(1, anzahlZeiten), id: \.self) { i in
                                if i < erinnerungsZeiten.count {
                                    DatePicker(
                                        anzahlZeiten > 1 ? "Zeit \(i + 1)" : "Uhrzeit",
                                        selection: $erinnerungsZeiten[i],
                                        displayedComponents: .hourAndMinute
                                    )
                                }
                            }
                        }
                    } header: {
                        Text("Erinnerungen")
                    } footer: {
                        if erinnerungAktiv && anzahlZeiten > 0 {
                            Text("Du erhältst täglich \(anzahlZeiten == 1 ? "eine" : "\(anzahlZeiten)") Erinnerung\(anzahlZeiten > 1 ? "en" : "") zur eingestellten Zeit.")
                        }
                    }
                }
            }
            .navigationTitle(medikament == nil ? "Neues Medikament" : "Medikament bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { speichern() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { ladeWerte() }
        }
    }

    private func aktualisiereStandardZeiten(_ frequenz: String) {
        let standard = notif.standardZeiten(frequenz)
        erinnerungsZeiten = standard.isEmpty ? [defaultZeit(8)] : standard.map(\.alsDate)
    }

    private func ladeWerte() {
        guard let m = medikament else { return }
        name = m.name
        dosierung = m.dosierung
        frequenz = m.frequenz
        startDatum = m.startDatum
        aktiv = m.aktiv
        erinnerungAktiv = m.erinnerungAktiv
        if !m.erinnerungsZeiten.isEmpty {
            erinnerungsZeiten = notif.parseZeitString(m.erinnerungsZeiten).map(\.alsDate)
        } else {
            aktualisiereStandardZeiten(m.frequenz)
        }
    }

    private func speichern() {
        let zeitenString = erinnerungAktiv
            ? notif.zeitenAlsString(erinnerungsZeiten.prefix(max(1, anzahlZeiten)).map(notif.dateZuZeitPunkt))
            : ""

        if let m = medikament {
            m.name = name; m.dosierung = dosierung; m.frequenz = frequenz
            m.startDatum = startDatum; m.aktiv = aktiv
            m.erinnerungAktiv = erinnerungAktiv
            m.erinnerungsZeiten = zeitenString
            erinnerungAktiv ? notif.planeErinnerungen(fuer: m) : notif.loescheErinnerungen(fuer: m)
        } else {
            let neu = Dauermedikation(name: name, dosierung: dosierung, frequenz: frequenz,
                                      startDatum: startDatum, aktiv: aktiv)
            neu.erinnerungAktiv = erinnerungAktiv
            neu.erinnerungsZeiten = zeitenString
            modelContext.insert(neu)
            if erinnerungAktiv { notif.planeErinnerungen(fuer: neu) }
        }
        dismiss()
    }
}

private func defaultZeit(_ stunde: Int) -> Date {
    var dc = DateComponents(); dc.hour = stunde; dc.minute = 0
    return Calendar.current.date(from: dc) ?? Date()
}

// MARK: - Einnahme-Log View

struct EinnahmeLogView: View {
    @Query(sort: \EinnahmeLog.datum, order: .reverse) private var logs: [EinnahmeLog]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        List {
            ForEach(logs as [EinnahmeLog]) { log in
                HStack(spacing: 12) {
                    Image(systemName: log.eingenommen ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(log.eingenommen ? .green : .red)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(log.medikamentName).font(.headline)
                        if !log.dosierung.isEmpty {
                            Text(log.dosierung).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(log.datum, style: .date).font(.caption).foregroundStyle(.secondary)
                        Text(log.datum, style: .time).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
            .onDelete { idx in idx.forEach { modelContext.delete(logs[$0]) } }
        }
        .navigationTitle("Einnahme-Verlauf")
    }
}
