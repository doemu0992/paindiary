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
                statistikSektion

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
                                    NotificationManager.shared.loescheBiologikaErinnerung(injektion: injektion)
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
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { zeigeForm = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $zeigeForm) { BiologikaForm() }
        .sheet(item: $bearbeitet) { BiologikaForm(injektion: $0) }
    }
    // MARK: - Stats

    private var statistikSektion: some View {
        Section {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Überblick", systemImage: "chart.bar.fill")
                        .font(.headline).foregroundStyle(.teal)
                    Divider()
                    HStack(spacing: 0) {
                        statPill("\(injektionen.count)", label: "Injektionen", farbe: .teal)
                        Divider().frame(height: 40)
                        statPill(tagesSeitLetzter, label: "Seit letzter", farbe: .secondary)
                        Divider().frame(height: 40)
                        statPill(naechsteDosisText, label: "Nächste",
                                 farbe: naechsteDosis != nil ? .teal : .secondary)
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

    private var tagesSeitLetzter: String {
        guard let erste = injektionen.first else { return "–" }
        let tage = Calendar.current.dateComponents([.day], from: erste.datum, to: Date()).day ?? 0
        return "\(tage) T."
    }

    private var naechsteDosisText: String {
        guard let nd = naechsteDosis, let n = nd.naechsteDosis else { return "–" }
        let tage = Calendar.current.dateComponents([.day], from: Date(), to: n).day ?? 0
        if tage <= 0 { return "heute" }
        return "in \(tage) T."
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
    @State private var schritt = 0

    private let TINT: Color = .teal
    private let maxSchritt = 1
    private let pflichtSchritte: Set<Int> = [0]
    private let andereOption = "Anderes..."

    private var praeparatListe: [String] {
        BiologikaInjektion.gaengigesPraeparate + [andereOption]
    }

    private var gewaehltesPreaparat: String {
        praeparat == andereOption ? eigenesPraeparat : praeparat
    }

    private var kannWeiter: Bool { !gewaehltesPreaparat.isEmpty }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.2)).frame(height: 3)
                        Capsule().fill(TINT)
                            .frame(width: geo.size.width * CGFloat(schritt + 1) / CGFloat(maxSchritt + 1), height: 3)
                            .animation(.easeInOut(duration: 0.3), value: schritt)
                    }
                }
                .frame(height: 3)
                .padding(.horizontal)
                .padding(.top, 10)

                schrittInhalt
                    .frame(maxHeight: .infinity)

                navigationsLeiste
            }
            .navigationTitle(injektion == nil ? "Neue Injektion" : "Injektion bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
        .onAppear { laden() }
    }

    @ViewBuilder
    private var schrittInhalt: some View {
        switch schritt {
        case 0:
            ScrollView {
                VStack(spacing: 20) {
                    schrittHeader(symbol: "syringe", titel: "Biologika-Injektion",
                                  untertitel: "Präparat, Datum, Dosis und Injektionsort")

                    // Präparat card
                    VStack(spacing: 0) {
                        Picker("Präparat", selection: $praeparat) {
                            ForEach(praeparatListe, id: \.self) { p in
                                Text(p).tag(p)
                            }
                        }
                        .pickerStyle(.menu)
                        .font(.subheadline)
                        .padding(16)
                        if praeparat == andereOption {
                            Divider().padding(.leading, 16)
                            TextField("Präparatname eingeben", text: $eigenesPraeparat)
                                .font(.subheadline).padding(16)
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 12))

                    // Datum & Dosis card
                    VStack(spacing: 0) {
                        DatePicker("Datum", selection: $datum, in: ...Date(), displayedComponents: [.date])
                            .font(.subheadline).padding(16)
                        Divider().padding(.leading, 16)
                        HStack {
                            Text("Dosierung").font(.subheadline)
                            Spacer()
                            TextField("mg", text: $dosierungStr)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 70)
                                .font(.subheadline)
                                .onChange(of: dosierungStr) { _, neu in
                                    if let d = Double(neu.replacingOccurrences(of: ",", with: ".")) {
                                        dosierungMg = d
                                    }
                                }
                            Text("mg").foregroundStyle(.secondary).font(.subheadline)
                        }
                        .padding(16)
                    }
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 12))

                    // Injektionsort button grid
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Injektionsort").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                            ForEach(BiologikaInjektion.injektionsStellen, id: \.self) { opt in
                                let sel = injektionsstelle == opt
                                Button { injektionsstelle = opt } label: {
                                    Text(opt).font(.caption.bold()).frame(maxWidth: .infinity).padding(.vertical, 10)
                                        .background(sel ? TINT : Color(.secondarySystemGroupedBackground))
                                        .foregroundStyle(sel ? .white : .primary)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .animation(.easeInOut(duration: 0.15), value: sel)
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

        default:
            ScrollView {
                VStack(spacing: 20) {
                    schrittHeader(symbol: "doc.text", titel: "Zusatzinfos",
                                  untertitel: "Charge, nächste Dosis und Nebenwirkungen (optional)")

                    // Charge card
                    VStack(spacing: 0) {
                        TextField("Chargen-Nummer (optional)", text: $chargenNummer)
                            .font(.subheadline).padding(16)
                    }
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 12))

                    // Nächste Dosis card
                    VStack(spacing: 0) {
                        Toggle("Erinnerung für nächste Dosis", isOn: $hatErinnerung)
                            .font(.subheadline).padding(16)
                        if hatErinnerung {
                            Divider().padding(.leading, 16)
                            DatePicker(
                                "Nächste Dosis",
                                selection: $naechsteDosis,
                                in: Date()...,
                                displayedComponents: [.date]
                            )
                            .font(.subheadline)
                            .padding(16)
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 12))

                    // Nebenwirkungen card
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Nebenwirkungen / Notizen")
                            .font(.caption).foregroundStyle(.secondary)
                            .padding(.horizontal, 16).padding(.top, 12)
                        TextField("Hinweise, Reaktionen…", text: $notizen, axis: .vertical)
                            .font(.subheadline)
                            .lineLimit(2...4)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                    }
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .padding(.vertical, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
        }
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
                        .background(kannWeiter ? TINT : Color.secondary, in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain).disabled(!kannWeiter)
            } else {
                Button { speichern() } label: {
                    Label("Speichern", systemImage: "checkmark").font(.subheadline.bold()).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(TINT, in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private func schrittHeader(symbol: String, titel: String, untertitel: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 32)).foregroundStyle(TINT)
            Text(titel).font(.title3.bold())
            Text(untertitel).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.bottom, 4)
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
