import SwiftUI
import SwiftData

struct MedikamenteView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Dauermedikation.name) private var medikamente: [Dauermedikation]

    @State private var formAnzeigen = false
    @State private var zuBearbeiten: Dauermedikation? = nil

    private let notif = NotificationManager.shared
    private var aktive: [Dauermedikation] { medikamente.filter(\.aktiv) }
    private var inaktive: [Dauermedikation] { medikamente.filter { !$0.aktiv } }

    var body: some View {
        List {
            berechtigungBanner

            if medikamente.isEmpty {
                ContentUnavailableView(
                    "Keine Medikamente",
                    systemImage: "pill",
                    description: Text("Tippe auf + um ein Dauermedikament hinzuzufügen.")
                )
                .listRowSeparator(.hidden)
            } else {
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
        .sheet(isPresented: $formAnzeigen) {
            MedikamentFormView()
        }
        .sheet(item: $zuBearbeiten) { med in
            MedikamentFormView(medikament: med)
        }
    }

    @ViewBuilder
    private var berechtigungBanner: some View {
        if notif.status == .denied {
            Section {
                Label("Push-Benachrichtigungen sind deaktiviert. Bitte in den Einstellungen aktivieren.", systemImage: "bell.slash")
                    .font(.caption)
                    .foregroundStyle(.orange)
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
                        Image(systemName: "bell.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    if !medikament.aktiv {
                        Text("Pausiert")
                            .font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .clipShape(Capsule())
                            .foregroundStyle(.secondary)
                    }
                }
                if !medikament.dosierung.isEmpty {
                    Text(medikament.dosierung).font(.subheadline).foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    if !medikament.frequenz.isEmpty {
                        Label(medikament.frequenz, systemImage: "clock")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if medikament.aktiv {
                        Text("·").font(.caption).foregroundStyle(.secondary)
                        Label(
                            "Seit \(medikament.startDatum.formatted(.dateTime.day().month().year()))",
                            systemImage: "calendar"
                        )
                        .font(.caption).foregroundStyle(.secondary)
                    }
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

    private let notif = NotificationManager.shared
    private let frequenzOptionen = [
        "1× täglich", "2× täglich", "3× täglich",
        "Morgens", "Abends", "Morgens & Abends",
        "Bei Bedarf", "Wöchentlich"
    ]

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
                        ForEach(frequenzOptionen, id: \.self) { opt in
                            Text(opt).tag(opt)
                        }
                    }
                    TextField("Eigene Frequenz…", text: $frequenz)
                    DatePicker("Seit", selection: $startDatum, displayedComponents: .date)
                }

                Section {
                    Toggle("Aktiv / Wird eingenommen", isOn: $aktiv)
                }

                Section {
                    Toggle(isOn: $erinnerungAktiv) {
                        VStack(alignment: .leading, spacing: 2) {
                            Label("Push-Erinnerung", systemImage: "bell.badge")
                            if erinnerungAktiv && !frequenz.isEmpty {
                                Text(erinnerungsZeitenText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onChange(of: erinnerungAktiv) { _, an in
                        if an && notif.status == .notDetermined {
                            Task { await notif.berechtigungAnfordern() }
                        }
                    }
                } footer: {
                    if erinnerungAktiv {
                        Text("Du erhältst täglich eine Push-Benachrichtigung zur Einnahmezeit.")
                    }
                }
            }
            .navigationTitle(medikament == nil ? "Neues Medikament" : "Medikament bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { speichern() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { ladeWerte() }
        }
    }

    private var erinnerungsZeitenText: String {
        switch frequenz {
        case "1× täglich", "Morgens":  return "Täglich um 08:00"
        case "Abends":                  return "Täglich um 21:00"
        case "Morgens & Abends":        return "Täglich um 08:00 und 21:00"
        case "2× täglich":              return "Täglich um 08:00 und 20:00"
        case "3× täglich":              return "Täglich um 08:00, 14:00 und 20:00"
        case "Bei Bedarf":              return "Keine automatische Erinnerung"
        case "Wöchentlich":             return "Montags um 08:00"
        default:                        return "Täglich um 08:00"
        }
    }

    private func ladeWerte() {
        guard let m = medikament else { return }
        name = m.name
        dosierung = m.dosierung
        frequenz = m.frequenz
        startDatum = m.startDatum
        aktiv = m.aktiv
        erinnerungAktiv = m.erinnerungAktiv
    }

    private func speichern() {
        if let m = medikament {
            m.name = name
            m.dosierung = dosierung
            m.frequenz = frequenz
            m.startDatum = startDatum
            m.aktiv = aktiv
            m.erinnerungAktiv = erinnerungAktiv
            if erinnerungAktiv {
                notif.planeErinnerungen(fuer: m)
            } else {
                notif.loescheErinnerungen(fuer: m)
            }
        } else {
            let neu = Dauermedikation(
                name: name,
                dosierung: dosierung,
                frequenz: frequenz,
                startDatum: startDatum,
                aktiv: aktiv
            )
            neu.erinnerungAktiv = erinnerungAktiv
            modelContext.insert(neu)
            if erinnerungAktiv {
                notif.planeErinnerungen(fuer: neu)
            }
        }
        dismiss()
    }
}
