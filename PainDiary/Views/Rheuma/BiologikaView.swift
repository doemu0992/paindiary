import SwiftUI
import SwiftData
import Charts

struct BiologikaView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BiologikaInjektion.datum, order: .reverse) private var injektionen: [BiologikaInjektion]

    @State private var zeigeForm = false
    @State private var bearbeitet: BiologikaInjektion? = nil

    private var naechsteDosis: BiologikaInjektion? {
        injektionen.first { i in
            guard let n = i.naechsteDosis else { return false }
            return n > Date()
        }
    }

    private var monatsDaten: [(monat: Date, anzahl: Int)] {
        guard injektionen.count >= 2 else { return [] }
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: injektionen) { i -> Date in
            let comps = calendar.dateComponents([.year, .month], from: i.datum)
            return calendar.date(from: comps) ?? i.datum
        }
        return grouped
            .map { (monat: $0.key, anzahl: $0.value.count) }
            .sorted { $0.monat < $1.monat }
    }

    var body: some View {
        List {
            if injektionen.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Keine Injektionen",
                        systemImage: "cross.vial.fill",
                        description: Text("Tippe auf + um eine Biologika-Injektion einzutragen.")
                    )
                    .listRowSeparator(.hidden)
                }
            } else {
                // Nächste Dosis
                if let naechste = naechsteDosis {
                    Section("Nächste Dosis") {
                        HStack(spacing: 14) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(naechste.praeparat)
                                    .font(.subheadline.bold())
                                if let n = naechste.naechsteDosis {
                                    Text(n, style: .date)
                                        .font(.caption.bold())
                                        .foregroundStyle(Color.accentColor)
                                    Text(n, style: .relative)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.accentColor.opacity(0.08))
                    }
                }

                // Verlaufschart
                if monatsDaten.count >= 2 {
                    Section("Verlauf") {
                        Chart(monatsDaten, id: \.monat) { punkt in
                            BarMark(
                                x: .value("Monat", punkt.monat, unit: .month),
                                y: .value("Injektionen", punkt.anzahl)
                            )
                            .foregroundStyle(Color.accentColor.gradient)
                            .cornerRadius(4)
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .month)) { _ in
                                AxisGridLine()
                                AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                            }
                        }
                        .chartYAxis {
                            AxisMarks(values: .automatic(desiredCount: 4)) { val in
                                AxisGridLine()
                                AxisValueLabel()
                            }
                        }
                        .frame(height: 140)
                        .padding(.vertical, 4)
                    }
                }

                // Alle Einträge
                Section("Alle Einträge") {
                    ForEach(injektionen) { injektion in
                        BiologikaZeile(injektion: injektion)
                            .contentShape(Rectangle())
                            .onTapGesture { bearbeitet = injektion }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    modelContext.delete(injektion)
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                                .tint(.red)
                                Button { bearbeitet = injektion } label: {
                                    Label("Bearbeiten", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                    }
                }
            }
        }
        .navigationTitle("Biologika / Injektionen")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { zeigeForm = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $zeigeForm) { BiologikaForm() }
        .sheet(item: $bearbeitet) { BiologikaForm(injektion: $0) }
    }
}

// MARK: - Zeile

