import SwiftUI
import SwiftData

struct ImpfpassView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Impftermin.impfstoff) private var impfungen: [Impftermin]

    @State private var zeigeForm = false
    @State private var bearbeitet: Impftermin? = nil
    @State private var zeigeStandard = false

    var body: some View {
        List {
            if impfungen.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Kein Impfpass",
                        systemImage: "syringe.fill",
                        description: Text("Tippe auf + um Impfungen einzutragen, oder lade Standardimpfungen für Rheumapatienten.")
                    )
                    .listRowSeparator(.hidden)

                    Button {
                        ladeStandardImpfungen()
                    } label: {
                        Label("Standardimpfungen laden", systemImage: "wand.and.stars")
                    }
                }
            } else {
                let faellig = impfungen.filter { $0.dringlichkeit == .ueberfaellig || $0.dringlichkeit == .bald }
                if !faellig.isEmpty {
                    Section("Ausstehend / Bald fällig") {
                        ForEach(faellig) { i in
                            ImpfZeile(impfung: i)
                                .contentShape(Rectangle())
                                .onTapGesture { bearbeitet = i }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        modelContext.delete(i)
                                    } label: {
                                        Label("Löschen", systemImage: "trash")
                                    }
                                    .tint(.red)
                                    Button { bearbeitet = i } label: {
                                        Label("Bearbeiten", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                        }
                    }
                }

                let aktuell = impfungen.filter { $0.dringlichkeit == .ok }
                if !aktuell.isEmpty {
                    Section("Aktuell") {
                        ForEach(aktuell) { i in
                            ImpfZeile(impfung: i)
                                .contentShape(Rectangle())
                                .onTapGesture { bearbeitet = i }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        modelContext.delete(i)
                                    } label: {
                                        Label("Löschen", systemImage: "trash")
                                    }
                                    .tint(.red)
                                    Button { bearbeitet = i } label: {
                                        Label("Bearbeiten", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                        }
                    }
                }
            }
        }
        .navigationTitle("Impfpass")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { zeigeForm = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $zeigeForm) { ImpfForm() }
        .sheet(item: $bearbeitet) { ImpfForm(impfung: $0) }
    }

    private func ladeStandardImpfungen() {
        for standard in Impftermin.standardImpfungen {
            modelContext.insert(standard)
        }
    }
}

private struct ImpfZeile: View {
    let impfung: Impftermin

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: dringlichkeitSymbol)
                .font(.title3)
                .foregroundStyle(dringlichkeitFarbe)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(impfung.impfstoff).font(.subheadline.bold())
                if let letzte = impfung.letzteImpfung {
                    Text("Zuletzt: " + letzte.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Noch nicht geimpft").font(.caption).foregroundStyle(.orange)
                }
                if !impfung.notizen.isEmpty {
                    Text(impfung.notizen).font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                if let naechste = impfung.naechsteFaelligkeit {
                    Text(naechste, style: .date).font(.caption.bold()).foregroundStyle(dringlichkeitFarbe)
                    if impfung.dringlichkeit == .bald {
                        Text("Bald fällig").font(.caption2).foregroundStyle(.orange)
                    } else if impfung.dringlichkeit == .ueberfaellig {
                        Text("Überfällig").font(.caption2.bold()).foregroundStyle(.red)
                    }
                } else if impfung.letzteImpfung == nil {
                    Text("Ausstehend").font(.caption).foregroundStyle(.red)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var dringlichkeitFarbe: Color {
        switch impfung.dringlichkeit {
        case .ok:          return .green
        case .bald:        return .orange
        case .ueberfaellig: return .red
        }
    }

    private var dringlichkeitSymbol: String {
        switch impfung.dringlichkeit {
        case .ok:          return "checkmark.circle.fill"
        case .bald:        return "exclamationmark.circle.fill"
        case .ueberfaellig: return "xmark.circle.fill"
        }
    }
}

// MARK: - Form

struct ImpfForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var impfung: Impftermin? = nil

    @State private var impfstoff = ""
    @State private var hatLetzte = false
    @State private var letzteImpfung = Date()
    @State private var intervallMonate = 12
    @State private var notizen = ""

    @State private var schritt = 0
    private let intervalle = [6: "6 Monate", 12: "1 Jahr", 24: "2 Jahre",
                               36: "3 Jahre", 60: "5 Jahre", 120: "10 Jahre", 0: "Einmalig"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                schritt0
                    .frame(maxHeight: .infinity)
                speichernLeiste
            }
            .navigationTitle(impfung == nil ? "Neue Impfung" : "Impfung bearbeiten")
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
                schrittHeader(symbol: "syringe.fill", titel: "Impfung", untertitel: "Impfdaten erfassen")

                VStack(spacing: 0) {
                    TextField("Name (z.B. Influenza)", text: $impfstoff)
                        .font(.subheadline).padding(16)
                    Divider().padding(.leading, 16)
                    HStack {
                        Text("Datum bekannt").foregroundStyle(.secondary)
                        Spacer()
                        Toggle("", isOn: $hatLetzte).labelsHidden().tint(.teal)
                    }
                    .font(.subheadline).padding(16)
                    if hatLetzte {
                        Divider().padding(.leading, 16)
                        HStack {
                            Text("Datum").foregroundStyle(.secondary)
                            Spacer()
                            DatePicker("", selection: $letzteImpfung, in: ...Date(), displayedComponents: [.date]).labelsHidden()
                        }
                        .font(.subheadline).padding(16)
                    }
                    Divider().padding(.leading, 16)
                    HStack {
                        Text("Intervall").foregroundStyle(.secondary)
                        Spacer()
                        Picker("", selection: $intervallMonate) {
                            ForEach(Array(intervalle.keys).sorted(), id: \.self) { k in
                                Text(intervalle[k]!).tag(k)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .font(.subheadline).padding(16)
                    Divider().padding(.leading, 16)
                    TextField("Hinweise, Chargen-Nr…", text: $notizen, axis: .vertical)
                        .lineLimit(2...4).font(.subheadline).padding(16)
                }
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal).padding(.vertical, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground))
    }

    private var speichernLeiste: some View {
        Button { speichern() } label: {
            Label("Speichern", systemImage: "checkmark").font(.subheadline.bold()).foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(impfstoff.isEmpty ? Color.secondary : Color.teal, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(impfstoff.isEmpty)
        .padding()
        .background(.ultraThinMaterial)
    }

    private func schrittHeader(symbol: String, titel: String, untertitel: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 32)).foregroundStyle(.teal)
            Text(titel).font(.title3.bold())
            Text(untertitel).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.bottom, 4)
    }

    private func laden() {
        guard let i = impfung else { return }
        impfstoff = i.impfstoff; intervallMonate = i.intervallMonate; notizen = i.notizen
        if let l = i.letzteImpfung { hatLetzte = true; letzteImpfung = l }
    }

    private func speichern() {
        if let i = impfung {
            i.impfstoff = impfstoff; i.intervallMonate = intervallMonate; i.notizen = notizen
            i.letzteImpfung = hatLetzte ? letzteImpfung : nil
        } else {
            let neu = Impftermin(impfstoff: impfstoff, intervallMonate: intervallMonate)
            neu.letzteImpfung = hatLetzte ? letzteImpfung : nil
            neu.notizen = notizen
            modelContext.insert(neu)
        }
        dismiss()
    }
}
