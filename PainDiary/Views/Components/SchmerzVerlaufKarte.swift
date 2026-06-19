import SwiftUI
import Charts

struct SchmerzVerlaufKarte: View {

    let eintraege: [PainEntry]
    var migraeneAnfaelle: [MigraeneEintrag] = []
    var zeigeStats: Bool = false

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
    @State private var chartAufgeklappt: Bool = true

    private var schmerzEintraege: [PainEntry] {
        eintraege.filter { !$0.istHautEintrag }
    }

    // MARK: - Stats (nur wenn zeigeStats = true)

    private var gesamtAvg: Double {
        guard !schmerzEintraege.isEmpty else { return 0 }
        return Double(schmerzEintraege.map(\.schmerzstaerke).reduce(0, +)) / Double(schmerzEintraege.count)
    }

    private var dieseWocheAvg: Double {
        var kal = Calendar.current; kal.firstWeekday = 2
        guard let interval = kal.dateInterval(of: .weekOfYear, for: Date()) else { return 0 }
        let w = schmerzEintraege.filter { $0.datum >= interval.start && $0.datum < interval.end }
        guard !w.isEmpty else { return 0 }
        return Double(w.map(\.schmerzstaerke).reduce(0, +)) / Double(w.count)
    }

    private var trendVorwocheWert: Double? {
        var kal = Calendar.current; kal.firstWeekday = 2
        guard let interval = kal.dateInterval(of: .weekOfYear, for: Date()),
              let vorStart = kal.date(byAdding: .weekOfYear, value: -1, to: interval.start) else { return nil }
        let diese = schmerzEintraege.filter { $0.datum >= interval.start && $0.datum < interval.end }
        let vorw  = schmerzEintraege.filter { $0.datum >= vorStart && $0.datum < interval.start }
        guard !diese.isEmpty && !vorw.isEmpty else { return nil }
        let a = Double(diese.map(\.schmerzstaerke).reduce(0, +)) / Double(diese.count)
        let b = Double(vorw.map(\.schmerzstaerke).reduce(0, +)) / Double(vorw.count)
        return a - b
    }

    private var gesamtEintraegeAnzahl: Int {
        schmerzEintraege.count + migraeneAnfaelle.count
    }

    private var topAusloeser: String? {
        let alle = schmerzEintraege.map(\.ausloeser).filter { !$0.isEmpty }
        guard !alle.isEmpty else { return nil }
        var z: [String: Int] = [:]
        for a in alle { z[a, default: 0] += 1 }
        return z.max(by: { $0.value < $1.value })?.key
    }

    // MARK: - Chart Data

    private var migraeneTagesDaten: [(datum: Date, schmerz: Double)] {
        let kal = Calendar.current
        let heute = kal.startOfDay(for: .now)
        guard let start = kal.date(byAdding: .day, value: -(zeitBereich.gesamtTage - 1), to: heute)
        else { return [] }
        var result: [(Date, Double)] = []
        var tag = start
        while tag <= heute {
            let te = migraeneAnfaelle.filter { kal.isDate($0.datum, inSameDayAs: tag) }
            if !te.isEmpty {
                let avg = Double(te.map(\.staerke).reduce(0, +)) / Double(te.count)
                result.append((tag, avg))
            }
            tag = kal.date(byAdding: .day, value: 1, to: tag) ?? tag
        }
        return result
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

    // MARK: - Body

    var body: some View {
        let daten = tagesDaten
        let aktivDaten = daten.filter { $0.anzahl > 0 }

        VStack(alignment: .leading, spacing: 12) {
            if zeigeStats {
                statsHeaderView
                Divider()
            }

            header(aktivDaten: aktivDaten)

            if !zeigeStats || chartAufgeklappt {
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
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
        .onAppear { resetScroll() }
        .onChange(of: zeitBereich) { ausgewaehlt = nil; resetScroll() }
        .sheet(isPresented: $zeigeTagesDetail) {
            if let sel = ausgewaehlt {
                TagesDetailSheet(datum: sel, eintraege: eintraege)
            }
        }
    }

    // MARK: - Stats Header

    @ViewBuilder
    private var statsHeaderView: some View {
        let avg = gesamtAvg
        let farbe = schmerzFarbe(avg)
        let t = trendVorwocheWert
        let sym: String = t.map { $0 > 0.05 ? "arrow.up" : $0 < -0.05 ? "arrow.down" : "minus" } ?? "minus"
        let trendFarbe: Color = t.map { $0 > 0.05 ? Color.red : $0 < -0.05 ? Color.green : Color.secondary } ?? .secondary
        let trendLabel = t.map { String(format: "%+.1f", $0) } ?? "–"

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ø Schmerzstärke · alle Module")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text(avg > 0 ? String(format: "%.1f", avg) : "–")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(avg > 0 ? farbe : .secondary)
                        if avg > 0 {
                            Text("/ 10").font(.title3).foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
                if avg > 0 {
                    VStack(alignment: .trailing, spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: sym).font(.caption.bold())
                            Text(trendLabel).font(.caption.bold())
                        }
                        .foregroundStyle(trendFarbe)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(trendFarbe.opacity(0.12), in: Capsule())
                        Text("vs. Vorwoche").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            HStack(spacing: 0) {
                statsMini("Diese Woche", wert: dieseWocheAvg > 0 ? String(format: "%.1f", dieseWocheAvg) : "–", farbe: .blue)
                Divider().frame(height: 36)
                statsMini("Einträge", wert: "\(gesamtEintraegeAnzahl)", farbe: .indigo)
                Divider().frame(height: 36)
                statsMini("Top Auslöser", wert: topAusloeser ?? "–", farbe: .orange)
            }
        }
    }

    private func statsMini(_ label: String, wert: String, farbe: Color) -> some View {
        VStack(spacing: 3) {
            Text(wert)
                .font(.subheadline.bold())
                .foregroundStyle(farbe)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    // MARK: - Chart Header

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
                        Button { zeigeTagesDetail = true } label: {
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
                            text: "Zeigt den Ø Schmerzwert pro Tag aus allen Modulen (Schmerz, Rheuma, Migräne). Tage ohne Eintrag werden ausgelassen – die Linie verbindet nur Tage mit tatsächlichen Daten.\n\nBedienung: Tippe oder ziehe über den Chart um einzelne Tage auszuwählen.\n\nFarbe der Punkte: grün ≤3, gelb 4–6, orange 7–8, rot ≥9."
                        )
                        .padding(.top, 2)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.15), value: ausgewaehlt)

            Spacer()

            if !zeigeStats || chartAufgeklappt {
                Picker("Zeitraum", selection: $zeitBereich) {
                    ForEach(ZeitBereich.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }

            if zeigeStats {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { chartAufgeklappt.toggle() }
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(chartAufgeklappt ? 0 : 180))
                        .animation(.easeInOut(duration: 0.25), value: chartAufgeklappt)
                        .padding(.leading, 6)
                }
                .buttonStyle(.plain)
            }
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

            let migraeneDaten = migraeneTagesDaten
            ForEach(migraeneDaten, id: \.datum) { punkt in
                PointMark(
                    x: .value("Tag", punkt.datum, unit: .day),
                    y: .value("Schmerz", punkt.schmerz)
                )
                .foregroundStyle(Color.purple)
                .symbol(.diamond)
                .symbolSize(80)
                .annotation(position: .top, spacing: 2) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 8))
                        .foregroundStyle(Color.purple.opacity(0.7))
                }
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
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
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
            if !migraeneTagesDaten.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(.purple)
                    Text("Migräne-Anfälle (getrennt erfasst)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
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
        .background(Color(.secondarySystemGroupedBackground))
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