private struct BiologikaZeile: View {
    let injektion: BiologikaInjektion

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "syringe.fill")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(injektion.praeparat)
                    .font(.subheadline.bold())
                HStack(spacing: 6) {
                    Text(injektion.datum, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !injektion.injektionsstelle.isEmpty {
                        Text("·").font(.caption).foregroundStyle(.secondary)
                        Text(injektion.injektionsstelle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(String(format: "%.0f mg", injektion.dosierungMg))
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
                if !injektion.chargenNummer.isEmpty {
                    Text("Ch: \(injektion.chargenNummer)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Form

struct BiologikaForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var injektion: BiologikaInjektion? = nil

    @State private var praeparat = BiologikaInjektion.gaengigesPraeparate[0]
    @State private var eigenesPraeparat = ""
    @State private var datum = Date()
    @State private var dosierungMg = 40.0
    @State private var dosierungStr = "40"
    @State private var chargenNummer = ""
    @State private var injektionsstelle = BiologikaInjektion.injektionsStellen[0]
    @State private var hatErinnerung = false
    @State private var naechsteDosis = Date().addingTimeInterval(14 * 24 * 3600)
    @State private var notizen = ""

    private let andereOption = "Anderes..."

    private var praeparatListe: [String] {
        BiologikaInjektion.gaengigesPraeparate + [andereOption]
    }

    private var gewaehltesPreaparat: String {
        praeparat == andereOption ? eigenesPraeparat : praeparat
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Präparat") {
                    Picker("Präparat", selection: $praeparat) {
                        ForEach(praeparatListe, id: \.self) { p in
                            Text(p).tag(p)
                        }
                    }
                    .pickerStyle(.menu)
                    if praeparat == andereOption {
                        TextField("Präparatname eingeben", text: $eigenesPraeparat)
                    }
                }

                Section("Datum & Dosis") {
                    DatePicker("Datum", selection: $datum, in: ...Date(), displayedComponents: [.date])
                    HStack {
                        Text("Dosierung")
                        Spacer()
                        TextField("mg", text: $dosierungStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                            .onChange(of: dosierungStr) { _, neu in
                                if let d = Double(neu.replacingOccurrences(of: ",", with: ".")) {
                                    dosierungMg = d
                                }
                            }
                        Text("mg").foregroundStyle(.secondary)
                    }
                    TextField("Chargen-Nummer (optional)", text: $chargenNummer)
                }

                Section("Injektionsstelle") {
                    Picker("Stelle", selection: $injektionsstelle) {
                        ForEach(BiologikaInjektion.injektionsStellen, id: \.self) { s in
                            Text(s).tag(s)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Nächste Dosis") {
                    Toggle("Erinnerung setzen", isOn: $hatErinnerung)
                    if hatErinnerung {
                        DatePicker(
                            "Nächste Dosis",
                            selection: $naechsteDosis,
                            in: Date()...,
                            displayedComponents: [.date]
                        )
                    }
                }

                Section("Notizen") {
                    TextField("Hinweise, Reaktionen…", text: $notizen, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(injektion == nil ? "Neue Injektion" : "Injektion bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { speichern() }
                        .disabled(gewaehltesPreaparat.isEmpty)
                }
            }
        }
        .onAppear { laden() }
    }

    private func laden() {
        guard let i = injektion else { return }
        if BiologikaInjektion.gaengigesPraeparate.contains(i.praeparat) {
            praeparat = i.praeparat
        } else {
            praeparat = andereOption
            eigenesPraeparat = i.praeparat
        }
        datum = i.datum
        dosierungMg = i.dosierungMg
        dosierungStr = String(format: i.dosierungMg.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", i.dosierungMg)
        chargenNummer = i.chargenNummer
        injektionsstelle = i.injektionsstelle
        notizen = i.notizen
        if let n = i.naechsteDosis {
            hatErinnerung = true
            naechsteDosis = n
        }
    }

    private func speichern() {
        let name = gewaehltesPreaparat
        let nm = NotificationManager.shared
        if let i = injektion {
            nm.loescheBiologikaErinnerung(injektion: i)
            i.praeparat = name
            i.datum = datum
            i.dosierungMg = dosierungMg
            i.chargenNummer = chargenNummer
            i.injektionsstelle = injektionsstelle
            i.naechsteDosis = hatErinnerung ? naechsteDosis : nil
            i.notizen = notizen
            if hatErinnerung { nm.planeBiologikaErinnerung(injektion: i) }
        } else {
            let neu = BiologikaInjektion()
            neu.praeparat = name
            neu.datum = datum
            neu.dosierungMg = dosierungMg
            neu.chargenNummer = chargenNummer
            neu.injektionsstelle = injektionsstelle
            neu.naechsteDosis = hatErinnerung ? naechsteDosis : nil
            neu.notizen = notizen
            modelContext.insert(neu)
            if hatErinnerung { nm.planeBiologikaErinnerung(injektion: neu) }
        }
        dismiss()
    }
}
