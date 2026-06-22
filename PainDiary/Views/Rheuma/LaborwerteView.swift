import SwiftUI
import SwiftData
import Charts

struct LaborwerteView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Laborwert.datum, order: .reverse) private var werte: [Laborwert]

    @State private var zeigeForm = false
    @State private var bearbeitet: Laborwert? = nil
    @State private var ausgewaehlterTyp = "Alle"

    private var alleTypen: [String] {
        ["Alle"] + Array(Set(werte.map(\.typ))).sorted()
    }

    private var gefilterteWerte: [Laborwert] {
        ausgewaehlterTyp == "Alle" ? werte : werte.filter { $0.typ == ausgewaehlterTyp }
    }

    var body: some View {
        List {
            if werte.isEmpty {
                ContentUnavailableView(
                    "Keine Laborwerte",
                    systemImage: "testtube.2",
                    description: Text("Tippe auf + um Laborwerte einzutragen.")
                )
                .listRowSeparator(.hidden)
            } else {
                // Filter
                if alleTypen.count > 2 {
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(alleTypen, id: \.self) { typ in
                                    Button {
                                        ausgewaehlterTyp = typ
                                    } label: {
                                        Text(typ)
                                            .font(.caption.bold())
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                ausgewaehlterTyp == typ ? Color.accentColor : Color(.secondarySystemBackground),
                                                in: Capsule()
                                            )
                                            .foregroundStyle(ausgewaehlterTyp == typ ? .white : .primary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                }

                // Chart für ausgewählten Typ
                if ausgewaehlterTyp != "Alle" {
                    let chartDaten = gefilterteWerte.sorted { $0.datum < $1.datum }
                    if chartDaten.count >= 2 {
                        Section {
                            Chart(chartDaten) { w in
                                LineMark(
                                    x: .value("Datum", w.datum, unit: .day),
                                    y: .value("Wert", w.wert)
                                )
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(Color.accentColor)
                                PointMark(
                                    x: .value("Datum", w.datum, unit: .day),
                                    y: .value("Wert", w.wert)
                                )
                                .foregroundStyle(trendFarbe(w))
                                if let max = chartDaten.first?.referenzMax {
                                    RuleMark(y: .value("Ref", max))
                                        .lineStyle(StrokeStyle(dash: [4]))
                                        .foregroundStyle(.orange.opacity(0.6))
                                }
                            }
                            .frame(height: 140)
                            .padding(.vertical, 4)
                        }
                    }
                }

                // List
                ForEach(gefilterteWerte) { w in
                    Button { bearbeitet = w } label: {
                        LaborwertZeile(wert: w)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: loeschen)
            }
        }
        .navigationTitle("Laborwerte")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { zeigeForm = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $zeigeForm) { LaborwertForm() }
        .sheet(item: $bearbeitet) { LaborwertForm(wert: $0) }
    }

    private func trendFarbe(_ w: Laborwert) -> Color {
        if let max = w.referenzMax, w.wert > max { return .red }
        if let min = w.referenzMin, w.wert < min { return .orange }
        return .green
    }

    private func loeschen(_ offsets: IndexSet) {
        offsets.map { gefilterteWerte[$0] }.forEach { modelContext.delete($0) }
    }
}

private struct LaborwertZeile: View {
    let wert: Laborwert

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusFarbe)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(wert.typ).font(.subheadline.bold())
                Text(wert.datum, style: .date).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: wert.wert.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", wert.wert) + " \(wert.einheit)")
                    .font(.subheadline.bold())
                    .foregroundStyle(statusFarbe)
                if let max = wert.referenzMax {
                    Text("Ref: < \(String(format: "%.0f", max))").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var statusFarbe: Color {
        if let max = wert.referenzMax, wert.wert > max { return .red }
        if let min = wert.referenzMin, wert.wert < min { return .orange }
        return .green
    }
}

// MARK: - Form

struct LaborwertForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var wert: Laborwert? = nil

    @State private var datum = Date()
    @State private var typ = ""
    @State private var wertStr = ""
    @State private var einheit = ""
    @State private var refMinStr = ""
    @State private var refMaxStr = ""
    @State private var notizen = ""
    @State private var zeigePicker = false

    @State private var schritt = 0
    private let maxSchritt = 1
    private let pflichtSchritte: Set<Int> = [0]

    private var kannWeiter: Bool { !typ.isEmpty && !wertStr.isEmpty }

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
            .navigationTitle(wert == nil ? "Neuer Wert" : "Wert bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
            }
            .sheet(isPresented: $zeigePicker) {
                NavigationStack {
                    List(LaborwertTyp.rheuma, id: \.name) { t in
                        Button {
                            typ = t.name
                            einheit = t.einheit
                            if let max = t.referenzMax { refMaxStr = String(format: "%.0f", max) }
                            if let min = t.referenzMin { refMinStr = String(format: "%.0f", min) }
                            zeigePicker = false
                        } label: {
                            HStack {
                                Text(t.name).foregroundStyle(.primary)
                                Spacer()
                                Text(t.einheit).foregroundStyle(.secondary).font(.caption)
                            }
                        }
                    }
                    .navigationTitle("Labortyp wählen")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schliessen") { zeigePicker = false } } }
                }
                .presentationDetents([.medium])
            }
        }
        .onAppear { ladeWerte() }
    }

    private var schritt0: some View {
        ScrollView {
            VStack(spacing: 20) {
                schrittHeader(symbol: "drop.fill", titel: "Laborwert", untertitel: "Parameter, Wert und Datum erfassen")

                VStack(spacing: 0) {
                    HStack {
                        TextField("Typ (z.B. CRP)", text: $typ)
                            .font(.subheadline)
                        Button { zeigePicker = true } label: {
                            Image(systemName: "list.bullet").foregroundStyle(Color.teal)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(16)
                    Divider().padding(.leading, 16)
                    HStack(spacing: 8) {
                        TextField("Wert", text: $wertStr).keyboardType(.decimalPad).font(.subheadline)
                        Text("·").foregroundStyle(.secondary)
                        TextField("Einheit", text: $einheit).font(.subheadline)
                    }
                    .padding(16)
                    Divider().padding(.leading, 16)
                    HStack {
                        Text("Datum").foregroundStyle(.secondary)
                        Spacer()
                        DatePicker("", selection: $datum, displayedComponents: [.date]).labelsHidden()
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
                schrittHeader(symbol: "chart.bar.fill", titel: "Referenzwerte", untertitel: "Normbereich und Notizen (optional)")

                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Text("Min").foregroundStyle(.secondary).font(.subheadline)
                        TextField("Min", text: $refMinStr).keyboardType(.decimalPad).font(.subheadline)
                        Text("–").foregroundStyle(.secondary)
                        TextField("Max", text: $refMaxStr).keyboardType(.decimalPad).font(.subheadline)
                        Text("Max").foregroundStyle(.secondary).font(.subheadline)
                    }
                    .padding(16)
                    Divider().padding(.leading, 16)
                    TextField("Notizen", text: $notizen, axis: .vertical)
                        .lineLimit(3...6).font(.subheadline).padding(16)
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

    private func ladeWerte() {
        guard let w = wert else { return }
        datum = w.datum; typ = w.typ; einheit = w.einheit; notizen = w.notizen
        wertStr = String(format: w.wert.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", w.wert)
        if let min = w.referenzMin { refMinStr = String(format: "%.1f", min) }
        if let max = w.referenzMax { refMaxStr = String(format: "%.1f", max) }
    }

    private func speichern() {
        guard let wertD = Double(wertStr.replacingOccurrences(of: ",", with: ".")) else { return }
        let refMin = Double(refMinStr.replacingOccurrences(of: ",", with: "."))
        let refMax = Double(refMaxStr.replacingOccurrences(of: ",", with: "."))
        if let existing = wert {
            existing.datum = datum; existing.typ = typ; existing.wert = wertD
            existing.einheit = einheit; existing.referenzMin = refMin; existing.referenzMax = refMax
            existing.notizen = notizen
        } else {
            let neu = Laborwert(datum: datum, typ: typ, wert: wertD, einheit: einheit)
            neu.referenzMin = refMin; neu.referenzMax = refMax; neu.notizen = notizen
            modelContext.insert(neu)
        }
        dismiss()
    }
}
