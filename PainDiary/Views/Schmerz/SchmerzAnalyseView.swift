import SwiftUI
import Charts
import SwiftData

// MARK: - Section Enum

enum SchmerzAnalyseSektion: String, CaseIterable, Codable, Identifiable {
    case zusammenfassung = "Zusammenfassung"
    case verlauf         = "Schmerzverlauf"
    case koerperstellen  = "Körperstellen"
    case ausloeser       = "Auslöser"
    case tageszeit       = "Tageszeit-Muster"
    case wohlbefinden    = "Wohlbefinden"
    case kiInsicht       = "KI-Einblick"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .zusammenfassung: return "chart.bar.fill"
        case .verlauf:         return "chart.line.uptrend.xyaxis"
        case .koerperstellen:  return "figure.stand"
        case .ausloeser:       return "exclamationmark.triangle.fill"
        case .tageszeit:       return "clock.fill"
        case .wohlbefinden:    return "heart.fill"
        case .kiInsicht:       return "sparkles"
        }
    }
}

// MARK: - Main View

struct SchmerzAnalyseView: View {
    @Query(sort: \PainEntry.datum, order: .reverse) private var alleEintraege: [PainEntry]
    private var eintraege: [PainEntry] { alleEintraege.filter { !$0.istHautEintrag && $0.koerperstelle != "Rheuma" } }

    @State private var sektionen: [SchmerzAnalyseSektion] = SchmerzAnalyseView.sektionenLaden()
    @State private var zeitraum: Zeitraum = .woche
    @State private var zeigeAnpassen = false
    @Environment(\.dismiss) private var dismiss

    enum Zeitraum: String, CaseIterable {
        case woche       = "7 T"
        case monat       = "30 T"
        case dreiMonate  = "3 M"
        case sechsMonate = "6 M"
        case jahr        = "1 J"
        case alle        = "Alle"

        var tage: Int? {
            switch self {
            case .woche:       return 7
            case .monat:       return 30
            case .dreiMonate:  return 90
            case .sechsMonate: return 180
            case .jahr:        return 365
            case .alle:        return nil
            }
        }
    }

    // MARK: - Filtered

    private var gefiltert: [PainEntry] {
        guard let tage = zeitraum.tage else { return eintraege }
        let grenze = Calendar.current.date(byAdding: .day, value: -tage, to: Date()) ?? Date()
        return eintraege.filter { $0.datum >= grenze }
    }

    private var avgSchmerz: Double {
        gefiltert.isEmpty ? 0 : Double(gefiltert.map(\.schmerzstaerke).reduce(0, +)) / Double(gefiltert.count)
    }

    private var maxSchmerz: Int { gefiltert.map(\.schmerzstaerke).max() ?? 0 }
    private var schube: [PainEntry] { gefiltert.filter(\.istSchub) }

    // MARK: - Verlauf (adaptive Granularität)

    private struct VerlaufPunkt: Identifiable {
        let id = UUID()
        let datum: Date
        let avgSchmerz: Double
        let schube: Int
    }

    private var chartKomponente: Calendar.Component {
        switch zeitraum {
        case .woche:              return .day
        case .monat:              return .weekOfYear
        default:                  return .month
        }
    }

    private var verlaufDaten: [VerlaufPunkt] {
        let cal = Calendar.current
        var grouped: [Date: [PainEntry]] = [:]
        for e in gefiltert {
            let comps: Set<Calendar.Component> = chartKomponente == .day
                ? [.year, .month, .day]
                : chartKomponente == .weekOfYear
                    ? [.yearForWeekOfYear, .weekOfYear]
                    : [.year, .month]
            let key = cal.date(from: cal.dateComponents(comps, from: e.datum)) ?? e.datum
            grouped[key, default: []].append(e)
        }
        return grouped.map { key, entries in
            VerlaufPunkt(
                datum: key,
                avgSchmerz: Double(entries.map(\.schmerzstaerke).reduce(0, +)) / Double(entries.count),
                schube: entries.filter(\.istSchub).count
            )
        }.sorted { $0.datum < $1.datum }
    }

    // MARK: - Körperstellen

    private struct OrtHaeufigkeit: Identifiable {
        let id: String
        let anzahl: Int
    }

    private var topOrte: [OrtHaeufigkeit] {
        var counts: [String: Int] = [:]
        for e in gefiltert where !e.koerperstelle.isEmpty {
            for ort in e.koerperstelle.components(separatedBy: ",").map({ $0.trimmingCharacters(in: .whitespaces) }) where !ort.isEmpty {
                counts[ort, default: 0] += 1
            }
        }
        return counts.map { OrtHaeufigkeit(id: $0.key, anzahl: $0.value) }
            .sorted { $0.anzahl > $1.anzahl }.prefix(8).map { $0 }
    }

