import SwiftUI
import SwiftData
import Charts

// MARK: - Section Enum

enum WohlbefindenAnalyseSektion: String, CaseIterable, Codable, Identifiable {
    case zusammenfassung = "Zusammenfassung"
    case stimmungStress  = "Stimmung & Stress"
    case schlaf          = "Schlaf"
    case wasser          = "Wasseraufnahme"
    case ernaehrung      = "Ernährung"
    case kiInsicht       = "KI-Einblick"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .zusammenfassung: return "chart.bar.fill"
        case .stimmungStress:  return "heart.fill"
        case .schlaf:          return "moon.zzz.fill"
        case .wasser:          return "drop.fill"
        case .ernaehrung:      return "fork.knife"
        case .kiInsicht:       return "sparkles"
        }
    }
}

// MARK: - Persistence

private let kWohlbefindenSektionenKey = "wohlbefindenAnalyseSektionen"

private func wohlbefindenSektionenLaden() -> [WohlbefindenAnalyseSektion] {
    guard let data = UserDefaults.standard.data(forKey: kWohlbefindenSektionenKey),
          let decoded = try? JSONDecoder().decode([WohlbefindenAnalyseSektion].self, from: data)
    else { return WohlbefindenAnalyseSektion.allCases }
    let missing = WohlbefindenAnalyseSektion.allCases.filter { !decoded.contains($0) }
    return decoded + missing
}

private func wohlbefindenSektionenSpeichern(_ s: [WohlbefindenAnalyseSektion]) {
    if let data = try? JSONEncoder().encode(s) {
        UserDefaults.standard.set(data, forKey: kWohlbefindenSektionenKey)
    }
}

// MARK: - Main View

struct WohlbefindenAnalyseView: View {
    @Query(sort: \PainEntry.datum, order: .reverse) private var alleEintraege: [PainEntry]
    @Query(sort: \WellnessEintrag.datum, order: .reverse) private var alleWellnessEintraege: [WellnessEintrag]
    @State private var sektionen: [WohlbefindenAnalyseSektion] = wohlbefindenSektionenLaden()
    @State private var zeitraum: WohlbefindenZeitraum = .woche
    @State private var zeigeAnpassen = false
    @Environment(\.dismiss) private var dismiss

    enum WohlbefindenZeitraum: String, CaseIterable {
        case woche       = "7 T"
        case monat       = "30 T"
        case dreiMonate  = "3 M"
        case sechsMonate = "6 M"
        case alle        = "Alle"

        var tage: Int? {
            switch self {
            case .woche:       return 7
            case .monat:       return 30
            case .dreiMonate:  return 90
            case .sechsMonate: return 180
            case .alle:        return nil
            }
        }
    }

    // MARK: - Filtered

    private var gefiltert: [PainEntry] {
        guard let tage = zeitraum.tage else { return alleEintraege }
        let grenze = Calendar.current.date(byAdding: .day, value: -tage, to: Date()) ?? Date()
        return alleEintraege.filter { $0.datum >= grenze }
    }

    private var gefilterteWellnessEintraege: [WellnessEintrag] {
        guard let tage = zeitraum.tage else { return alleWellnessEintraege }
        let grenze = Calendar.current.date(byAdding: .day, value: -tage, to: Date()) ?? Date()
        return alleWellnessEintraege.filter { $0.datum >= grenze }
    }

    // MARK: - Stimmung & Stress

    private struct StimmungsPunkt: Identifiable {
        let id = UUID()
        let datum: Date
        let stimmung: Double
        let stress: Double
    }

    private var stimmungsDaten: [StimmungsPunkt] {
        let kal = Calendar.current
        let tage = min(zeitraum.tage ?? 365, 365)
        let heute = kal.startOfDay(for: Date())
        return (0..<tage).reversed().compactMap { offset -> StimmungsPunkt? in
            guard let tag = kal.date(byAdding: .day, value: -offset, to: heute) else { return nil }
            let painEntries = gefiltert.filter { kal.isDate($0.datum, inSameDayAs: tag) }
            let wellnessTag = gefilterteWellnessEintraege.first(where: { kal.isDate($0.datum, inSameDayAs: tag) })

            let stimmungPain = painEntries.filter { $0.stimmung > 0 }
            let avgS: Double
            if !stimmungPain.isEmpty {
                avgS = Double(stimmungPain.map(\.stimmung).reduce(0, +)) / Double(stimmungPain.count)
            } else if let w = wellnessTag, w.stimmung > 0 {
                avgS = Double(w.stimmung)
            } else { return nil }

            let stressPain = painEntries.filter { $0.stressLevel > 0 }
            let avgSt: Double
            if !stressPain.isEmpty {
                avgSt = Double(stressPain.map(\.stressLevel).reduce(0, +)) / Double(stressPain.count)
            } else if let w = wellnessTag, w.stressLevel > 0 {
                avgSt = Double(w.stressLevel)
            } else {
                avgSt = 0
            }

            return StimmungsPunkt(datum: tag, stimmung: avgS, stress: avgSt)
        }
    }

