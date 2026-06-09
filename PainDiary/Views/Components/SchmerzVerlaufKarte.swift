import SwiftUI
import Charts

struct SchmerzVerlaufKarte: View {

    let eintraege: [PainEntry]

    enum ZeitBereich: String, CaseIterable {
        case woche = "W", monat = "M", dreiMonate = "3M", jahr = "J"

        var gesamtTage: Int {
            switch self { case .woche: 7; case .monat: 30; case .dreiMonate: 90; case .jahr: 365 }
        }
        var sichtbareTage: Int {
            switch self { case .woche: 7; case .monat: 30; case .dreiMonate: 30; case .jahr: 60 }
        }
        var visibleSek: Double { Double(sichtbareTage) * 86_400 }
    }

    @State private var zeitBereich: ZeitBereich = .woche
    @State private var ausgewaehlt: Date? = nil
    @State private var scrollPosition: Date? = nil

    private var schmerzEintraege: [PainEntry] {
        eintraege.filter { !$0.istHautEintrag }
    }

    private var tagesDaten: [(datum: Date, schmerz: Double, anzahl: Int)] {
        let kal = Calendar.current
        let heute = kal.startOfDay(for: .now)
        guard let start = kal.date(byAdding: .day, value: -(zeitBereich.gesamtTage - 1), to: heute)
        else { return [] }
        var result: [(Date, Double, Int)] = []
        var tag = start
        while tag <= heute {
            let te = schmerzEintraege.filter { kal.isDate($0.datum, inSameDayAs: tag) }
            let avg = te.isEmpty ? 0.0 : Double(te.map(\.schmerzstaerke).reduce(0, +)) / Double(te.count)
            result.append((tag, avg, te.count))
            tag = kal.date(byAdding: .day, value: 1, to: tag) ?? tag
        }
        return result
    }

    var body: some View {
        let daten = tagesDaten
        let hatDaten = daten.contains { $0.anzahl > 0 }

        VStack(alignment: .leading, spacing: 12) {
            header(daten: daten)

            if hatDaten {
                chartView(daten: daten)
                legendeView(daten: daten)
            } else {
                Text("Noch keine Einträge in diesem Zeitraum.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .onAppear { resetScroll() }
        .onChange(of: zeitBereich) { ausgewaehlt = nil; resetScroll() }
    }

    // MARK: - Header

    private func header(daten: [(datum: Date, schmerz: Double, anzahl: Int)]) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                if let sel = ausgewaehlt,
                   let p = daten.first(where: { Calendar.current.isDate($0.datum, inSameDayAs: sel) }) {
                    if p.anzahl > 0 {
                        Text(String(format: "%.1f", p.schmerz))
                            .font(.title2.bold())
                            .contentTransition(.numericText())
                    } else {
                        Text("Kein Eintrag")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text(p.datum.formatted(.dateTime.day().month(.wide)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Schmerzverlauf")
                        .font(.headline)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: ausgewaehlt)

            Spacer()

            Picker("Zeitraum", selection: $zeitBereich) {
                ForEach(ZeitBereich.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(width: 160)
        }
    }

    // MARK: - Chart

    @ViewBuilder
    private func chartView(daten: [(datum: Date, schmerz: Double, anzahl: Int)]) -> some View {
        Chart(daten, id: \.datum) { punkt in
            if punkt.anzahl > 0 {
                BarMark(
                    x: .value("Tag", punkt.datum, unit: .day),
                    y: .value("Schmerz", punkt.schmerz),
                    width: .ratio(zeitBereich == .jahr ? 0.85 : 0.65)
                )
                .foregroundStyle(barFarbe(datum: punkt.datum, schmerz: punkt.schmerz))
                .cornerRadius(zeitBereich == .jahr ? 2 : 4)
            }

            if let sel = ausgewaehlt,
               Calendar.current.isDate(punkt.datum, inSameDayAs: sel),
               punkt.anzahl > 0 {
                RuleMark(x: .value("Tag", punkt.datum, unit: .day))
                    .foregroundStyle(Color.secondary.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(
                        position: .top, spacing: 4,
                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                    ) {
                        callout(fuer: punkt)
                    }
            }
        }
        .chartYScale(domain: 0...10)
        .chartYAxis {
            AxisMarks(values: [0, 5, 10]) {
                AxisGridLine().foregroundStyle(Color.secondary.opacity(0.15))
                AxisValueLabel()
            }
        }
        .chartXAxis {
            if zeitBereich == .woche {
                AxisMarks(values: .stride(by: .day)) {
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.1))
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            } else if zeitBereich == .monat {
                AxisMarks(values: .stride(by: .weekOfYear)) {
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.1))
                    AxisValueLabel(format: .dateTime.day())
                }
            } else {
                AxisMarks(values: .stride(by: .month)) {
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.1))
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
        }
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: zeitBereich.visibleSek)
        .chartScrollPosition(x: $scrollPosition)
        .chartXSelection(value: $ausgewaehlt)
        .frame(height: 180)
    }

    // MARK: - Legende

    private func legendeView(daten: [(datum: Date, schmerz: Double, anzahl: Int)]) -> some View {
        let aktiv = daten.filter { $0.anzahl > 0 }
        return HStack(spacing: 12) {
            if !aktiv.isEmpty {
                let avg = aktiv.map(\.schmerz).reduce(0, +) / Double(aktiv.count)
                Label(String(format: "Ø %.1f/10", avg), systemImage: "minus")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 6) {
                legendePunkt(label: "≤3",  farbe: .green)
                legendePunkt(label: "4–6", farbe: .yellow)
                legendePunkt(label: "7–8", farbe: .orange)
                legendePunkt(label: "≥9",  farbe: .red)
            }
        }
    }

    private func legendePunkt(label: String, farbe: Color) -> some View {
        HStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 2).fill(farbe).frame(width: 8, height: 8)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: - Callout

    private func callout(fuer punkt: (datum: Date, schmerz: Double, anzahl: Int)) -> some View {
        VStack(spacing: 1) {
            Text(String(format: "%.1f", punkt.schmerz))
                .font(.caption.bold())
            Text(punkt.datum.formatted(.dateTime.day().month(.abbreviated)))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
    }

    // MARK: - Helpers

    private func barFarbe(datum: Date, schmerz: Double) -> Color {
        let base = schmerzFarbe(schmerz)
        guard let sel = ausgewaehlt else { return base }
        return Calendar.current.isDate(datum, inSameDayAs: sel) ? base : base.opacity(0.3)
    }

    private func schmerzFarbe(_ v: Double) -> Color {
        v < 3 ? .green : v < 6 ? .yellow : v < 8 ? .orange : .red
    }

    private func resetScroll() {
        scrollPosition = Calendar.current.date(
            byAdding: .day,
            value: -(zeitBereich.sichtbareTage - 1),
            to: .now
        )
    }
}
