import SwiftUI
import SwiftData
import Charts

struct ZyklusAnalyseView: View {
    @Query(sort: \ZyklusEintrag.datum, order: .forward) private var eintraege: [ZyklusEintrag]
    @Query(sort: \PainEntry.datum, order: .reverse) private var painEntries: [PainEntry]

    private var analyse: ZyklusAnalyse {
        ZyklusRechner.analyse(eintraege: Array(eintraege))
    }

    var body: some View {
        Group {
            if eintraege.isEmpty {
                ContentUnavailableView(
                    "Keine Daten",
                    systemImage: "drop.circle",
                    description: Text("Erfasse zuerst Zyklusdaten.")
                )
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        statistikKarten
                        zykluslaengenChart
                        schleimMuster
                        symptomHaeufigkeit
                        basaltemperaturChart
                        ovulationstestKarte
                        schmerzKorrelation
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Zyklusanalyse")
    }

    // MARK: - Statistik Karten

    private var statistikKarten: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statCard("Ø Zykluslänge", String(format: "%.0f Tage", analyse.zykluslaenge), "arrow.clockwise", .pink)
                statCard("Ø Periode", String(format: "%.0f Tage", analyse.periodendauer), "drop.fill", .red)
                statCard("Variation", String(format: "±%.1f Tage", analyse.variation), "chart.bar.xaxis", .orange)
                statCard("Zyklen erfasst", "\(max(analyse.zyklusStarts.count - 1, 0))", "list.number", .purple)
            }

            lernKarte
        }
    }

    @ViewBuilder
    private var lernKarte: some View {
        let adaptZyklus = Int(round(analyse.adaptierteZykluslaenge))
        let adaptPeriod = Int(round(analyse.adaptiertePeriodendauer))
        let avgZyklus   = Int(round(analyse.zykluslaenge))
        let avgPeriod   = Int(round(analyse.periodendauer))
        let zyklusDiff  = adaptZyklus - avgZyklus
        let periodDiff  = adaptPeriod - avgPeriod
        let hatLerndaten = analyse.zyklusStarts.count >= 3 // enough for weighted avg to differ

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile").foregroundStyle(.teal).font(.title3)
                Text("Adaptive Vorhersage").font(.subheadline.bold())
                Spacer()
                if hatLerndaten {
                    Label("Aktiv", systemImage: "checkmark.circle.fill")
                        .font(.caption2).foregroundStyle(.teal)
                } else {
                    Text("Ab 3 Zyklen aktiv").font(.caption2).foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("\(adaptZyklus) Tage")
                        .font(.subheadline.bold())
                        .foregroundStyle(zyklusDiff != 0 ? .pink : .primary)
                    Text("Vorhersage Zyklus")
                        .font(.caption2).foregroundStyle(.secondary)
                    if zyklusDiff != 0 {
                        Text(zyklusDiff > 0 ? "+\(zyklusDiff)d" : "\(zyklusDiff)d")
                            .font(.caption2.bold())
                            .foregroundStyle(zyklusDiff > 0 ? .orange : .blue)
                    }
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 44)

                VStack(spacing: 4) {
                    Text("\(adaptPeriod) Tage")
                        .font(.subheadline.bold())
                        .foregroundStyle(periodDiff != 0 ? .red : .primary)
                    Text("Vorhersage Periode")
                        .font(.caption2).foregroundStyle(.secondary)
                    if periodDiff != 0 {
                        Text(periodDiff > 0 ? "+\(periodDiff)d" : "\(periodDiff)d")
                            .font(.caption2.bold())
                            .foregroundStyle(periodDiff > 0 ? .orange : .blue)
                    }
                }
                .frame(maxWidth: .infinity)

                if let offset = analyse.gelernterOvulationsOffset {
                    Divider().frame(height: 44)
                    VStack(spacing: 4) {
                        Text("Tag \(offset)")
                            .font(.subheadline.bold()).foregroundStyle(.teal)
                        Text("Eisprung (gelernt)")
                            .font(.caption2).foregroundStyle(.secondary)
                        let std = avgZyklus - 14
                        let diff = offset - std
                        if diff != 0 {
                            Text(diff > 0 ? "+\(diff)d" : "\(diff)d")
                                .font(.caption2.bold())
                                .foregroundStyle(diff > 0 ? .orange : .blue)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            Text("Letzte 3 Zyklen gewichtet (50/30/20 %). Ø-Werte bleiben für Statistik unverändert.")
                .font(.caption2).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(hatLerndaten ? Color.teal.opacity(0.08) : Color.secondary.opacity(0.05),
                    in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Zykluslängen Chart

    @ViewBuilder
    private var zykluslaengenChart: some View {
        let laengen = berechneLaengen()
        if laengen.count >= 2 {
            karte {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Zykluslängen").font(.headline)
                    Text("Verlauf der letzten Zyklen").font(.caption).foregroundStyle(.secondary)
                }
                Chart {
                    ForEach(Array(laengen.enumerated()), id: \.offset) { i, laenge in
                        LineMark(
                            x: .value("Zyklus", i + 1),
                            y: .value("Tage", laenge)
                        )
                        .foregroundStyle(Color.pink.gradient)
                        .interpolationMethod(.catmullRom)
                        PointMark(
                            x: .value("Zyklus", i + 1),
                            y: .value("Tage", laenge)
                        )
                        .foregroundStyle(Color.pink)
                        .annotation(position: .top) {
                            Text(String(format: "%.0f", laenge))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    RuleMark(y: .value("Ø", analyse.zykluslaenge))
                        .foregroundStyle(Color.secondary.opacity(0.4))
                        .lineStyle(StrokeStyle(dash: [4]))
                }
                .chartYScale(domain: max((laengen.min() ?? 20) - 3, 0) ... (laengen.max() ?? 35) + 3)
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisValueLabel { Text("Z\(value.as(Int.self) ?? 0)") }
                    }
                }
                .frame(height: 160)
            }
        }
    }

    private func berechneLaengen() -> [Double] {
        let kal = Calendar.current
        let starts = analyse.zyklusStarts
        return (1..<starts.count).map { i in
            Double(kal.dateComponents([.day], from: starts[i - 1], to: starts[i]).day ?? 28)
        }
    }

    // MARK: - Zervixschleim

    @ViewBuilder
    private var schleimMuster: some View {
        let verteilung = schleimVerteilung()
        if !verteilung.isEmpty {
            karte {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Zervixschleim").font(.headline)
                    Text("Häufigkeit der erfassten Typen").font(.caption).foregroundStyle(.secondary)
                }

                let maxAnzahl = Double(verteilung.map(\.anzahl).max() ?? 1)
                VStack(spacing: 8) {
                    ForEach(verteilung) { item in
                        HStack(spacing: 10) {
                            Circle().fill(schleimFarbe(item.typ)).frame(width: 8, height: 8)
                            Text(item.typ.capitalized)
                                .font(.subheadline)
                                .frame(width: 72, alignment: .leading)
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(schleimFarbe(item.typ).opacity(0.3))
                                    .frame(width: geo.size.width * CGFloat(item.anzahl) / CGFloat(maxAnzahl), height: 10)
                                    .frame(maxHeight: .infinity, alignment: .center)
                            }
                            Text("\(item.anzahl)×").font(.caption.bold()).foregroundStyle(.secondary)
                        }
                        .frame(height: 20)
                    }
                }

                if verteilung.contains(where: { ["wässrig", "eiweiss"].contains($0.typ.lowercased()) }) {
                    Label("Wässrig & Eiweiss-Schleim werden als fruchtbar gewertet (Symptothermalmethode).", systemImage: "info.circle")
                        .font(.caption2).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private struct SchleimItem: Identifiable {
        let id = UUID()
        let typ: String
        let anzahl: Int
    }

    private func schleimVerteilung() -> [SchleimItem] {
        var zähler: [String: Int] = [:]
        for e in eintraege where !e.zervixschleim.isEmpty {
            zähler[e.zervixschleim, default: 0] += 1
        }
        return ["trocken", "klebrig", "cremig", "wässrig", "Eiweiss"].compactMap { typ in
            guard let count = zähler[typ], count > 0 else { return nil }
            return SchleimItem(typ: typ, anzahl: count)
        }
    }

    private func schleimFarbe(_ typ: String) -> Color {
        switch typ.lowercased() {
        case "trocken": return .gray
        case "klebrig": return .yellow
        case "cremig": return .orange
        case "wässrig": return .blue
        case "eiweiss": return .teal
        default: return .secondary
        }
    }

    // MARK: - Symptome

    @ViewBuilder
    private var symptomHaeufigkeit: some View {
        let symptome = topSymptome()
        if !symptome.isEmpty {
            karte {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Häufigste Symptome").font(.headline)
                    Text("Alle Zykluseinträge").font(.caption).foregroundStyle(.secondary)
                }
                Chart(symptome.prefix(8)) { s in
                    BarMark(
                        x: .value("Anzahl", s.anzahl),
                        y: .value("Symptom", s.name)
                    )
                    .foregroundStyle(Color.purple.gradient)
                    .cornerRadius(4)
                    .annotation(position: .trailing) {
                        Text("\(s.anzahl)").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .frame(height: CGFloat(min(symptome.count, 8)) * 30 + 20)
            }
        }
    }

    private struct SymptomItem: Identifiable {
        let id = UUID()
        let name: String
        let anzahl: Int
    }

    private func topSymptome() -> [SymptomItem] {
        var zähler: [String: Int] = [:]
        for e in eintraege {
            for s in e.symptome.components(separatedBy: ", ") where !s.isEmpty {
                zähler[s, default: 0] += 1
            }
        }
        return zähler.map { SymptomItem(name: $0.key, anzahl: $0.value) }
                     .sorted { $0.anzahl > $1.anzahl }
    }

    // MARK: - Basaltemperatur

    @ViewBuilder
    private var basaltemperaturChart: some View {
        let tempDaten = basaltemperaturDaten()
        if tempDaten.count >= 3 {
            let minTemp = (tempDaten.map(\.temp).min() ?? 36.0) - 0.15
            let maxTemp = (tempDaten.map(\.temp).max() ?? 37.0) + 0.15
            karte {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Basaltemperatur").font(.headline)
                    Text("Aktueller Zyklus").font(.caption).foregroundStyle(.secondary)
                }
                Chart(tempDaten, id: \.datum) { punkt in
                    LineMark(
                        x: .value("Tag", punkt.datum, unit: .day),
                        y: .value("°C", punkt.temp)
                    )
                    .foregroundStyle(Color.orange.gradient)
                    .interpolationMethod(.catmullRom)
                    PointMark(
                        x: .value("Tag", punkt.datum, unit: .day),
                        y: .value("°C", punkt.temp)
                    )
                    .foregroundStyle(Color.orange)
                    .symbolSize(30)
                }
                .chartYScale(domain: minTemp...maxTemp)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 3)) {
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }
                .frame(height: 160)
            }
        }
    }

    private struct TempPunkt {
        let datum: Date
        let temp: Double
    }

    private func basaltemperaturDaten() -> [TempPunkt] {
        let kal = Calendar.current
        let startDatum = analyse.zyklusStarts.last
        return eintraege
            .filter { $0.basaltemperatur > 0 && (startDatum == nil || kal.startOfDay(for: $0.datum) >= startDatum!) }
            .map { TempPunkt(datum: kal.startOfDay(for: $0.datum), temp: $0.basaltemperatur) }
            .sorted { $0.datum < $1.datum }
    }

    // MARK: - Ovulationstest

    @ViewBuilder
    private var ovulationstestKarte: some View {
        let tests = ovulationstests()
        if !tests.isEmpty {
            karte {
                Text("Ovulationstests").font(.headline)
                VStack(spacing: 8) {
                    ForEach(tests.suffix(10), id: \.datum) { test in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(ovuFarbe(test.ergebnis))
                                .frame(width: 12, height: 12)
                            Text(test.datum.formatted(.dateTime.day().month(.abbreviated).year()))
                                .font(.caption).foregroundStyle(.secondary)
                                .frame(width: 80, alignment: .leading)
                            Text(test.ergebnis.capitalized).font(.subheadline)
                            Spacer()
                            if test.ergebnis == "positiv" {
                                Image(systemName: "star.fill").font(.caption2).foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }
        }
    }

    private struct OvuTest {
        let datum: Date
        let ergebnis: String
    }

    private func ovulationstests() -> [OvuTest] {
        eintraege.filter { !$0.ovulationstest.isEmpty }
                 .map { OvuTest(datum: $0.datum, ergebnis: $0.ovulationstest) }
                 .sorted { $0.datum < $1.datum }
    }

    private func ovuFarbe(_ ergebnis: String) -> Color {
        switch ergebnis {
        case "positiv": return .orange
        case "negativ": return .gray.opacity(0.4)
        default: return .yellow.opacity(0.7)
        }
    }

    // MARK: - Schmerz je Phase

    @ViewBuilder
    private var schmerzKorrelation: some View {
        if !painEntries.isEmpty && !analyse.zyklusStarts.isEmpty {
            let daten = ZyklusRechner.schmerzJePhase(painEntries: Array(painEntries), analyse: analyse)
            if !daten.isEmpty {
                karte {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Schmerz & Zyklus").font(.headline)
                        Text("Ø Schmerzstärke je Phase").font(.caption).foregroundStyle(.secondary)
                    }
                    Chart(daten, id: \.phase.rawValue) { d in
                        BarMark(
                            x: .value("Phase", d.phase.rawValue),
                            y: .value("Schmerz", d.avgSchmerz)
                        )
                        .foregroundStyle(phaseFarbe(d.phase).gradient)
                        .cornerRadius(6)
                        .annotation(position: .top) {
                            Text(String(format: "%.1f", d.avgSchmerz))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .chartYScale(domain: 0...10)
                    .frame(height: 160)

                    HStack(spacing: 12) {
                        ForEach(daten, id: \.phase.rawValue) { d in
                            HStack(spacing: 4) {
                                Circle().fill(phaseFarbe(d.phase)).frame(width: 8, height: 8)
                                Text("\(d.anzahl)").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text("Schmerzeinträge gesamt: \(daten.map(\.anzahl).reduce(0, +))")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func phaseFarbe(_ p: ZyklusRechner.Zyklusphase) -> Color {
        switch p {
        case .menstruation: return .red
        case .follikelphase: return .yellow
        case .ovulation: return .orange
        case .lutealphase: return .purple
        }
    }

    // MARK: - Helpers

    private func statCard(_ titel: String, _ wert: String, _ symbol: String, _ farbe: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).foregroundStyle(farbe).font(.title3).frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(titel).font(.caption).foregroundStyle(.secondary)
                Text(wert).font(.subheadline.bold())
            }
            Spacer()
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func karte<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) { content() }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
