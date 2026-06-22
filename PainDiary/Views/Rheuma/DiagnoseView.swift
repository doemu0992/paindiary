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
        .navigationBarTitleDisplayMode(.large)
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

    @State private var schritt = 0
    private let maxSchritt = 1
    private let pflichtSchritte: Set<Int> = [0]

    private var kannWeiter: Bool {
        !bezeichnung.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.teal.opacity(0.15)).frame(height: 3)
                        Capsule().fill(Color.teal)
                            .frame(width: geo.size.width * CGFloat(schritt + 1) / CGFloat(maxSchritt + 1), height: 3)
                            .animation(.easeInOut(duration: 0.3), value: schritt)
                    }
                }
                .frame(height: 3).padding(.horizontal).padding(.top, 10)

                Group {
                    switch schritt {
                    case 0: schritt0
                    default: schritt1
                    }
                }
                .frame(maxHeight: .infinity)

                navigationsLeiste
            }
            .navigationTitle(diagnose == nil ? "Neue Diagnose" : "Diagnose bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
            }
        }
        .onAppear { laden() }
    }

    private var schritt0: some View {
        ScrollView {
            VStack(spacing: 20) {
                schrittHeader(symbol: "stethoscope", titel: "Diagnose", untertitel: "Bezeichnung und ICD-Code erfassen")

                VStack(spacing: 0) {
                    TextField("Bezeichnung", text: $bezeichnung)
                        .font(.subheadline).padding(16)
                    Divider().padding(.leading, 16)
                    HStack {
                        Text("Vorschlag").foregroundStyle(.secondary)
                        Spacer()
                        Picker("", selection: $bezeichnung) {
                            Text("Eigene Eingabe").tag("")
                            ForEach(Diagnose.haeufigeVorschlaege, id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                        .pickerStyle(.menu)
                        .foregroundStyle(.secondary)
                    }
                    .font(.subheadline).padding(16)
                    Divider().padding(.leading, 16)
                    HStack {
                        Text("ICD-Code").foregroundStyle(.secondary)
                        Spacer()
                        TextField("z.B. M05", text: $icdCode)
                            .textInputAutocapitalization(.characters)
                            .multilineTextAlignment(.trailing)
                    }
                    .font(.subheadline).padding(16)
                }
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal).padding(.vertical, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground))
    }

    private var schritt1: some View {
        ScrollView {
            VStack(spacing: 20) {
                schrittHeader(symbol: "doc.text.fill", titel: "Details", untertitel: "Status, Datum und Notizen (optional)")

                VStack(spacing: 0) {
                    HStack {
                        Text("Aktive Diagnose").foregroundStyle(.secondary)
                        Spacer()
                        Toggle("", isOn: $aktiv).labelsHidden().tint(.teal)
                    }
                    .font(.subheadline).padding(16)
                    Divider().padding(.leading, 16)
                    HStack {
                        Text("Diagnosedatum bekannt").foregroundStyle(.secondary)
                        Spacer()
                        Toggle("", isOn: $hatDatum).labelsHidden().tint(.teal)
                    }
                    .font(.subheadline).padding(16)
                    if hatDatum {
                        Divider().padding(.leading, 16)
                        HStack {
                            Text("Datum").foregroundStyle(.secondary)
                            Spacer()
                            DatePicker("", selection: $datum, in: ...Date(), displayedComponents: [.date]).labelsHidden()
                        }
                        .font(.subheadline).padding(16)
                    }
                    Divider().padding(.leading, 16)
                    TextField("Hinweise, Verlauf…", text: $notizen, axis: .vertical)
                        .lineLimit(2...5).font(.subheadline).padding(16)
                }
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal).padding(.vertical, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground))
    }

    private var navigationsLeiste: some View {
        HStack(spacing: 12) {
            if schritt > 0 {
                Button { withAnimation { schritt -= 1 } } label: {
                    Text("Zurück").font(.subheadline.bold()).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
            }
            if !pflichtSchritte.contains(schritt) && schritt < maxSchritt {
                Button { withAnimation { schritt += 1 } } label: {
                    Text("Überspringen").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            if schritt < maxSchritt {
                Button { guard kannWeiter else { return }; withAnimation { schritt += 1 } } label: {
                    Text("Weiter ›").font(.subheadline.bold()).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(kannWeiter ? Color.teal : Color.secondary, in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain).disabled(!kannWeiter)
            } else {
                Button { speichern() } label: {
                    Label("Speichern", systemImage: "checkmark").font(.subheadline.bold()).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color.teal, in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
            }
        }
        .padding().background(.ultraThinMaterial)
    }

    private func schrittHeader(symbol: String, titel: String, untertitel: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 32)).foregroundStyle(.teal)
            Text(titel).font(.title3.bold())
            Text(untertitel).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.bottom, 4)
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