    private var avgStimmung: Double {
        let items = stimmungsDaten.filter { $0.stimmung > 0 }
        return items.isEmpty ? 0 : items.map(\.stimmung).reduce(0, +) / Double(items.count)
    }

    private var avgStress: Double {
        let items = stimmungsDaten.filter { $0.stress > 0 }
        return items.isEmpty ? 0 : items.map(\.stress).reduce(0, +) / Double(items.count)
    }

    // MARK: - Schlaf

    private struct SchlafPunkt: Identifiable {
        let id = UUID()
        let datum: Date
        let stunden: Double
    }

    private var schlafDaten: [SchlafPunkt] {
        let kal = Calendar.current
        let tage = min(zeitraum.tage ?? 365, 365)
        let heute = kal.startOfDay(for: Date())
        return (0..<tage).reversed().compactMap { offset -> SchlafPunkt? in
            guard let tag = kal.date(byAdding: .day, value: -offset, to: heute) else { return nil }
            let painEntries = gefiltert.filter { kal.isDate($0.datum, inSameDayAs: tag) && $0.schlafStunden > 0 }
            if !painEntries.isEmpty {
                let avg = painEntries.map(\.schlafStunden).reduce(0, +) / Double(painEntries.count)
                return SchlafPunkt(datum: tag, stunden: avg)
            }
            if let w = gefilterteWellnessEintraege.first(where: { kal.isDate($0.datum, inSameDayAs: tag) }),
               w.schlafStunden > 0 {
                return SchlafPunkt(datum: tag, stunden: w.schlafStunden)
            }
            return nil
        }
    }

    private var avgSchlaf: Double {
        return schlafDaten.isEmpty ? 0 : schlafDaten.map(\.stunden).reduce(0, +) / Double(schlafDaten.count)
    }

    // MARK: - Wasser (UserDefaults)

    private static func datumString(offset: Int = 0) -> String {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        return df.string(from: Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date())
    }

    private var wasserZielMl: Int {
        let v = UserDefaults.standard.integer(forKey: "wasserZielMl")
        return v > 0 ? v : 2000
    }

    private struct WasserPunkt: Identifiable {
        let id = UUID()
        let datum: Date
        let ml: Int
    }

    private var wasserDaten: [WasserPunkt] {
        let kal = Calendar.current
        let tage = min(zeitraum.tage ?? 90, 90)
        return (0..<tage).reversed().compactMap { offset -> WasserPunkt? in
            guard let datum = kal.date(byAdding: .day, value: -offset, to: kal.startOfDay(for: Date())) else { return nil }
            if let w = gefilterteWellnessEintraege.first(where: { kal.isDate($0.datum, inSameDayAs: datum) }),
               w.wasserMl > 0 {
                return WasserPunkt(datum: datum, ml: w.wasserMl)
            }
            let key = "wasserMl_\(Self.datumString(offset: -offset))"
            let ml = UserDefaults.standard.integer(forKey: key)
            guard ml > 0 else { return nil }
            return WasserPunkt(datum: datum, ml: ml)
        }
    }

    private var avgWasserMl: Double {
        guard !wasserDaten.isEmpty else { return 0 }
        return Double(wasserDaten.map(\.ml).reduce(0, +)) / Double(wasserDaten.count)
    }

    private var wasserZielErreichtProzent: Double {
        guard !wasserDaten.isEmpty else { return 0 }
        let erreicht = wasserDaten.filter { $0.ml >= wasserZielMl }.count
        return Double(erreicht) / Double(wasserDaten.count)
    }

    // MARK: - Ernährung (UserDefaults)

    private struct ErnaehrungsPunkt: Identifiable {
        let id = UUID()
        let datum: Date
        let koffein: Int
        let alkohol: Int
    }

