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
    @State private var scrollPosition: Date = .now
    @State private var zeigeTagesDetail = false

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
        let aktivDaten = daten.filter { $0.anzahl > 0 }

        VStack(alignment: .leading, spacing: 12) {
            header(aktivDaten: aktivDaten)

            if aktivDaten.isEmpty {
                Text("Noch keine Einträge in diesem Zeitraum.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                chartView(aktivDaten: aktivDaten)
                legendeView(aktivDaten: aktivDaten)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
        .onAppear { resetScroll() }
        .onChange(of: zeitBereich) { ausgewaehlt = nil; resetScroll() }
        .sheet(isPresented: $zeigeTagesDetail) {
            if let sel = ausgewaehlt {
                TagesDetailSheet(datum: sel, eintraege: eintraege)
            }
        }
    }

    // MARK: - Header

    private func header(aktivDaten: [(datum: Date, schmerz: Double, anzahl: Int)]) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                if let sel = ausgewaehlt,
                   let p = aktivDaten.first(where: { Calendar.current.isDate($0.datum, inSameDayAs: sel) }) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(String(format: "%.1f", p.schmerz))
                            .font(.title2.bold())
                            .foregroundStyle(schmerzFarbe(p.schmerz))
                            .contentTransition(.numericText())
                        Text("/ 10").font(.caption).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 8) {
                        Text(p.datum.formatted(.dateTime.day().month(.wide)))
                            .font(.caption).foregroundStyle(.secondary)
                        Button {
                            zeigeTagesDetail = true
                        } label: {
                            Text("Details")
                                .font(.caption.bold())
                                .foregroundStyle(Color.accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    HStack(alignment: .top, spacing: 6) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Schmerzverlauf").font(.headline)
                            if !aktivDaten.isEmpty {
                                let avg = aktivDaten.map(\.schmerz).reduce(0, +) / Double(aktivDaten.count)
                                Text(String(format: "Ø %.1f / 10", avg))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        InfoButton(
                            titel: "Schmerzverlauf",
                            text: "Zeigt den Ø Schmerzwert pro Tag. Tage ohne Eintrag werden ausgelassen – die Linie verbindet nur Tage mit tatsächlichen Daten.\n\nBedienung: Tippe oder ziehe über den Chart um einzelne Tage auszuwählen. Wechsle oben rechts zwischen Woche, Monat, 3 Monaten und Jahr.\n\nFarbe der Punkte: grün ≤3, gelb 4–6, orange 7–8, rot ≥9."
                        )
                        .padding(.top, 2)
                    }
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
    private func chartView(aktivDaten: [(datum: Date, schmerz: Double, anzahl: Int)]) -> some View {
        let selectedPunkt: (datum: Date, schmerz: Double, anzahl: Int)? = ausgewaehlt.flatMap { sel in
            aktivDaten.first { Calendar.current.isDate($0.datum, inSameDayAs: sel) }
        }

        Chart {
            ForEach(aktivDaten, id: \.datum) { punkt in
                AreaMark(
                    x: .value("Tag", punkt.datum, unit: .day),
                    yStart: .value("Basis", 0),
                    yEnd: .value("Schmerz", punkt.schmerz)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.indigo.opacity(0.22), Color.indigo.opacity(0.01)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .interpolationMethod(.monotone)
            }

            ForEach(aktivDaten, id: \.datum) { punkt in
                LineMark(
                    x: .value("Tag", punkt.datum, unit: .day),
                    y: .value("Schmerz", punkt.schmerz)
                )
                .foregroundStyle(Color.indigo)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.monotone)
            }

            if let p = selectedPunkt {
                RuleMark(x: .value("Tag", p.datum, unit: .day))
                    .foregroundStyle(Color.secondary.opacity(0.25))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(
                        position: .top, spacing: 6,
                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                    ) {
                        callout(fuer: p)
                    }

                PointMark(
                    x: .value("Tag", p.datum, unit: .day),
                    y: .value("Schmerz", p.schmerz)
                )
                .foregroundStyle(schmerzFarbe(p.schmerz))
                .symbolSize(110)
            }
        }
        .chartLegend(.hidden)
        .chartYScale(domain: 0...10)
        .chartYAxis {
            AxisMarks(values: [0, 5, 10]) {
                AxisGridLine().foregroundStyle(Color.secondary.opacity(0.12))
                AxisValueLabel().foregroundStyle(Color.secondary)
            }
        }
        .chartXAxis {
            if zeitBereich == .woche {
                AxisMarks(values: .stride(by: .day)) {
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.08))
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            } else if zeitBereich == .monat {
                AxisMarks(values: .stride(by: .weekOfYear)) {
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.08))
                    AxisValueLabel(format: .dateTime.day())
                }
            } else {
                AxisMarks(values: .stride(by: .month)) {
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.08))
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
        }
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: zeitBereich.visibleSek)
        .chartScrollPosition(x: $scrollPosition)
        .chartOverlay { proxy in
            GeometryReader { _ in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { val in
                                guard let date: Date = proxy.value(atX: val.location.x) else { return }
                                let nearest = aktivDaten.min {
                                    abs($0.datum.timeIntervalSince(date)) < abs($1.datum.timeIntervalSince(date))
                                }
                                ausgewaehlt = nearest?.datum
                            }
                    )
            }
        }
        .frame(height: 200)
    }

    // MARK: - Legende

    private func legendeView(aktivDaten: [(datum: Date, schmerz: Double, anzahl: Int)]) -> some View {
        let avg = aktivDaten.map(\.schmerz).reduce(0, +) / Double(aktivDaten.count)
        return HStack(spacing: 12) {
            Label(String(format: "Ø %.1f / 10", avg), systemImage: "waveform.path.ecg")
                .font(.caption2).foregroundStyle(.secondary)
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
        HStack(spacing: 3) {
            Circle().fill(farbe).frame(width: 7, height: 7)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: - Callout

    private func callout(fuer punkt: (datum: Date, schmerz: Double, anzahl: Int)) -> some View {
        VStack(spacing: 2) {
            Text(String(format: "%.1f", punkt.schmerz))
                .font(.caption.bold())
                .foregroundStyle(schmerzFarbe(punkt.schmerz))
            Text(punkt.datum.formatted(.dateTime.day().month(.abbreviated)))
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.10), radius: 6, x: 0, y: 2)
    }

    // MARK: - Helpers

    private func schmerzFarbe(_ v: Double) -> Color {
        v <= 3 ? .green : v <= 6 ? .yellow : v <= 8 ? .orange : .red
    }

    private func resetScroll() {
        scrollPosition = Calendar.current.date(
            byAdding: .day,
            value: -(zeitBereich.sichtbareTage - 1),
            to: .now
        ) ?? .now
    }
}
