import SwiftUI
import SwiftData
import Charts

struct KorrelationsView: View {
    @Query(sort: \PainEntry.datum, order: .reverse) private var eintraege: [PainEntry]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if eintraege.count < 5 {
                    ContentUnavailableView(
                        "Zu wenig Daten",
                        systemImage: "chart.xyaxis.line",
                        description: Text("Erfasse mindestens 5 Einträge um Korrelationen zu sehen.")
                    )
                } else {
                    wochentagChart
                    schlafSchmerzChart
                    stressSchmerzChart
                    wetterSchmerzChart
                }
            }
            .padding()
        }
        .navigationTitle("Korrelationen")
    }

    // MARK: - Wochentag

    private var wochentagDaten: [(tag: String, schmerz: Double)] {
        let wochentage = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
        let kal = Calendar.current
        return (2...8).compactMap { wochentag in
            let treffer = eintraege.filter {
                kal.component(.weekday, from: $0.datum) == (wochentag > 8 ? wochentag - 7 : wochentag)
            }
            guard !treffer.isEmpty else { return nil }
            let avg = Double(treffer.map(\.schmerzstaerke).reduce(0, +)) / Double(treffer.count)
            let idx = wochentag == 8 ? 6 : wochentag - 2
            guard idx >= 0 && idx < 7 else { return nil }
            return (tag: wochentage[idx], schmerz: avg)
        }
    }

    private var wochentagChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Schmerz nach Wochentag")
                .font(.headline)
            Text("Ø Schmerzstärke pro Wochentag")
                .font(.caption).foregroundStyle(.secondary)

            if wochentagDaten.isEmpty {
                Text("Nicht genug Daten für diese Analyse.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Chart(wochentagDaten, id: \.tag) { punkt in
                    BarMark(
                        x: .value("Tag", punkt.tag),
                        y: .value("Schmerz", punkt.schmerz)
                    )
                    .foregroundStyle(SchmerzBadge.farbe(fuer: Int(punkt.schmerz)).gradient)
                    .cornerRadius(6)
                }
                .chartYScale(domain: 0...10)
                .chartYAxis {
                    AxisMarks(values: [0, 2, 4, 6, 8, 10])
                }
                .frame(height: 180)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Schlaf ↔ Schmerz

    private var schlafDaten: [(schlaf: Double, schmerz: Double)] {
        eintraege
            .filter { $0.schlafStunden > 0 }
            .map { (schlaf: $0.schlafStunden, schmerz: Double($0.schmerzstaerke)) }
    }

    private var schlafSchmerzChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Schlaf ↔ Schmerz")
                .font(.headline)
            Text("Weniger Schlaf = mehr Schmerz?")
                .font(.caption).foregroundStyle(.secondary)

            if schlafDaten.count < 3 {
                Text("Nicht genug Daten. Aktiviere HealthKit oder trage Schlafstunden manuell ein.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Chart(schlafDaten, id: \.schlaf) { punkt in
                    PointMark(
                        x: .value("Schlaf (Std.)", punkt.schlaf),
                        y: .value("Schmerz", punkt.schmerz)
                    )
                    .foregroundStyle(SchmerzBadge.farbe(fuer: Int(punkt.schmerz)).opacity(0.8))
                    .symbolSize(60)
                }
                .chartXScale(domain: 0...12)
                .chartYScale(domain: 0...10)
                .chartXAxis {
                    AxisMarks(values: [0, 2, 4, 6, 8, 10, 12]) { value in
                        AxisValueLabel {
                            if let d = value.as(Double.self) {
                                Text("\(Int(d))h")
                            }
                        }
                    }
                }
                .frame(height: 180)

                let korr = korrelation(schlafDaten.map(\.schlaf), schlafDaten.map(\.schmerz))
                HStack {
                    Image(systemName: korrelationsSymbol(korr))
                        .foregroundStyle(korrelationsFarbe(korr))
                    Text(korrelationsText(korr))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Stress ↔ Schmerz

    private var stressDaten: [(level: String, schmerz: Double, anzahl: Int)] {
        let labels = ["", "Entspannt", "Leicht", "Mässig", "Hoch", "Extrem"]
        return (1...5).compactMap { level in
            let treffer = eintraege.filter { ($0.stressLevel ?? 0) == level }
            guard !treffer.isEmpty else { return nil }
            let avg = Double(treffer.map(\.schmerzstaerke).reduce(0, +)) / Double(treffer.count)
            return (level: labels[level], schmerz: avg, anzahl: treffer.count)
        }
    }

    private var stressSchmerzChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Stress ↔ Schmerz")
                .font(.headline)
            Text("Ø Schmerzstärke je Stresslevel")
                .font(.caption).foregroundStyle(.secondary)

            if stressDaten.count < 2 {
                Text("Noch zu wenig Daten. Trage bei neuen Einträgen den Stresslevel ein.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Chart(stressDaten, id: \.level) { punkt in
                    BarMark(
                        x: .value("Stress", punkt.level),
                        y: .value("Schmerz", punkt.schmerz)
                    )
                    .foregroundStyle(stressFarbe(punkt.level).gradient)
                    .cornerRadius(6)
                    .annotation(position: .top) {
                        Text(String(format: "%.1f", punkt.schmerz))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartYScale(domain: 0...10)
                .chartYAxis { AxisMarks(values: [0, 2, 4, 6, 8, 10]) }
                .frame(height: 180)

                let korr = korrelation(
                    eintraege.filter { ($0.stressLevel ?? 0) > 0 }.map { Double($0.stressLevel ?? 0) },
                    eintraege.filter { ($0.stressLevel ?? 0) > 0 }.map { Double($0.schmerzstaerke) }
                )
                HStack {
                    Image(systemName: korrelationsSymbol(korr))
                        .foregroundStyle(korrelationsFarbe(korr))
                    Text(stressKorrelationsText(korr))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func stressFarbe(_ label: String) -> Color {
        switch label {
        case "Entspannt": return .green
        case "Leicht":    return .mint
        case "Mässig":    return .yellow
        case "Hoch":      return .orange
        case "Extrem":    return .red
        default:          return .secondary
        }
    }

    private func stressKorrelationsText(_ r: Double) -> String {
        switch abs(r) {
        case 0.7...: return r > 0 ? "Starker Zusammenhang: hoher Stress → mehr Schmerz" : "Starke negative Korrelation"
        case 0.4...: return r > 0 ? "Mittlerer Zusammenhang: Stress beeinflusst Schmerz" : "Mittlere negative Korrelation"
        case 0.2...: return "Schwacher Zusammenhang erkennbar"
        default:     return "Kein klarer Zusammenhang zwischen Stress und Schmerz"
        }
    }

    // MARK: - Wetter ↔ Schmerz

    private var wetterDaten: [(wetter: String, schmerz: Double)] {
        let mitWetter = eintraege.filter { $0.wetterCode != nil }
        guard !mitWetter.isEmpty else { return [] }

        let gruppen = Dictionary(grouping: mitWetter) { eintrag -> String in
            guard let code = eintrag.wetterCode else { return "Unbekannt" }
            return WetterSnapshot.beschreibungFuerCode(code)
        }
        return gruppen.map { key, werte in
            let avg = Double(werte.map(\.schmerzstaerke).reduce(0, +)) / Double(werte.count)
            return (wetter: key, schmerz: avg)
        }
        .sorted { $0.schmerz > $1.schmerz }
    }

    private var wetterSchmerzChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Wetter ↔ Schmerz")
                .font(.headline)
            Text("Ø Schmerzstärke je Wetterlage")
                .font(.caption).foregroundStyle(.secondary)

            if wetterDaten.isEmpty {
                Text("Noch keine Wetterdaten. Erlaube Standortzugriff beim Erfassen.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Chart(wetterDaten, id: \.wetter) { punkt in
                    BarMark(
                        x: .value("Schmerz", punkt.schmerz),
                        y: .value("Wetter", punkt.wetter)
                    )
                    .foregroundStyle(SchmerzBadge.farbe(fuer: Int(punkt.schmerz)).gradient)
                    .cornerRadius(6)
                }
                .chartXScale(domain: 0...10)
                .frame(height: CGFloat(wetterDaten.count * 44 + 20))
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Pearson Korrelation

    private func korrelation(_ x: [Double], _ y: [Double]) -> Double {
        guard x.count == y.count, x.count > 1 else { return 0 }
        let n = Double(x.count)
        let xMean = x.reduce(0, +) / n
        let yMean = y.reduce(0, +) / n
        let zaehler = zip(x, y).map { ($0 - xMean) * ($1 - yMean) }.reduce(0, +)
        let nennerX = sqrt(x.map { pow($0 - xMean, 2) }.reduce(0, +))
        let nennerY = sqrt(y.map { pow($0 - yMean, 2) }.reduce(0, +))
        guard nennerX * nennerY != 0 else { return 0 }
        return zaehler / (nennerX * nennerY)
    }

    private func korrelationsText(_ r: Double) -> String {
        switch abs(r) {
        case 0.7...:  return r < 0 ? "Starke negative Korrelation: mehr Schlaf = weniger Schmerz" : "Starke positive Korrelation"
        case 0.4...:  return r < 0 ? "Mittlere negative Korrelation" : "Mittlere positive Korrelation"
        case 0.2...:  return "Schwache Korrelation"
        default:      return "Kein klarer Zusammenhang erkennbar"
        }
    }

    private func korrelationsSymbol(_ r: Double) -> String {
        switch abs(r) {
        case 0.4...: return r < 0 ? "arrow.down.right" : "arrow.up.right"
        default:     return "minus"
        }
    }

    private func korrelationsFarbe(_ r: Double) -> Color {
        abs(r) > 0.4 ? (r < 0 ? .green : .red) : .secondary
    }
}