    private var ernaehrungsDaten: [ErnaehrungsPunkt] {
        let kal = Calendar.current
        let tage = min(zeitraum.tage ?? 90, 90)
        return (0..<tage).reversed().compactMap { offset -> ErnaehrungsPunkt? in
            guard let datum = kal.date(byAdding: .day, value: -offset, to: kal.startOfDay(for: Date())) else { return nil }
            if let w = gefilterteWellnessEintraege.first(where: { kal.isDate($0.datum, inSameDayAs: datum) }),
               w.koffeinTassen > 0 || w.alkoholGlaeser > 0 {
                return ErnaehrungsPunkt(datum: datum, koffein: w.koffeinTassen, alkohol: w.alkoholGlaeser)
            }
            let ds = Self.datumString(offset: -offset)
            let koffein = UserDefaults.standard.integer(forKey: "koffeinTassen_\(ds)")
            let alkohol = UserDefaults.standard.integer(forKey: "alkoholGlaeser_\(ds)")
            guard koffein > 0 || alkohol > 0 else { return nil }
            return ErnaehrungsPunkt(datum: datum, koffein: koffein, alkohol: alkohol)
        }
    }

    private var avgKoffein: Double {
        guard !ernaehrungsDaten.isEmpty else { return 0 }
        return Double(ernaehrungsDaten.map(\.koffein).reduce(0, +)) / Double(ernaehrungsDaten.count)
    }

    private var avgAlkohol: Double {
        guard !ernaehrungsDaten.isEmpty else { return 0 }
        return Double(ernaehrungsDaten.map(\.alkohol).reduce(0, +)) / Double(ernaehrungsDaten.count)
    }

    // MARK: - KI Prompt

