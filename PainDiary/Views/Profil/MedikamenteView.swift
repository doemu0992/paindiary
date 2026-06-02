import SwiftUI
import SwiftData

struct MedikamenteView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Dauermedikation.name) private var medikamente: [Dauermedikation]

    @State private var formAnzeigen = false
    @State private var zuBearbeiten: Dauermedikation? = nil

    private var aktive: [Dauermedikation] { medikamente.filter(\.aktiv) }
    private var inaktive: [Dauermedikation] { medikamente.filter { !$0.aktiv } }

    var body: some View {
        List {
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
                            MedikamentZeile(medikament: med)
                                .contentShape(Rectangle())
                                .onTapGesture { zuBearbeiten = med }
                        }
                        .onDelete { loeschen(aus: aktive, offsets: $0) }
                    }
                }
                if !inaktive.isEmpty {
                    Section("Pausiert / Abgesetzt") {
                        ForEach(inaktive) { med in
                            MedikamentZeile(medikament: med)
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

    private func loeschen(aus liste: [Dauermedikation], offsets: IndexSet) {
        offsets.forEach { modelContext.delete(liste[$0]) }
    }
}

// MARK: - Zeile

private struct MedikamentZeile: View {
    let medikament: Dauermedikation

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
                    Text(medikament.name)
                        .font(.headline)
                    if !medikament.aktiv {
                        Text("Pausiert")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .clipShape(Capsule())
                            .foregroundStyle(.secondary)
                    }
                }
                if !medikament.dosierung.isEmpty {
                    Text(medikament.dosierung)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    if !medikament.frequenz.isEmpty {
                        Label(medikament.frequenz, systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if medikament.aktiv {
                        Text("·").font(.caption).foregroundStyle(.secondary)
                        Label("Seit \(medikament.startDatum.formatted(.dateTime.day().month().year()))", systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
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

    private func ladeWerte() {
        guard let m = medikament else { return }
        name = m.name
        dosierung = m.dosierung
        frequenz = m.frequenz
        startDatum = m.startDatum
        aktiv = m.aktiv
    }

    private func speichern() {
        if let m = medikament {
            m.name = name
            m.dosierung = dosierung
            m.frequenz = frequenz
            m.startDatum = startDatum
            m.aktiv = aktiv
        } else {
            let neu = Dauermedikation(
                name: name,
                dosierung: dosierung,
                frequenz: frequenz,
                startDatum: startDatum,
                aktiv: aktiv
            )
            modelContext.insert(neu)
        }
        dismiss()
    }
}
