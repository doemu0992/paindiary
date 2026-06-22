import SwiftUI
import SwiftData
import Charts

enum SchlafAnalyseSektion: String, CaseIterable, Codable, Identifiable {
    case korrelation = "Schmerz-Schlaf-Korrelation"
    case qualitaetTrend = "Qualitätstrend"
    case phasenVerteilung = "Schlafphasen"
    case kiInsicht = "KI-Einblick"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .korrelation: return "chart.dots.scatter"
        case .qualitaetTrend: return "chart.line.uptrend.xyaxis"
        case .phasenVerteilung: return "moon.stars.fill"
        case .kiInsicht: return "sparkles"
        }
    }
}

private let kSektionenKey = "schlafAnalyseSektionen"

private func sektionenLaden() -> [SchlafAnalyseSektion] {
    guard let data = UserDefaults.standard.data(forKey: kSektionenKey),
          let decoded = try? JSONDecoder().decode([SchlafAnalyseSektion].self, from: data)
    else { return SchlafAnalyseSektion.allCases }
    return decoded
}

private func sektionenSpeichern(_ s: [SchlafAnalyseSektion]) {
    if let data = try? JSONEncoder().encode(s) {
        UserDefaults.standard.set(data, forKey: kSektionenKey)
    }
}

struct SchlafAnalyseView: View {
    let nächte: [SleepNightSummary]
    @Query(sort: \PainEntry.datum, order: .reverse) private var allePainEntries: [PainEntry]
    @Environment(\.dismiss) private var dismiss
    @State private var sektionen: [SchlafAnalyseSektion] = sektionenLaden()
    @State private var zeigeAnpassen = false

    enum Zeitraum: String, CaseIterable {
        case woche = "7 T"
        case monat = "30 T"
        case dreiMonate = "3 M"
        case alle = "Alle"
        var tage: Int? {
            switch self {
            case .woche: return 7
            case .monat: return 30
            case .dreiMonate: return 90
            case .alle: return nil
            }
        }
    }
    @State private var zeitraum: Zeitraum = .woche

    private var gefiltert: [SleepNightSummary] {
        guard let tage = zeitraum.tage else { return nächte }
        let cutoff = Calendar.current.date(byAdding: .day, value: -tage, to: Date()) ?? Date()
        return nächte.filter { $0.date >= cutoff }
    }

    private var gefiltertePainEntries: [PainEntry] {
        guard let tage = zeitraum.tage else { return Array(allePainEntries) }
        let cutoff = Calendar.current.date(byAdding: .day, value: -tage, to: Date()) ?? Date()
        return allePainEntries.filter { $0.datum >= cutoff && !$0.istHautEintrag }
    }

    // Correlate: for each sleep night, find same-day pain entries
    private var korrelationsPunkte: [(qualitaet: Double, schmerzAvg: Double, datum: Date)] {
        let cal = Calendar.current
        return gefiltert.compactMap { nacht in
            let schmerzen = gefiltertePainEntries.filter { cal.isDate($0.datum, inSameDayAs: nacht.date) }
            guard !schmerzen.isEmpty else { return nil }
            let avg = Double(schmerzen.map(\.schmerzstaerke).reduce(0, +)) / Double(schmerzen.count)
            return (qualitaet: nacht.qualitaet, schmerzAvg: avg, datum: nacht.date)
        }
    }