    // MARK: - Auslöser

    private struct AusloeserHaeufigkeit: Identifiable {
        let id: String
        let anzahl: Int
    }

    private var topAusloeser: [AusloeserHaeufigkeit] {
        var counts: [String: Int] = [:]
        for e in gefiltert where !e.ausloeser.isEmpty {
            counts[e.ausloeser, default: 0] += 1
        }
        return counts.map { AusloeserHaeufigkeit(id: $0.key, anzahl: $0.value) }
            .sorted { $0.anzahl > $1.anzahl }.prefix(8).map { $0 }
    }

    // MARK: - Tageszeit

    private var tageszeit: [(label: String, count: Int)] {
        let bins = ["Nacht (0–6)", "Morgen (6–12)", "Mittag (12–18)", "Abend (18–24)"]
        var counts = [Int](repeating: 0, count: 4)
        let cal = Calendar.current
        for e in gefiltert {
            let h = cal.component(.hour, from: e.datum)
            switch h {
            case 0..<6:   counts[0] += 1
            case 6..<12:  counts[1] += 1
            case 12..<18: counts[2] += 1
            default:      counts[3] += 1
            }
        }
        return zip(bins, counts).map { (label: $0, count: $1) }
    }

    // MARK: - Wohlbefinden

    private var avgStress: Double {
        let m = gefiltert.filter { $0.stressLevel > 0 }
        return m.isEmpty ? 0 : Double(m.map(\.stressLevel).reduce(0, +)) / Double(m.count)
    }
    private var avgSchlaf: Double {
        let m = gefiltert.filter { $0.schlafStunden > 0 }
        return m.isEmpty ? 0 : m.map(\.schlafStunden).reduce(0, +) / Double(m.count)
    }
    private var avgStimmung: Double {
        let m = gefiltert.filter { $0.stimmung > 0 }
        return m.isEmpty ? 0 : Double(m.map(\.stimmung).reduce(0, +)) / Double(m.count)
    }

    // MARK: - KI Prompt

    private var kiPrompt: String {
        var parts: [String] = []
        parts.append("Zeitraum: \(zeitraum.rawValue), \(gefiltert.count) Einträge")
        if !gefiltert.isEmpty {
            parts.append(String(format: "Ø Schmerzstärke: %.1f/10, Maximum: %d/10", avgSchmerz, maxSchmerz))
        }
        if !schube.isEmpty { parts.append("Schübe: \(schube.count)") }
        let orteStr = topOrte.prefix(3).map(\.id).joined(separator: ", ")
        if !orteStr.isEmpty { parts.append("Hauptlokalisation: \(orteStr)") }
        let ausloeserStr = topAusloeser.prefix(3).map(\.id).joined(separator: ", ")
        if !ausloeserStr.isEmpty { parts.append("Häufigste Auslöser: \(ausloeserStr)") }
        if avgStress > 0 { parts.append(String(format: "Ø Stress: %.1f/5", avgStress)) }
        if avgSchlaf > 0 { parts.append(String(format: "Ø Schlaf: %.1f Stunden", avgSchlaf)) }
        if avgStimmung > 0 { parts.append(String(format: "Ø Stimmung: %.1f/5", avgStimmung)) }
        return "Schmerzdaten:\n" + parts.joined(separator: "\n")
    }

    // MARK: - Persistence

    private static let kSektionenKey = "schmerzAnalyseSektionen"

    static func sektionenLaden() -> [SchmerzAnalyseSektion] {
        guard let data = UserDefaults.standard.data(forKey: kSektionenKey),
              let decoded = try? JSONDecoder().decode([SchmerzAnalyseSektion].self, from: data)
        else { return SchmerzAnalyseSektion.allCases }
        let missing = SchmerzAnalyseSektion.allCases.filter { !decoded.contains($0) }
        return decoded + missing
    }

    private func sektionenSpeichern(_ s: [SchmerzAnalyseSektion]) {
        if let data = try? JSONEncoder().encode(s) {
            UserDefaults.standard.set(data, forKey: Self.kSektionenKey)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    Picker("Zeitraum", selection: $zeitraum) {
                        ForEach(Zeitraum.allCases, id: \.self) { Text($0.rawValue).tag($0) }
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
            .navigationTitle("Schmerz-Analyse")
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
                SchmerzAnalyseAnpassenView(sektionen: $sektionen)
            }
            .onChange(of: sektionen) { _, new in sektionenSpeichern(new) }
        }
    }

    // MARK: - Section Dispatcher