    private var kiPrompt: String {
        var parts = ["Wohlbefinden-Analyse (Zeitraum: \(zeitraum.rawValue), \(gefiltert.count) Einträge)"]
        if avgStimmung > 0 { parts.append(String(format: "Ø Stimmung: %.1f/5", avgStimmung)) }
        if avgStress > 0   { parts.append(String(format: "Ø Stresslevel: %.1f/5", avgStress)) }
        if avgSchlaf > 0   { parts.append(String(format: "Ø Schlaf: %.1fh/Nacht", avgSchlaf)) }
        if avgWasserMl > 0 {
            parts.append(String(format: "Ø Wasseraufnahme: %.0f ml/Tag (Ziel: %d ml)", avgWasserMl, wasserZielMl))
            parts.append(String(format: "Wasserziel erreicht: %.0f%% der Tage", wasserZielErreichtProzent * 100))
        }
        if avgKoffein > 0  { parts.append(String(format: "Ø Koffein: %.1f Tassen/Tag", avgKoffein)) }
        if avgAlkohol > 0  { parts.append(String(format: "Ø Alkohol: %.1f Gläser/Tag", avgAlkohol)) }
        return parts.joined(separator: "\n")
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    Picker("Zeitraum", selection: $zeitraum) {
                        ForEach(WohlbefindenZeitraum.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 16)

                    VStack(spacing: 16) {
                        ForEach(sektionen) { sektion in
                            sektionView(sektion)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Wohlbefinden-Analyse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { zeigeAnpassen = true } label: {
                        Label("Reihenfolge", systemImage: "slider.horizontal.3")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .sheet(isPresented: $zeigeAnpassen) {
                WohlbefindenAnalyseAnpassenView(sektionen: $sektionen)
            }
            .onChange(of: sektionen) { _, new in wohlbefindenSektionenSpeichern(new) }
        }
    }

    // MARK: - Section Dispatcher

    @ViewBuilder
    private func sektionView(_ sektion: WohlbefindenAnalyseSektion) -> some View {
        switch sektion {
        case .zusammenfassung: zusammenfassungKarte
        case .stimmungStress:  stimmungStressKarte
        case .schlaf:          schlafKarte
        case .wasser:          wasserKarte
        case .ernaehrung:      if !ernaehrungsDaten.isEmpty { ernaehrungKarte }
        case .kiInsicht:       KIAnalyseKarte(prompt: kiPrompt, modulTint: .teal).id(kiPrompt)
        }
    }

    // MARK: - Zusammenfassung

    private var zusammenfassungKarte: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Zusammenfassung", systemImage: "chart.bar.fill")
                .font(.headline).foregroundStyle(.teal)
            Divider()
            HStack(spacing: 0) {
                statPill(
                    avgStimmung > 0 ? String(format: "%.1f", avgStimmung) : "–",
                    label: "Stimmung\n(Ø/5)",
                    farbe: avgStimmung > 0 ? stimmungFarbe(avgStimmung) : .secondary
                )
                Divider().frame(height: 40)
                statPill(
                    avgSchlaf > 0 ? String(format: "%.1fh", avgSchlaf) : "–",
                    label: "Schlaf\n(Ø Std.)",
                    farbe: avgSchlaf >= 7 ? .green : avgSchlaf >= 6 ? .orange : avgSchlaf > 0 ? .red : .secondary
                )
                Divider().frame(height: 40)
                statPill(
                    avgWasserMl > 0 ? String(format: "%.0f%%", wasserZielErreichtProzent * 100) : "–",
                    label: "Wasser\n(Ziel erreicht)",
                    farbe: wasserZielErreichtProzent >= 0.7 ? .teal : wasserZielErreichtProzent > 0 ? .orange : .secondary
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    private func statPill(_ wert: String, label: String, farbe: Color) -> some View {
        VStack(spacing: 4) {
            Text(wert).font(.title2.bold()).foregroundStyle(farbe)
            Text(label).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func stimmungFarbe(_ wert: Double) -> Color {
        switch wert {
        case ..<2: return .red
        case ..<3: return .orange
        case ..<4: return .yellow
        case ..<5: return .green
        default:   return .teal
        }
    }

    // MARK: - Stimmung & Stress

    private var stimmungStressKarte: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Stimmung & Stress", systemImage: "heart.fill")
                .font(.headline).foregroundStyle(.pink)
            Divider()
            if stimmungsDaten.isEmpty {
                Text("Noch keine Daten im ausgewählten Zeitraum.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                Chart {
                    ForEach(stimmungsDaten) { punkt in
                        LineMark(
                            x: .value("Tag", punkt.datum, unit: .day),
                            y: .value("Wert", punkt.stimmung)
                        )
                        .foregroundStyle(by: .value("Typ", "Stimmung"))
                        .interpolationMethod(.catmullRom)
                        .symbol(.circle)

                        LineMark(
                            x: .value("Tag", punkt.datum, unit: .day),
                            y: .value("Wert", punkt.stress)
                        )
                        .foregroundStyle(by: .value("Typ", "Stress"))
                        .interpolationMethod(.catmullRom)
                        .symbol(.square)
                    }
                }
                .chartForegroundStyleScale(["Stimmung": Color.red, "Stress": Color.orange])
                .chartYScale(domain: 1...5)
                .chartXAxis {
                    AxisMarks(values: .stride(by: (zeitraum.tage ?? 30) <= 7 ? .day : .weekOfYear)) {
                        AxisValueLabel(format: (zeitraum.tage ?? 30) <= 7 ? .dateTime.weekday(.narrow) : .dateTime.day().month(.abbreviated))
                    }
                }
                .chartLegend(position: .bottom, alignment: .leading)
                .frame(height: 130)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    // MARK: - Schlaf

    private var schlafKarte: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Schlaf", systemImage: "moon.zzz.fill")
                    .font(.headline).foregroundStyle(.indigo)
                Spacer()
                if avgSchlaf > 0 {
                    Text(avgSchlaf >= 7 ? "Gut" : avgSchlaf >= 6 ? "Okay" : "Zu wenig")
                        .font(.caption.bold())
                        .foregroundStyle(avgSchlaf >= 7 ? .green : avgSchlaf >= 6 ? .orange : .red)
                }
            }
            Divider()
            if schlafDaten.isEmpty {
                Text("Noch keine Schlafdaten im ausgewählten Zeitraum.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text(avgSchlaf > 0 ? String(format: "%.1f", avgSchlaf) : "–")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.indigo)
                        Text("Ø Stunden").font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(width: 85)

                    Chart(schlafDaten) { punkt in
                        BarMark(
                            x: .value("Tag", punkt.datum, unit: .day),
                            y: .value("Schlaf", punkt.stunden)
                        )
                        .foregroundStyle(punkt.stunden >= 7 ? Color.indigo : Color.indigo.opacity(0.4))
                        .cornerRadius(4)
                    }
                    .chartYScale(domain: 0...10)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: (zeitraum.tage ?? 30) <= 7 ? .day : .weekOfYear)) {
                            AxisValueLabel(format: (zeitraum.tage ?? 30) <= 7 ? .dateTime.weekday(.narrow) : .dateTime.day().month(.abbreviated))
                        }
                    }
                    .frame(height: 80)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    // MARK: - Wasser

    private var wasserKarte: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Wasseraufnahme", systemImage: "drop.fill")
                .font(.headline).foregroundStyle(.teal)
            Divider()
            if wasserDaten.isEmpty {
                Text("Noch keine Wasserdaten im ausgewählten Zeitraum.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text(String(format: "%.0f", avgWasserMl))
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(.teal)
                        Text("Ø ml/Tag").font(.caption).foregroundStyle(.secondary)
                        Text("Ziel: \(wasserZielMl) ml").font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(width: 90)

                    Chart(wasserDaten) { punkt in
                        BarMark(
                            x: .value("Tag", punkt.datum, unit: .day),
                            y: .value("ml", punkt.ml)
                        )
                        .foregroundStyle(punkt.ml >= wasserZielMl ? Color.teal : Color.teal.opacity(0.4))
                        .cornerRadius(4)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: (zeitraum.tage ?? 30) <= 7 ? .day : .weekOfYear)) {
                            AxisValueLabel(format: (zeitraum.tage ?? 30) <= 7 ? .dateTime.weekday(.narrow) : .dateTime.day().month(.abbreviated))
                        }
                    }
                    .frame(height: 80)
                }
                HStack {
                    Text("Ziel erreicht an").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.0f%% der Tage", wasserZielErreichtProzent * 100))
                        .font(.caption.bold())
                        .foregroundStyle(wasserZielErreichtProzent >= 0.7 ? .teal : .orange)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    // MARK: - Ernährung

    private var ernaehrungKarte: some View {
        let braun = Color(red: 0.55, green: 0.35, blue: 0.15)
        return VStack(alignment: .leading, spacing: 12) {
            Label("Ernährung", systemImage: "fork.knife")
                .font(.headline).foregroundStyle(braun)
            Divider()
            HStack(spacing: 0) {
                statPill(
                    avgKoffein > 0 ? String(format: "%.1f", avgKoffein) : "–",
                    label: "Koffein\n(Ø Tassen)",
                    farbe: avgKoffein > 3 ? .red : avgKoffein > 0 ? braun : .secondary
                )
                Divider().frame(height: 40)
                statPill(
                    avgAlkohol > 0 ? String(format: "%.1f", avgAlkohol) : "–",
                    label: "Alkohol\n(Ø Gläser)",
                    farbe: avgAlkohol > 1 ? .red : avgAlkohol > 0 ? .purple : .secondary
                )
                Divider().frame(height: 40)
                statPill(
                    "\(ernaehrungsDaten.count)",
                    label: "Tage\nmit Daten",
                    farbe: .secondary
                )
            }

            Chart {
                ForEach(ernaehrungsDaten) { punkt in
                    BarMark(
                        x: .value("Tag", punkt.datum, unit: .day),
                        y: .value("Tassen", Double(punkt.koffein))
                    )
                    .foregroundStyle(by: .value("Typ", "Koffein"))

                    BarMark(
                        x: .value("Tag", punkt.datum, unit: .day),
                        y: .value("Gläser", Double(punkt.alkohol))
                    )
                    .foregroundStyle(by: .value("Typ", "Alkohol"))
                }
            }
            .chartForegroundStyleScale(["Koffein": braun, "Alkohol": Color.purple])
            .chartXAxis {
                AxisMarks(values: .stride(by: (zeitraum.tage ?? 30) <= 7 ? .day : .weekOfYear)) {
                    AxisValueLabel(format: (zeitraum.tage ?? 30) <= 7 ? .dateTime.weekday(.narrow) : .dateTime.day().month(.abbreviated))
                }
            }
            .chartLegend(position: .bottom, alignment: .leading)
            .frame(height: 100)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }
}

// MARK: - Anpassen

private struct WohlbefindenAnalyseAnpassenView: View {
    @Binding var sektionen: [WohlbefindenAnalyseSektion]
    @Environment(\.dismiss) private var dismiss
    @State private var editMode: EditMode = .active

    var body: some View {
        NavigationStack {
            List {
                ForEach(sektionen) { sektion in
                    HStack(spacing: 12) {
                        Image(systemName: sektion.symbol).foregroundStyle(.teal).frame(width: 24)
                        Text(sektion.rawValue).font(.subheadline)
                    }
                }
                .onMove { from, to in
                    sektionen.move(fromOffsets: from, toOffset: to)
                    wohlbefindenSektionenSpeichern(sektionen)
                }
            }
            .environment(\.editMode, $editMode)
            .navigationTitle("Reihenfolge anpassen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
