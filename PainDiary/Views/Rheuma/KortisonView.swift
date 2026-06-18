import SwiftUI
import SwiftData
import Charts

struct KortisonView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \KortisonEintrag.datum, order: .reverse) private var eintraege: [KortisonEintrag]

    @State private var zeigeForm = false
    @State private var bearbeitet: KortisonEintrag? = nil

    private var chartDaten: [KortisonEintrag] {
        eintraege.sorted { $0.datum < $1.datum }
    }

    var body: some View {
        List {
            if eintraege.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Kein Kortison-Tagebuch",
                        systemImage: "pills.fill",
                        description: Text("Tippe auf + um eine Kortison-Einnahme einzutragen.")
                    )
                    .listRowSeparator(.hidden)
                }
            } else {
                statistikSektion

                // Verlaufschart
                if chartDaten.count >= 2 {
                    Section("Verlauf") {
                        Chart(chartDaten) { eintrag in
                            LineMark(
                                x: .value("Datum", eintrag.datum, unit: .day),
                                y: .value("mg", eintrag.dosierungMg)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.orange)
                            PointMark(
                                x: .value("Datum", eintrag.datum, unit: .day),
                                y: .value("mg", eintrag.dosierungMg)
                            )
                            .foregroundStyle(eintrag.istSchubTherapie ? Color.red : Color.orange)
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .month)) { _ in
                                AxisGridLine()
                                AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                            }
                        }
                        .chartYAxis {
                            AxisMarks { val in
                                AxisGridLine()
                                AxisValueLabel {
                                    if let v = val.as(Double.self) {
                                        Text(String(format: "%.0f mg", v))
                                            .font(.caption2)
                                    }
                                }
                            }
                        }
                        .frame(height: 140)
                        .padding(.vertical, 4)
                    }
                }

                // Einträge
                Section("Einträge") {
                    ForEach(eintraege) { eintrag in
                        KortisonZeile(eintrag: eintrag)
                            .contentShape(Rectangle())
                            .onTapGesture { bearbeitet = eintrag }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    modelContext.delete(eintrag)
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                                .tint(.red)
                                Button { bearbeitet = eintrag } label: {
                                    Label("Bearbeiten", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                    }
                }
            }
        }
        .navigationTitle("Kortison-Tagebuch")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { zeigeForm = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $zeigeForm) { KortisonForm() }
        .sheet(item: $bearbeitet) { KortisonForm(eintrag: $0) }
    }
    // MARK: - Stats

    private var eintraege30: [KortisonEintrag] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return eintraege.filter { $0.datum >= cutoff }
    }

    private var avgDosis30: Double {
        guard !eintraege30.isEmpty else { return 0 }
        return eintraege30.map(\.dosierungMg).reduce(0, +) / Double(eintraege30.count)
    }

    private var statistikSektion: some View {
        Section {
            let schubAnzahl = eintraege.filter(\.istSchubTherapie).count
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    Label("30-Tage-Überblick", systemImage: "chart.bar.fill")
                        .font(.headline).foregroundStyle(.orange)
                    Divider()
                    HStack(spacing: 0) {
                        statPill("\(eintraege.count)", label: "Einträge", farbe: .orange)
                        Divider().frame(height: 40)
                        statPill("\(schubAnzahl)", label: "Schub-Einnahmen",
                                 farbe: schubAnzahl > 0 ? .red : .green)
                        Divider().frame(height: 40)
                        statPill(eintraege30.isEmpty ? "–" : String(format: "%.0f mg", avgDosis30),
                                 label: "Ø Dosis (30 T.)", farbe: .orange)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
            }
            .padding(.vertical, 4)
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.clear)
    }

    private func statPill(_ wert: String, label: String, farbe: Color) -> some View {
        VStack(spacing: 4) {
            Text(wert).font(.title2.bold()).foregroundStyle(farbe)
            Text(label).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Zeile

private struct KortisonZeile: View {
    let eintrag: KortisonEintrag

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "pills.fill")
                .font(.title3)
                .foregroundStyle(.orange)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(eintrag.praeparat)
                        .font(.subheadline.bold())
                    if eintrag.istSchubTherapie {
                        Text("Schub")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.15), in: Capsule())
                            .foregroundStyle(.red)
                    }
                }
                Text(eintrag.datum, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !eintrag.notizen.isEmpty {
                    Text(eintrag.notizen)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(String(format: "%.1f mg", eintrag.dosierungMg))
                .font(.subheadline.bold())
                .foregroundStyle(.orange)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Form

struct KortisonForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var eintrag: KortisonEintrag? = nil

    @State private var praeparat = "Prednison"
    @State private var datum = Date()
    @State private var dosierungMg = 5.0
    @State private var istSchubTherapie = false
    @State private var notizen = ""

    private let schrittGroesse = 0.5
    private let minDosis = 0.5
    private let maxDosis = 200.0

    var body: some View {
        NavigationStack {
            Form {
                Section("Präparat") {
                    Picker("Präparat", selection: $praeparat) {
                        ForEach(KortisonEintrag.praeparate, id: \.self) { p in
                            Text(p).tag(p)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Datum") {
                    DatePicker("Datum", selection: $datum, in: ...Date(), displayedComponents: [.date])
                }

                Section {
                    VStack(spacing: 12) {
                        Text(String(format: "%.1f mg", dosierungMg))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.orange)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 4)

                        Stepper(
                            value: $dosierungMg,
                            in: minDosis...maxDosis,
                            step: schrittGroesse
                        ) {
                            EmptyView()
                        }

                        Slider(
                            value: $dosierungMg,
                            in: minDosis...maxDosis,
                            step: schrittGroesse
                        ) {
                            Text("Dosierung")
                        } minimumValueLabel: {
                            Text("0.5").font(.caption2).foregroundStyle(.secondary)
                        } maximumValueLabel: {
                            Text("200").font(.caption2).foregroundStyle(.secondary)
                        }
                        .tint(.orange)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Dosierung")
                } footer: {
                    Text("0.5er Schritte · 0.5 – 200 mg")
                        .font(.caption)
                }

                Section {
                    Toggle("Schubtherapie (erhöhte Dosis)", isOn: $istSchubTherapie)
                        .tint(.red)
                }

                Section("Notizen") {
                    TextField("Hinweise, Nebenwirkungen…", text: $notizen, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(eintrag == nil ? "Neuer Eintrag" : "Eintrag bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { speichern() }
                }
            }
        }
        .onAppear { laden() }
    }

    private func laden() {
        guard let e = eintrag else { return }
        praeparat = e.praeparat
        datum = e.datum
        dosierungMg = e.dosierungMg
        istSchubTherapie = e.istSchubTherapie
        notizen = e.notizen
    }

    private func speichern() {
        if let e = eintrag {
            e.praeparat = praeparat
            e.datum = datum
            e.dosierungMg = dosierungMg
            e.istSchubTherapie = istSchubTherapie
            e.notizen = notizen
        } else {
            let neu = KortisonEintrag()
            neu.praeparat = praeparat
            neu.datum = datum
            neu.dosierungMg = dosierungMg
            neu.istSchubTherapie = istSchubTherapie
            neu.notizen = notizen
            modelContext.insert(neu)
        }
        dismiss()
    }
}