    @ViewBuilder
    private func sektionView(_ sektion: SchmerzAnalyseSektion) -> some View {
        switch sektion {
        case .zusammenfassung: zusammenfassungKarte
        case .verlauf:         verlaufKarte
        case .koerperstellen:  koerperstellenKarte
        case .ausloeser:       ausloeserKarte
        case .tageszeit:       tageszeitKarte
        case .wohlbefinden:    wohlbefindenKarte
        case .kiInsicht:
            KIAnalyseKarte(prompt: kiPrompt, modulTint: .red)
                .id(kiPrompt)
        }
    }

    // MARK: - Helpers

    private func karte<Content: View>(
        titel: String,
        symbol: String,
        farbe: Color,
        info: String = "",
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Label(titel, systemImage: symbol)
                    .font(.headline).foregroundStyle(farbe)
                if !info.isEmpty {
                    InfoButton(titel: titel, text: info)
                }
            }
            Divider()
            content()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    private func leerKarte(_ sektion: SchmerzAnalyseSektion) -> some View {
        karte(titel: sektion.rawValue, symbol: sektion.symbol, farbe: .secondary) {
            Text("Keine Daten für diesen Zeitraum")
                .font(.subheadline).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
        }
    }

    private func statZelle(_ wert: String, label: String, farbe: Color = .primary) -> some View {
        VStack(spacing: 4) {
            Text(wert).font(.title2.bold()).foregroundStyle(farbe)
            Text(label).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Zusammenfassung

    private var zusammenfassungKarte: some View {
        karte(titel: "Zusammenfassung", symbol: "chart.bar.fill", farbe: .red,
              info: "Überblick über den gewählten Zeitraum.") {
            if gefiltert.isEmpty {
                Text("Keine Einträge in diesem Zeitraum")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                HStack(spacing: 0) {
                    statZelle(String(format: "%.1f", avgSchmerz), label: "Ø Schmerz",
                              farbe: avgSchmerz <= 3 ? .green : avgSchmerz <= 6 ? .orange : .red)
                    Divider().frame(height: 40)
                    statZelle("\(maxSchmerz)", label: "Maximum", farbe: maxSchmerz >= 8 ? .red : .orange)
                    Divider().frame(height: 40)
                    statZelle("\(schube.count)", label: "Schübe",
                              farbe: schube.isEmpty ? .green : .red)
                }
                .padding(.bottom, 4)

                if !schube.isEmpty {
                    Divider()
                    let normalEintraege = gefiltert.filter { !$0.istSchub }
                    HStack(spacing: 0) {
                        statZelle("\(gefiltert.count)", label: "Einträge", farbe: .secondary)
                        Divider().frame(height: 40)
                        let schubAvg = Double(schube.map(\.schmerzstaerke).reduce(0, +)) / Double(schube.count)
                        statZelle(String(format: "%.1f", schubAvg), label: "Ø Schmerz\nbei Schub", farbe: .red)
                        Divider().frame(height: 40)
                        let normalAvg = normalEintraege.isEmpty ? 0.0
                            : Double(normalEintraege.map(\.schmerzstaerke).reduce(0, +)) / Double(normalEintraege.count)
                        statZelle(String(format: "%.1f", normalAvg), label: "Ø Schmerz\nnormal", farbe: .secondary)
                    }
                }
            }
        }
    }

    // MARK: - Verlauf

    private var verlaufKarte: some View {
        Group {
            if verlaufDaten.isEmpty {
                leerKarte(.verlauf)
            } else {
                karte(titel: "Schmerzverlauf", symbol: "chart.line.uptrend.xyaxis", farbe: .red) {
                    let komp = chartKomponente
                    let xFormat: Date.FormatStyle = komp == .day
                        ? .dateTime.day().month(.abbreviated)
                        : komp == .weekOfYear
                            ? .dateTime.day().month(.abbreviated)
                            : .dateTime.month(.abbreviated)
                    Chart(verlaufDaten) { punkt in
                        LineMark(
                            x: .value("Datum", punkt.datum, unit: komp),
                            y: .value("Ø Schmerz", punkt.avgSchmerz)
                        )
                        .foregroundStyle(.red)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Datum", punkt.datum, unit: komp),
                            y: .value("Ø Schmerz", punkt.avgSchmerz)
                        )
                        .foregroundStyle(.red)
                        .symbolSize(30)

                        if punkt.schube > 0 {
                            PointMark(
                                x: .value("Datum", punkt.datum, unit: komp),
                                y: .value("Ø Schmerz", punkt.avgSchmerz)
                            )
                            .foregroundStyle(.red.opacity(0.3))
                            .symbolSize(CGFloat(punkt.schube) * 120)
                        }
                    }
                    .chartYScale(domain: 0...10)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: komp)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: xFormat, centered: true)
                        }
                    }
                    .frame(height: 160)

                    Text("Punkte = Ø Schmerzstärke, Kreisgrösse = Anzahl Schübe")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Körperstellen

    private var koerperstellenKarte: some View {
        Group {
            if topOrte.isEmpty {
                leerKarte(.koerperstellen)
            } else {
                karte(titel: "Körperstellen", symbol: "figure.stand", farbe: .red) {
                    let maxAnzahl = topOrte.first?.anzahl ?? 1
                    VStack(spacing: 8) {
                        ForEach(topOrte) { ort in
                            HStack(spacing: 8) {
                                Text(ort.id)
                                    .font(.subheadline)
                                    .frame(width: 120, alignment: .leading)
                                    .lineLimit(1)
                                GeometryReader { geo in
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.red.opacity(0.7))
                                        .frame(width: geo.size.width * CGFloat(ort.anzahl) / CGFloat(maxAnzahl))
                                }
                                .frame(height: 18)
                                Text("\(ort.anzahl)×")
                                    .font(.caption.bold())
                                    .foregroundStyle(.red)
                                    .frame(width: 32, alignment: .trailing)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Auslöser

    private var ausloeserKarte: some View {
        Group {
            if topAusloeser.isEmpty {
                leerKarte(.ausloeser)
            } else {
                karte(titel: "Auslöser", symbol: "exclamationmark.triangle.fill", farbe: .red) {
                    let maxAnzahl = topAusloeser.first?.anzahl ?? 1
                    VStack(spacing: 8) {
                        ForEach(topAusloeser) { a in
                            HStack(spacing: 8) {
                                Text(a.id)
                                    .font(.subheadline)
                                    .frame(width: 120, alignment: .leading)
                                    .lineLimit(1)
                                GeometryReader { geo in
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.orange.opacity(0.7))
                                        .frame(width: geo.size.width * CGFloat(a.anzahl) / CGFloat(maxAnzahl))
                                }
                                .frame(height: 18)
                                Text("\(a.anzahl)×")
                                    .font(.caption.bold())
                                    .foregroundStyle(.orange)
                                    .frame(width: 32, alignment: .trailing)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Tageszeit

    private var tageszeitKarte: some View {
        Group {
            if gefiltert.isEmpty {
                leerKarte(.tageszeit)
            } else {
                karte(titel: "Tageszeit-Muster", symbol: "clock.fill", farbe: .red) {
                    Chart(tageszeit, id: \.label) { item in
                        BarMark(
                            x: .value("Tageszeit", item.label),
                            y: .value("Einträge", item.count)
                        )
                        .foregroundStyle(Color.red.opacity(0.75))
                        .cornerRadius(4)
                    }
                    .chartXAxis {
                        AxisMarks { val in
                            AxisValueLabel {
                                if let s = val.as(String.self) {
                                    Text(s.components(separatedBy: " ").first ?? s)
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                    .frame(height: 120)
                }
            }
        }
    }

    // MARK: - Wohlbefinden

    private var wohlbefindenKarte: some View {
        karte(titel: "Wohlbefinden", symbol: "heart.fill", farbe: .red) {
            HStack(spacing: 0) {
                statZelle(
                    avgStress > 0 ? String(format: "%.1f", avgStress) : "–",
                    label: "Ø Stress",
                    farbe: avgStress > 0 ? (avgStress <= 2 ? .green : avgStress <= 3.5 ? .orange : .red) : .secondary
                )
                Divider().frame(height: 40)
                statZelle(
                    avgSchlaf > 0 ? String(format: "%.1fh", avgSchlaf) : "–",
                    label: "Ø Schlaf",
                    farbe: avgSchlaf > 0 ? (avgSchlaf >= 7 ? .green : avgSchlaf >= 5 ? .orange : .red) : .secondary
                )
                Divider().frame(height: 40)
                statZelle(
                    avgStimmung > 0 ? String(format: "%.1f", avgStimmung) : "–",
                    label: "Ø Stimmung",
                    farbe: avgStimmung > 0 ? (avgStimmung >= 4 ? .green : avgStimmung >= 2.5 ? .orange : .red) : .secondary
                )
            }
        }
    }
}

// MARK: - Anpassen View

struct SchmerzAnalyseAnpassenView: View {
    @Binding var sektionen: [SchmerzAnalyseSektion]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach($sektionen) { $sektion in
                    Label(sektion.rawValue, systemImage: sektion.symbol)
                }
                .onMove { sektionen.move(fromOffsets: $0, toOffset: $1) }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Sektionen anpassen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
