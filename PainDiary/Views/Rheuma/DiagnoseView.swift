import SwiftUI
import SwiftData

struct DiagnoseView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Diagnose.bezeichnung) private var diagnosen: [Diagnose]

    @State private var zeigeForm = false
    @State private var bearbeitet: Diagnose? = nil

    private var aktive: [Diagnose] { diagnosen.filter { $0.aktiv } }
    private var fruehereD: [Diagnose] { diagnosen.filter { !$0.aktiv } }

    var body: some View {
        List {
            if diagnosen.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Keine Diagnosen",
                        systemImage: "cross.case.fill",
                        description: Text("Tippe auf + um eine Diagnose einzutragen.")
                    )
                    .listRowSeparator(.hidden)
                }
            } else {
                if !aktive.isEmpty {
                    Section("Aktive Diagnosen") {
                        ForEach(aktive) { d in
                            DiagnoseZeile(diagnose: d)
                                .contentShape(Rectangle())
                                .onTapGesture { bearbeitet = d }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        modelContext.delete(d)
                                    } label: {
                                        Label("Löschen", systemImage: "trash")
                                    }
                                    .tint(.red)
                                    Button { bearbeitet = d } label: {
                                        Label("Bearbeiten", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                        }
                        .onDelete { indexSet in
                            for i in indexSet { modelContext.delete(aktive[i]) }
                        }
                    }
                }

                if !fruehereD.isEmpty {
                    Section("Frühere Diagnosen") {
                        ForEach(fruehereD) { d in
                            DiagnoseZeile(diagnose: d)
                                .contentShape(Rectangle())
                                .onTapGesture { bearbeitet = d }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        modelContext.delete(d)
                                    } label: {
                                        Label("Löschen", systemImage: "trash")
                                    }
                                    .tint(.red)
                                    Button { bearbeitet = d } label: {
                                        Label("Bearbeiten", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                        }
                        .onDelete { indexSet in
                            for i in indexSet { modelContext.delete(fruehereD[i]) }
                        }
                    }
                }
            }
        }
        .navigationTitle("Diagnosen")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { zeigeForm = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $zeigeForm) { DiagnoseForm() }
        .sheet(item: $bearbeitet) { DiagnoseForm(diagnose: $0) }
    }
}

private struct DiagnoseZeile: View {
    let diagnose: Diagnose

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: diagnose.aktiv ? "staroflife.fill" : "archivebox.fill")
                .font(.title3)
                .foregroundStyle(diagnose.aktiv ? Color.blue : Color.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(diagnose.bezeichnung).font(.subheadline.bold())
                if !diagnose.icdCode.isEmpty {
                    Text(diagnose.icdCode).font(.caption).foregroundStyle(.secondary)
                }
                if let datum = diagnose.datum {
                    Text("Seit: " + datum.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(diagnose.aktiv ? "Aktiv" : "Inaktiv")
                .font(.caption2.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(diagnose.aktiv ? Color.blue.opacity(0.15) : Color.secondary.opacity(0.15))
                .foregroundStyle(diagnose.aktiv ? Color.blue : Color.secondary)
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Form

struct DiagnoseForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var diagnose: Diagnose? = nil

    @State private var bezeichnung = ""
    @State private var icdCode = ""
    @State private var aktiv = true
    @State private var hatDatum = false
    @State private var datum = Date()
    @State private var notizen = ""
    @State private var zeigeVorschlaege = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Diagnose") {
                    TextField("Bezeichnung", text: $bezeichnung)

                    Picker("Vorschlag", selection: $bezeichnung) {
                        Text("Eigene Eingabe").tag("")
                        ForEach(Diagnose.haeufigeVorschlaege, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .pickerStyle(.menu)
                    .foregroundStyle(.secondary)

                    TextField("ICD-Code (z.B. M05)", text: $icdCode)
                        .textInputAutocapitalization(.characters)
                }

                Section("Status & Datum") {
                    Toggle("Aktive Diagnose", isOn: $aktiv)
                    Toggle("Diagnosedatum bekannt", isOn: $hatDatum)
                    if hatDatum {
                        DatePicker("Datum", selection: $datum, in: ...Date(), displayedComponents: [.date])
                    }
                }

                Section("Notizen") {
                    TextField("Hinweise, Verlauf…", text: $notizen, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle(diagnose == nil ? "Neue Diagnose" : "Diagnose bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { speichern() }
                        .disabled(bezeichnung.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear { laden() }
    }

    private func laden() {
        guard let d = diagnose else { return }
        bezeichnung = d.bezeichnung
        icdCode = d.icdCode
        aktiv = d.aktiv
        notizen = d.notizen
        if let dt = d.datum { hatDatum = true; datum = dt }
    }

    private func speichern() {
        if let d = diagnose {
            d.bezeichnung = bezeichnung
            d.icdCode = icdCode
            d.aktiv = aktiv
            d.datum = hatDatum ? datum : nil
            d.notizen = notizen
        } else {
            let neu = Diagnose()
            neu.bezeichnung = bezeichnung
            neu.icdCode = icdCode
            neu.aktiv = aktiv
            neu.datum = hatDatum ? datum : nil
            neu.notizen = notizen
            modelContext.insert(neu)
        }
        dismiss()
    }
}
