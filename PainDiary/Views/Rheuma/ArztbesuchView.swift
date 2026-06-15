import SwiftUI
import SwiftData

struct ArztbesuchView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Arztbesuch.datum, order: .reverse) private var besuche: [Arztbesuch]

    @State private var zeigeForm = false
    @State private var bearbeitet: Arztbesuch? = nil

    var body: some View {
        List {
            if besuche.isEmpty {
                ContentUnavailableView(
                    "Keine Arztbesuche",
                    systemImage: "stethoscope",
                    description: Text("Tippe auf + um einen Arztbesuch zu dokumentieren.")
                )
                .listRowSeparator(.hidden)
            } else {
                // Next appointment reminder
                if let naechster = besuche.compactMap(\.naechsterTermin).filter({ $0 > Date() }).min() {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.title2).foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Nächster Termin")
                                    .font(.subheadline.bold())
                                Text(naechster, style: .date)
                                    .font(.caption).foregroundStyle(.secondary)
                                Text(naechster, style: .relative)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Verlauf") {
                    ForEach(besuche) { besuch in
                        Button { bearbeitet = besuch } label: {
                            ArztbesuchZeile(besuch: besuch)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: loeschen)
                }
            }
        }
        .navigationTitle("Arztbesuche")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { zeigeForm = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $zeigeForm) { ArztbesuchForm() }
        .sheet(item: $bearbeitet) { ArztbesuchForm(besuch: $0) }
    }

    private func loeschen(_ offsets: IndexSet) {
        offsets.map { besuche[$0] }.forEach { modelContext.delete($0) }
    }
}

private struct ArztbesuchZeile: View {
    let besuch: Arztbesuch

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(besuch.datum, style: .date)
                    .font(.subheadline.bold())
                if !besuch.fachgebiet.isEmpty {
                    Text("·").foregroundStyle(.secondary)
                    Text(besuch.fachgebiet)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            if !besuch.arzt.isEmpty {
                Text(besuch.arzt).font(.caption).foregroundStyle(.secondary)
            }
            if !besuch.befund.isEmpty {
                Text(besuch.befund)
                    .font(.caption)
                    .foregroundStyle(.primary.opacity(0.8))
                    .lineLimit(2)
            }
            if !besuch.therapieaenderung.isEmpty {
                Label(besuch.therapieaenderung, systemImage: "pills.fill")
                    .font(.caption)
                    .foregroundStyle(.purple)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Form

struct ArztbesuchForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var besuch: Arztbesuch? = nil

    @State private var datum = Date()
    @State private var arzt = ""
    @State private var fachgebiet = ""
    @State private var befund = ""
    @State private var therapieaenderung = ""
    @State private var hatNaechstenTermin = false
    @State private var naechsterTermin = Date()
    @State private var notizen = ""

    private let fachgebiete = ["Rheumatologie", "Allgemeinmedizin", "Orthopädie", "Neurologie",
                                "Dermatologie", "Kardiologie", "Gastroenterologie", "Innere Medizin"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Besuch") {
                    DatePicker("Datum", selection: $datum, displayedComponents: [.date])
                    TextField("Arzt / Ärztin", text: $arzt)
                    Picker("Fachgebiet", selection: $fachgebiet) {
                        Text("–").tag("")
                        ForEach(fachgebiete, id: \.self) { Text($0).tag($0) }
                    }
                }

                Section("Befund & Therapie") {
                    TextField("Befund / Diagnose", text: $befund, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Therapieänderung / Medikamente", text: $therapieaenderung, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Nächster Termin") {
                    Toggle("Nächsten Termin eintragen", isOn: $hatNaechstenTermin)
                    if hatNaechstenTermin {
                        DatePicker("Datum", selection: $naechsterTermin, in: Date()..., displayedComponents: [.date])
                    }
                }

                Section("Notizen") {
                    TextField("Weitere Notizen…", text: $notizen, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(besuch == nil ? "Neuer Besuch" : "Besuch bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { speichern() }
                }
            }
        }
        .onAppear { laden() }
    }

    private func laden() {
        guard let b = besuch else { return }
        datum = b.datum; arzt = b.arzt; fachgebiet = b.fachgebiet
        befund = b.befund; therapieaenderung = b.therapieaenderung; notizen = b.notizen
        if let t = b.naechsterTermin { hatNaechstenTermin = true; naechsterTermin = t }
    }

    private func speichern() {
        if let b = besuch {
            b.datum = datum; b.arzt = arzt; b.fachgebiet = fachgebiet
            b.befund = befund; b.therapieaenderung = therapieaenderung
            b.naechsterTermin = hatNaechstenTermin ? naechsterTermin : nil
            b.notizen = notizen
        } else {
            let neu = Arztbesuch(datum: datum, arzt: arzt, fachgebiet: fachgebiet)
            neu.befund = befund; neu.therapieaenderung = therapieaenderung
            neu.naechsterTermin = hatNaechstenTermin ? naechsterTermin : nil
            neu.notizen = notizen
            modelContext.insert(neu)
        }
        dismiss()
    }
}