    private var kiPrompt: String {
        let punkte = korrelationsPunkte.prefix(30)
        let avgQual = gefiltert.map(\.qualitaet).reduce(0, +) / max(Double(gefiltert.count), 1)
        let avgDauer = gefiltert.map(\.dauerStunden).reduce(0, +) / max(Double(gefiltert.count), 1)
        return """
        Schlaf-Analyse (\(zeitraum.rawValue)):
        - Analysierte Nächte: \(gefiltert.count)
        - Ø Schlafqualität: \(String(format: "%.0f", avgQual))/100
        - Ø Schlafdauer: \(String(format: "%.1f h", avgDauer))
        - Korrelationsdatenpunkte: \(punkte.count)
        - Korrelationsbeispiele: \(punkte.prefix(5).map { "Qual:\(Int($0.qualitaet)) Schmerz:\(String(format: "%.1f", $0.schmerzAvg))" }.joined(separator: ", "))
        Identifiziere Muster zwischen Schlafqualität und Schmerzintensität. Gib 3–4 kurze Einblicke auf Deutsch.
        """
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("Zeitraum", selection: $zeitraum) {
                        ForEach(Zeitraum.allCases, id: \.self) { z in
                            Text(z.rawValue).tag(z)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    ForEach(sektionen) { sektion in
                        sektionView(sektion)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Schlaf-Analyse")
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
            .onChange(of: sektionen) { _, new in sektionenSpeichern(new) }
            .sheet(isPresented: $zeigeAnpassen) {
                SchlafAnalyseAnpassenView(sektionen: $sektionen)
            }
        }
    }

    @ViewBuilder
    private func sektionView(_ sektion: SchlafAnalyseSektion) -> some View {
        switch sektion {
        case .korrelation:      korrelationsKarte
        case .qualitaetTrend:   qualitaetTrendKarte
        case .phasenVerteilung: phasenKarte
        case .kiInsicht:
            if #available(iOS 26, *) {
                KIAnalyseKarte(prompt: kiPrompt, modulTint: .indigo)
                    .id(kiPrompt)
            }
        }
    }

    // MARK: - Schmerz-Schlaf-Korrelation

    private var korrelationsKarte: some View {
        karte(titel: "Schmerz-Schlaf-Korrelation", symbol: "chart.dots.scatter") {
            if korrelationsPunkte.isEmpty {
                Text("Nicht genug Daten — erfasse Schmerzeinträge an Schlafnächten.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                Chart(korrelationsPunkte, id: \.datum) { p in
                    PointMark(
                        x: .value("Schlafqualität", p.qualitaet),
                        y: .value("Schmerz", p.schmerzAvg)
                    )
                    .foregroundStyle(
                        LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing)
                    )
                    .symbolSize(80)
                }
                .chartXAxis {
                    AxisMarks(values: [0, 25, 50, 75, 100]) { v in
                        AxisValueLabel { Text("\(v.as(Int.self) ?? 0)").font(.caption2) }
                        AxisGridLine()
                    }
                }
                .chartYAxis {
                    AxisMarks(values: [0, 3, 6, 10]) { v in
                        AxisValueLabel { Text("\(v.as(Int.self) ?? 0)").font(.caption2) }
                        AxisGridLine()
                    }
                }
                .chartXScale(domain: 0...100)
                .chartYScale(domain: 0...10)
                .frame(height: 180)

                Text("X: Schlafqualität (0–100) · Y: Schmerzstärke (Ø Tageswert)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)

                let pearson = pearsonKorrelation(korrelationsPunkte)
                if let r = pearson {
                    HStack(spacing: 6) {
                        Image(systemName: r < -0.3 ? "arrow.down.right" : r > 0.3 ? "arrow.up.right" : "minus")
                        Text(String(format: "Korrelation r = %.2f — %@", r, korrelationsText(r)))
                    }
                    .font(.caption.bold())
                    .foregroundStyle(r < -0.3 ? Color.green : r > 0.3 ? Color.red : Color.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func pearsonKorrelation(_ punkte: [(qualitaet: Double, schmerzAvg: Double, datum: Date)]) -> Double? {
        let n = Double(punkte.count)
        guard n >= 3 else { return nil }
        let xs = punkte.map(\.qualitaet)
        let ys = punkte.map(\.schmerzAvg)
        let xBar = xs.reduce(0, +) / n
        let yBar = ys.reduce(0, +) / n
        let cov = zip(xs, ys).map { ($0 - xBar) * ($1 - yBar) }.reduce(0, +)
        let sdX = sqrt(xs.map { ($0 - xBar) * ($0 - xBar) }.reduce(0, +))
        let sdY = sqrt(ys.map { ($0 - yBar) * ($0 - yBar) }.reduce(0, +))
        guard sdX > 0 && sdY > 0 else { return nil }
        return cov / (sdX * sdY)
    }

    private func korrelationsText(_ r: Double) -> String {
        if r < -0.5 { return "starker negativer Zusammenhang (mehr Schlaf → weniger Schmerz)" }
        if r < -0.3 { return "moderater Zusammenhang" }
        if r > 0.3 { return "kein klarer positiver Zusammenhang" }
        return "kein eindeutiger Zusammenhang"
    }

    // MARK: - Qualitätstrend

    private var qualitaetTrendKarte: some View {
        karte(titel: "Qualitätstrend", symbol: "chart.line.uptrend.xyaxis") {
            if gefiltert.isEmpty {
                Text("Keine Daten im Zeitraum.").font(.caption).foregroundStyle(.secondary)
            } else {
                let sorted = gefiltert.sorted { $0.datum < $1.datum }
                Chart(sorted) { n in
                    LineMark(
                        x: .value("Datum", n.date),
                        y: .value("Qualität", n.qualitaet)
                    )
                    .foregroundStyle(.indigo)
                    .interpolationMethod(.catmullRom)
                    AreaMark(
                        x: .value("Datum", n.date),
                        y: .value("Qualität", n.qualitaet)
                    )
                    .foregroundStyle(LinearGradient(colors: [.indigo.opacity(0.25), .clear], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.catmullRom)
                }
                .chartXAxis { AxisMarks(values: .stride(by: .day, count: 7)) { _ in AxisGridLine() } }
                .chartYScale(domain: 0...100)
                .frame(height: 150)
            }
        }
    }

    // MARK: - Phasenverteilung

    private var phasenKarte: some View {
        karte(titel: "Schlafphasen (Durchschnitt)", symbol: "moon.stars.fill") {
            if gefiltert.isEmpty {
                Text("Keine Daten im Zeitraum.").font(.caption).foregroundStyle(.secondary)
            } else {
                let avgTief   = gefiltert.map(\.tiefPct).reduce(0, +) / Double(gefiltert.count)
                let avgREM    = gefiltert.map(\.remPct).reduce(0, +) / Double(gefiltert.count)
                let avgLeicht = gefiltert.map(\.leichtPct).reduce(0, +) / Double(gefiltert.count)
                let avgWach   = gefiltert.map(\.wachPct).reduce(0, +) / Double(gefiltert.count)

                VStack(spacing: 8) {
                    phasBalken("Tiefschlaf", pct: avgTief, farbe: .indigo)
                    phasBalken("REM", pct: avgREM, farbe: .purple)
                    phasBalken("Leichtschlaf", pct: avgLeicht, farbe: .blue)
                    phasBalken("Wach", pct: avgWach, farbe: .orange)
                }

                Text("Empfehlung: Tiefschlaf ≥ 15 %, REM ≥ 20 %")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func phasBalken(_ label: String, pct: Double, farbe: Color) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(farbe.opacity(0.12)).frame(height: 10)
                    Capsule().fill(farbe).frame(width: geo.size.width * pct, height: 10)
                }
            }
            .frame(height: 10)
            Text(String(format: "%.0f%%", pct * 100))
                .font(.caption.bold())
                .foregroundStyle(farbe)
                .frame(width: 36, alignment: .trailing)
        }
    }

    // MARK: - Karte Helper

    private func karte<Content: View>(titel: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(titel, systemImage: symbol)
                    .font(.headline)
                    .foregroundStyle(.indigo)
                Spacer()
            }
            content()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }
}

// MARK: - Anpassen

private struct SchlafAnalyseAnpassenView: View {
    @Binding var sektionen: [SchlafAnalyseSektion]
    @Environment(\.dismiss) private var dismiss
    @State private var editMode: EditMode = .active

    var body: some View {
        NavigationStack {
            List {
                ForEach(sektionen) { sektion in
                    HStack(spacing: 12) {
                        Image(systemName: sektion.symbol).foregroundStyle(.indigo).frame(width: 24)
                        Text(sektion.rawValue).font(.subheadline)
                    }
                }
                .onMove { from, to in
                    sektionen.move(fromOffsets: from, toOffset: to)
                    sektionenSpeichern(sektionen)
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
