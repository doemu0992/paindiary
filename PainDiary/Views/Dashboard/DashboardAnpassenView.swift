import SwiftUI
import SwiftData

struct DashboardAnpassenView: View {
    @Binding var kacheln: [KachelKonfiguration]
    @Environment(\.dismiss) private var dismiss
    @State private var editMode: EditMode = .inactive
    @State private var pickerKachel: KachelKonfiguration?

    private var analyseHinzufuegbar: [KachelTyp] {
        let bereitsIds = Set(kacheln.map(\.id))
        return [
            .wetterSchmerz, .stressSchmerz, .schlafSchmerz,
            .tageszeitVerteilung, .koerperstellen, .schmerzarten,
            .stimmungsTrend, .midasKachel
        ].filter { !bereitsIds.contains($0.rawValue) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach($kacheln) { $kachel in
                        HStack(spacing: 12) {
                            Image(systemName: kachel.typ.symbol)
                                .foregroundStyle(kachelFarbe(kachel.typ))
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(kachel.anzeigeTitel).font(.subheadline)
                                Text(kachel.typ.abschnitt)
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if kachel.typ == .konfigKorrelation {
                                Button {
                                    pickerKachel = kachel
                                } label: {
                                    Image(systemName: "pencil.circle")
                                        .foregroundStyle(.indigo)
                                }
                                .buttonStyle(.plain)
                            }
                            Button {
                                withAnimation { kachel.sichtbar.toggle() }
                            } label: {
                                Image(systemName: kachel.sichtbar ? "eye.fill" : "eye.slash")
                                    .foregroundStyle(kachel.sichtbar ? Color.primary : Color.secondary.opacity(0.4))
                            }
                            .buttonStyle(.plain)
                        }
                        .opacity(kachel.sichtbar ? 1 : 0.5)
                    }
                    .onMove { kacheln.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { offsets in
                        let loeschbar = offsets.filter { !KachelTyp.basisKacheln.contains(kacheln[$0].typ) }
                        withAnimation { kacheln.remove(atOffsets: IndexSet(loeschbar)) }
                    }
                } header: {
                    HStack {
                        Text("Reihenfolge")
                        Spacer()
                        Text("Sichtbar").font(.caption2)
                    }
                } footer: {
                    Text("Tippe auf das Auge zum Ein-/Ausblenden. Stift-Icon: Korrelation bearbeiten. Im Bearbeiten-Modus: verschieben oder löschen.")
                        .font(.caption2)
                }

                if !analyseHinzufuegbar.isEmpty {
                    Section("Analyse hinzufügen") {
                        ForEach(analyseHinzufuegbar, id: \.self) { typ in
                            Button {
                                withAnimation {
                                    kacheln.append(KachelKonfiguration(id: typ.rawValue, typ: typ))
                                }
                            } label: {
                                HStack {
                                    Image(systemName: typ.symbol)
                                        .foregroundStyle(kachelFarbe(typ))
                                        .frame(width: 24)
                                    Text(typ.titel).font(.subheadline).foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "plus.circle.fill").foregroundStyle(.teal)
                                }
                            }
                        }
                    }
                }

                Section("Eigene Korrelation") {
                    Button {
                        pickerKachel = KachelKonfiguration(id: "__neu__", typ: .konfigKorrelation)
                    } label: {
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                                .foregroundStyle(.indigo).frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Neue Korrelation konfigurieren")
                                    .font(.subheadline).foregroundStyle(.primary)
                                Text("Region, Schmerzart, Zeitraum & mehr")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "plus.circle.fill").foregroundStyle(.indigo)
                        }
                    }
                }

                Section {
                    Button("Standard wiederherstellen", role: .destructive) {
                        withAnimation { kacheln = KachelKonfiguration.standard }
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .navigationTitle("Dashboard anpassen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(editMode == .active ? "Fertig" : "Bearbeiten") {
                        withAnimation { editMode = editMode == .active ? .inactive : .active }
                    }
                }
            }
            .sheet(item: $pickerKachel) { kachel in
                let istNeu = kachel.id == "__neu__"
                KorrelationsPickerView(existierend: istNeu ? nil : kachel) { bearbeitet in
                    if istNeu {
                        withAnimation { kacheln.append(bearbeitet) }
                    } else {
                        if let idx = kacheln.firstIndex(where: { $0.id == bearbeitet.id }) {
                            kacheln[idx] = bearbeitet
                        }
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func kachelFarbe(_ typ: KachelTyp) -> Color {
        switch typ {
        case .schmerzUebersicht, .hautveraenderung, .tageszeitVerteilung: return .orange
        case .schmerzverlauf, .medikamente, .schmerzarten: return .blue
        case .stimmungStress, .zyklus, .stimmungsTrend: return .pink
        case .schnellLinks, .konfigKorrelation: return .indigo
        case .wetterSchmerz: return .cyan
        case .stressSchmerz: return .yellow
        case .schlafSchmerz: return .purple
        case .koerperstellen: return .teal
        case .midasKachel: return .purple
        case .migraeneKachel: return .purple
        }
    }
}

// MARK: - Korrelations-Picker

struct KorrelationsPickerView: View {
    var existierend: KachelKonfiguration?
    var onFertig: (KachelKonfiguration) -> Void
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \PainEntry.datum, order: .reverse) private var allePainEntries: [PainEntry]
    @Query private var medikamente: [Dauermedikation]

    @State private var xVariable: String
    @State private var yVariable: String
    @State private var filterRegionen: Set<String>
    @State private var filterSchmerzarten: Set<String>
    @State private var filterMedikament: String
    @State private var filterZeitraum: Int
    @State private var filterMinStaerke: Int
    @State private var diagrammTyp: String

    init(existierend: KachelKonfiguration? = nil, onFertig: @escaping (KachelKonfiguration) -> Void) {
        self.existierend = existierend
        self.onFertig = onFertig
        _xVariable       = State(initialValue: existierend?.xVariable       ?? "wetter")
        _yVariable       = State(initialValue: existierend?.yVariable       ?? "schmerzstaerke")
        _filterRegionen  = State(initialValue: Set(existierend?.filterRegionen  ?? []))
        _filterSchmerzarten = State(initialValue: Set(existierend?.filterSchmerzarten ?? []))
        _filterMedikament   = State(initialValue: existierend?.filterMedikament   ?? "")
        _filterZeitraum     = State(initialValue: existierend?.filterZeitraum     ?? 0)
        _filterMinStaerke   = State(initialValue: existierend?.filterMinStaerke   ?? 0)
        _diagrammTyp        = State(initialValue: existierend?.diagrammTyp        ?? "auto")
    }

    // MARK: - Verfügbare Daten

    private var alleRegionen: [String] {
        let raw = allePainEntries
            .filter { !$0.istHautEintrag }
            .flatMap { $0.koerperstelle.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
            .filter { !$0.isEmpty }
        return Array(Set(raw)).sorted()
    }

    private var alleSchmerzarten: [String] {
        let raw = allePainEntries
            .filter { !$0.istHautEintrag }
            .map(\.schmerzart)
            .filter { !$0.isEmpty }
        return Array(Set(raw)).sorted()
    }

    private var aktiveMedikamente: [String] {
        medikamente.filter(\.aktiv).map(\.name).sorted()
    }

    // MARK: - Optionen

    let xOptionen: [(id: String, name: String, symbol: String, farbe: Color)] = [
        ("wetter",     "Wetter",     "cloud.sun.fill",    .cyan),
        ("stress",     "Stress",     "bolt.fill",         .yellow),
        ("schlaf",     "Schlaf",     "moon.zzz.fill",     .purple),
        ("stimmung",   "Stimmung",   "heart.fill",        .pink),
        ("tageszeit",  "Tageszeit",  "clock.fill",        .orange),
        ("wochentag",  "Wochentag",  "calendar",          .blue),
        ("medikament", "Medikament", "pill.fill",         .green),
    ]

    let yOptionen: [(id: String, name: String, symbol: String, farbe: Color)] = [
        ("schmerzstaerke", "Schmerzstärke", "waveform.path.ecg", .orange),
        ("stimmung",       "Stimmung",      "heart.fill",        .pink),
        ("stress",         "Stress",        "bolt.fill",         .yellow),
        ("schlafstunden",  "Schlafdauer",   "moon.zzz.fill",     .purple),
    ]

    private let zeitraumOptionen = [(0, "Alles"), (90, "90 T"), (30, "30 T"), (7, "7 T")]

    // MARK: - Auto-Titel

    private var autoTitel: String {
        var prefix = ""
        if !filterRegionen.isEmpty {
            prefix = filterRegionen.sorted().joined(separator: " + ") + ": "
        } else if !filterSchmerzarten.isEmpty {
            prefix = filterSchmerzarten.sorted().first.map { $0 + ": " } ?? ""
        }
        let x = xOptionen.first { $0.id == xVariable }?.name ?? xVariable
        let y = yOptionen.first { $0.id == yVariable }?.name ?? yVariable
        return "\(prefix)\(x) → \(y)"
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // X-Achse
                Section("Einflussfaktor (X-Achse)") {
                    ForEach(xOptionen, id: \.id) { opt in
                        Button { xVariable = opt.id } label: {
                            HStack {
                                Image(systemName: opt.symbol).foregroundStyle(opt.farbe).frame(width: 24)
                                Text(opt.name).foregroundStyle(.primary)
                                Spacer()
                                if xVariable == opt.id {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                }

                // Y-Achse
                Section("Ergebnis (Y-Achse)") {
                    ForEach(yOptionen, id: \.id) { opt in
                        Button { yVariable = opt.id } label: {
                            HStack {
                                Image(systemName: opt.symbol).foregroundStyle(opt.farbe).frame(width: 24)
                                Text(opt.name).foregroundStyle(.primary)
                                Spacer()
                                if yVariable == opt.id {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                }

                // Filter: Körperregion
                if !alleRegionen.isEmpty {
                    Section {
                        ForEach(alleRegionen, id: \.self) { region in
                            let aktiv = filterRegionen.contains(region)
                            Button {
                                withAnimation { if aktiv { filterRegionen.remove(region) } else { filterRegionen.insert(region) } }
                            } label: {
                                HStack {
                                    Image(systemName: aktiv ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(aktiv ? Color.teal : Color.secondary)
                                    Text(region).foregroundStyle(.primary)
                                }
                            }
                        }
                    } header: {
                        Text("Körperregion filtern")
                    } footer: {
                        Text(filterRegionen.isEmpty ? "Alle Körperstellen" : "\(filterRegionen.count) ausgewählt — nur diese Einträge fliessen in die Analyse ein.")
                            .font(.caption2)
                    }
                }

                // Filter: Schmerzart
                if !alleSchmerzarten.isEmpty {
                    Section {
                        ForEach(alleSchmerzarten, id: \.self) { art in
                            let aktiv = filterSchmerzarten.contains(art)
                            Button {
                                withAnimation { if aktiv { filterSchmerzarten.remove(art) } else { filterSchmerzarten.insert(art) } }
                            } label: {
                                HStack {
                                    Image(systemName: aktiv ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(aktiv ? Color.orange : Color.secondary)
                                    Text(art).foregroundStyle(.primary)
                                }
                            }
                        }
                    } header: {
                        Text("Schmerzart filtern")
                    } footer: {
                        Text(filterSchmerzarten.isEmpty ? "Alle Schmerzarten" : "\(filterSchmerzarten.count) ausgewählt")
                            .font(.caption2)
                    }
                }

                // Filter: Medikament
                if !aktiveMedikamente.isEmpty {
                    Section {
                        Button {
                            withAnimation { filterMedikament = "" }
                        } label: {
                            HStack {
                                Image(systemName: filterMedikament.isEmpty ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(filterMedikament.isEmpty ? Color.accentColor : Color.secondary)
                                Text("Kein Filter").foregroundStyle(.primary)
                            }
                        }
                        ForEach(aktiveMedikamente, id: \.self) { med in
                            let aktiv = filterMedikament == med
                            Button {
                                withAnimation { filterMedikament = aktiv ? "" : med }
                            } label: {
                                HStack {
                                    Image(systemName: aktiv ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(aktiv ? Color.accentColor : Color.secondary)
                                    Text(med).foregroundStyle(.primary)
                                }
                            }
                        }
                    } header: {
                        Text("Medikament filtern")
                    } footer: {
                        Text("Nur Einträge von Tagen, an denen dieses Medikament eingenommen wurde.")
                            .font(.caption2)
                    }
                }

                // Filter: Zeitraum
                Section("Zeitraum") {
                    Picker("Zeitraum", selection: $filterZeitraum) {
                        ForEach(zeitraumOptionen, id: \.0) { val, label in
                            Text(label).tag(val)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                // Filter: Mindest-Stärke
                Section {
                    HStack {
                        Image(systemName: "waveform.path.ecg").foregroundStyle(.red)
                        Text(filterMinStaerke == 0 ? "Alle Stärken" : "≥ \(filterMinStaerke) / 10")
                            .foregroundStyle(filterMinStaerke == 0 ? .secondary : .primary)
                        Spacer()
                        Stepper("", value: $filterMinStaerke, in: 0...9)
                            .labelsHidden()
                    }
                } header: {
                    Text("Mindest-Schmerzstärke")
                } footer: {
                    Text("Nur Einträge ab dieser Intensität berücksichtigen.")
                        .font(.caption2)
                }

                // Diagrammtyp
                Section {
                    Picker("Typ", selection: $diagrammTyp) {
                        Text("Auto").tag("auto")
                        Text("Balken").tag("balken")
                        Text("Streuung").tag("scatter")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                } header: {
                    Text("Diagrammtyp")
                } footer: {
                    Text("Auto: Balken für Kategorien (Wetter, Tageszeit…), Streuung für Schlaf.")
                        .font(.caption2)
                }

                // Vorschau-Titel
                Section("Titel (Vorschau)") {
                    HStack(spacing: 12) {
                        Image(systemName: "slider.horizontal.3").foregroundStyle(.indigo)
                        Text(autoTitel).font(.subheadline)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(existierend == nil ? "Neue Korrelation" : "Korrelation bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(existierend == nil ? "Hinzufügen" : "Speichern") {
                        let uid = String(UUID().uuidString.prefix(8))
                        let id = existierend?.id ?? "konfigKorrelation_\(xVariable)_\(yVariable)_\(uid)"
                        let kachel = KachelKonfiguration(
                            id: id,
                            typ: .konfigKorrelation,
                            xVariable: xVariable,
                            yVariable: yVariable,
                            benutzertitel: autoTitel,
                            filterRegionen: Array(filterRegionen).sorted(),
                            filterSchmerzarten: Array(filterSchmerzarten).sorted(),
                            filterMedikament: filterMedikament,
                            filterZeitraum: filterZeitraum,
                            filterMinStaerke: filterMinStaerke,
                            diagrammTyp: diagrammTyp
                        )
                        onFertig(kachel)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}
