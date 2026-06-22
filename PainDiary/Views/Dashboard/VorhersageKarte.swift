import SwiftUI
import Charts

struct VorhersageKarte: View {
    let eintraege: [PainEntry]

    private var kal: Calendar {
        var k = Calendar.current
        k.firstWeekday = 2
        return k
    }

    // Ø Schmerz pro Wochentag (Calendar.weekday: 1=So, 2=Mo, ..., 7=Sa), letzte 90 Tage, mind. 2 Punkte
    private var schnittProWochentag: [Int: Double] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        let relevant = eintraege.filter { !$0.istHautEintrag && $0.datum >= cutoff }
        var dict: [Int: (sum: Int, count: Int)] = [:]
        for e in relevant {
            let wt = Calendar.current.component(.weekday, from: e.datum)
            let cur = dict[wt] ?? (0, 0)
            dict[wt] = (cur.sum + e.schmerzstaerke, cur.count + 1)
        }
        return dict.compactMapValues { $0.count >= 2 ? Double($0.sum) / Double($0.count) : nil }
    }

    // Trend-Korrektur: letzte 7 Tage vs. davor 7 Tage (gedämpft)
    private var trendAdjust: Double {
        guard
            let vor7  = Calendar.current.date(byAdding: .day, value: -7,  to: Date()),
            let vor14 = Calendar.current.date(byAdding: .day, value: -14, to: Date())
        else { return 0 }
        let aktuell = eintraege.filter { !$0.istHautEintrag && $0.datum >= vor7 }
        let vorher  = eintraege.filter { !$0.istHautEintrag && $0.datum >= vor14 && $0.datum < vor7 }
        guard !aktuell.isEmpty, !vorher.isEmpty else { return 0 }
        let avgA = Double(aktuell.map(\.schmerzstaerke).reduce(0, +)) / Double(aktuell.count)
        let avgV = Double(vorher.map(\.schmerzstaerke).reduce(0, +)) / Double(vorher.count)
        return (avgA - avgV) * 0.25
    }

    private var baseline: Double {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let relevant = eintraege.filter { !$0.istHautEintrag && $0.datum >= cutoff }
        guard !relevant.isEmpty else { return 5 }
        return Double(relevant.map(\.schmerzstaerke).reduce(0, +)) / Double(relevant.count)
    }

    private struct Vorhersage: Identifiable {
        let id = UUID()
        let datum: Date
        let wert: Double
    }

    private var vorhersagen: [Vorhersage] {
        let morgen = kal.startOfDay(for: kal.date(byAdding: .day, value: 1, to: Date())!)
        return (0..<7).compactMap { i in
            guard let datum = kal.date(byAdding: .day, value: i, to: morgen) else { return nil }
            let wt = Calendar.current.component(.weekday, from: datum)
            let basis = schnittProWochentag[wt] ?? baseline
            let wert = max(0, min(10, basis + trendAdjust))
            return Vorhersage(datum: datum, wert: wert)
        }
    }

    private var besterTag: Vorhersage? { vorhersagen.min(by: { $0.wert < $1.wert }) }
    private var schwersterTag: Vorhersage? { vorhersagen.max(by: { $0.wert < $1.wert }) }

    private var hatGenugDaten: Bool {
        eintraege.filter { !$0.istHautEintrag }.count >= 14
    }

    private func farbe(_ w: Double) -> Color {
        if w <= 3  { return .green }
        if w <= 6  { return Color(red: 0.95, green: 0.75, blue: 0) }
        if w <= 8  { return .orange }
        return .red
    }

    var body: some View {
        KachelContainer(
            titel: "7-Tage-Vorhersage",
            symbol: "wand.and.stars",
            farbe: .purple,
            infoText: "Prognostizierter Schmerzwert für die nächsten 7 Tage – basierend auf deinen Wochentagsmustern der letzten 90 Tage und dem aktuellen Verlaufstrend. Kein medizinischer Ratschlag."
        ) {
            if hatGenugDaten {
                prognoseInhalt
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis.circle")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Mindestens 14 Einträge nötig für eine Vorhersage.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
    }

    private var prognoseInhalt: some View {
        VStack(spacing: 14) {
            Chart(vorhersagen) { tag in
                BarMark(
                    x: .value("Tag", tag.datum, unit: .day),
                    y: .value("Schmerz", tag.wert)
                )
                .foregroundStyle(farbe(tag.wert).gradient)
                .cornerRadius(4)
                .annotation(position: .top, alignment: .center) {
                    Text(String(format: "%.1f", tag.wert))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(farbe(tag.wert))
                }
            }
            .chartYScale(domain: 0...10)
            .chartYAxis {
                AxisMarks(values: [0, 5, 10]) {
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.15))
                    AxisValueLabel()
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic) {
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated).locale(Locale(identifier: "de_DE")))
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
            }
            .chartLegend(.hidden)
            .frame(height: 160)

            // Bester / Schwierigster Tag
            if let best = besterTag, let schwer = schwersterTag, best.datum != schwer.datum {
                HStack(spacing: 12) {
                    tagHinweis(
                        label: "Bester Tag",
                        datum: best.datum,
                        wert: best.wert,
                        symbol: "arrow.down.circle.fill",
                        farbe: .green
                    )
                    Divider().frame(height: 36)
                    tagHinweis(
                        label: "Schwierigster Tag",
                        datum: schwer.datum,
                        wert: schwer.wert,
                        symbol: "arrow.up.circle.fill",
                        farbe: farbe(schwer.wert)
                    )
                }
                .padding(10)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
            }

            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Wochentagsmuster der letzten 90 Tage + aktueller Trend")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func tagHinweis(label: String, datum: Date, wert: Double, symbol: String, farbe: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(farbe)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(datum.formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "de_DE"))))
                    .font(.caption.bold())
                Text(String(format: "Ø %.1f", wert))
                    .font(.caption2)
                    .foregroundStyle(farbe)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
