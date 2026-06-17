import SwiftUI
import Charts

// MARK: - Section Enum

enum RheumaAnalyseSektion: String, CaseIterable, Codable, Identifiable {
    case zusammenfassung   = "Zusammenfassung"
    case verlauf           = "Schmerzverlauf"
    case morgensteifigkeit = "Morgensteifigkeit"
    case schubMuster       = "Schub-Muster"
    case gelenke           = "Betroffene Gelenke"
    case haqVerlauf        = "HAQ-Verlauf"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .zusammenfassung:   return "chart.bar.fill"
        case .verlauf:           return "chart.line.uptrend.xyaxis"
        case .morgensteifigkeit: return "sunrise.fill"
        case .schubMuster:       return "flame.fill"
        case .gelenke:           return "figure.arms.open"
        case .haqVerlauf:        return "chart.line.downtrend.xyaxis"
        }
    }
}

// MARK: - Main View

struct RheumaAnalyseView: View {
    let eintraege: [PainEntry]
    let haqEintraege: [HAQEintrag]

    @State private var sektionen: [RheumaAnalyseSektion] = RheumaAnalyseView.sektionenLaden()
    @State private var zeitraum: Zeitraum = .alle
    @State private var zeigeAnpassen = false
    @State private var verlaufScrollPosition: Date = Date().addingTimeInterval(-60*60*24*30*5)
    @Environment(\.dismiss) private var dismiss

    enum Zeitraum: String, CaseIterable {
        case monat       = "30 T"
        case dreiMonate  = "3 M"
        case sechsMonate = "6 M"
        case jahr        = "1 J"
        case alle        = "Alle"

        var tage: Int? {
            switch self {
            case .monat:       return 30
            case .dreiMonate:  return 90
            case .sechsMonate: return 180
            case .jahr:        return 365
            case .alle:        return nil
            }
        }

        var verlaufMonate: Int {
            switch self {
            case .monat:       return 1
            case .dreiMonate:  return 3
            case .sechsMonate: return 6
            case .jahr:        return 12
            case .alle:        return 24
            }
        }
    }

    // MARK: Filtered

    private var gefiltert: [PainEntry] {
        guard let tage = zeitraum.tage else { return eintraege }
        let grenze = Calendar.current.date(byAdding: .day, value: -tage, to: Date()) ?? Date()
        return eintraege.filter { $0.datum >= grenze }
    }

    private var mitSchub: [PainEntry]  { gefiltert.filter { $0.istSchub } }
    private var mitMorgen: [PainEntry] { gefiltert.filter { $0.morgensteifigkeit > 0 } }
    private var mitGelenk: [PainEntry] { gefiltert.filter { !$0.gelenkStatus.isEmpty } }

    private var avgSchmerz: Double {
        gefiltert.isEmpty ? 0 : Double(gefiltert.map(\.schmerzstaerke).reduce(0, +)) / Double(gefiltert.count)
    }
    private var avgMorgen: Double {
        mitMorgen.isEmpty ? 0 : Double(mitMorgen.map(\.morgensteifigkeit).reduce(0, +)) / Double(mitMorgen.count)
    }

    private var gefilterteHAQ: [HAQEintrag] {
        guard let tage = zeitraum.tage else { return haqEintraege }
        let grenze = Calendar.current.date(byAdding: .day, value: -tage, to: Date()) ?? Date()
        return haqEintraege.filter { $0.datum >= grenze }
    }

    // MARK: Computed — Verlauf

    private struct MonatsWert: Identifiable {
        let id = UUID()
        let monat: Date
        let avgSchmerz: Double
        let schube: Int
    }

    private var monatlicherVerlauf: [MonatsWert] {
        let cal = Calendar.current
        var grouped: [Date: [PainEntry]] = [:]
        for e in gefiltert {
            let key = cal.date(from: cal.dateComponents([.year, .month], from: e.datum)) ?? e.datum
            grouped[key, default: []].append(e)
        }
        return grouped.map { key, entries in
            let avg = Double(entries.map(\.schmerzstaerke).reduce(0, +)) / Double(entries.count)
            return MonatsWert(monat: key, avgSchmerz: avg, schube: entries.filter { $0.istSchub }.count)
        }.sorted { $0.monat < $1.monat }
    }

    // MARK: Computed — Morgensteifigkeit

    private struct MorgenWert: Identifiable {
        let id = UUID()
        let monat: Date
        let avg: Double
    }

    private var morgensteifigkeitVerlauf: [MorgenWert] {
        let cal = Calendar.current
        var grouped: [Date: [Int]] = [:]
        for e in mitMorgen {
            let key = cal.date(from: cal.dateComponents([.year, .month], from: e.datum)) ?? e.datum
            grouped[key, default: []].append(e.morgensteifigkeit)
        }
        return grouped.map { key, werte in
            MorgenWert(monat: key, avg: Double(werte.reduce(0, +)) / Double(werte.count))
        }.sorted { $0.monat < $1.monat }
    }

    // MARK: Computed — Schub nach Wochentag

    private var schubNachWochentag: [(tag: String, anzahl: Int)] {
        let cal = Calendar.current
        let tage = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
        var counts = [Int](repeating: 0, count: 7)
        for e in mitSchub {
            let wd = cal.component(.weekday, from: e.datum)
            counts[(wd + 5) % 7] += 1
        }
        return zip(tage, counts).map { (tag: $0, anzahl: $1) }
    }

    // MARK: Computed — Top Gelenke

    private struct GelenkHaeufigkeit: Identifiable {
        let id: String
        let name: String
        let anzahl: Int
    }

    private var topGelenke: [GelenkHaeufigkeit] {
        var counts: [String: Int] = [:]
        for e in mitGelenk {
            for (key, _) in GelenkStatusCoder.decode(e.gelenkStatus) {
                counts[key, default: 0] += 1
            }
        }
        let namenMap = Dictionary(uniqueKeysWithValues: alleGelenke.map { ($0.id, $0.langname) })
        return counts
            .map { GelenkHaeufigkeit(id: $0.key, name: namenMap[$0.key] ?? $0.key, anzahl: $0.value) }
            .sorted { $0.anzahl > $1.anzahl }
            .prefix(8).map { $0 }
    }

    // MARK: Persistence

    private static let kSektionenKey = "rheumaAnalyseSektionen"

    static func sektionenLaden() -> [RheumaAnalyseSektion] {
        guard let data = UserDefaults.standard.data(forKey: kSektionenKey),
              let decoded = try? JSONDecoder().decode([RheumaAnalyseSektion].self, from: data)
        else { return RheumaAnalyseSektion.allCases }
        let missing = RheumaAnalyseSektion.allCases.filter { !decoded.contains($0) }
        return decoded + missing
    }

    private func sektionenSpeichern(_ s: [RheumaAnalyseSektion]) {
        if let data = try? JSONEncoder().encode(s) {
            UserDefaults.standard.set(data, forKey: Self.kSektionenKey)
        }
    }

    // MARK: Body

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
            .navigationTitle("Rheuma-Analyse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { zeigeAnpassen = true } label: {
                        Label("Anpassen", systemImage: "slider.horizontal.3")
                    }
                }
            }
            .sheet(isPresented: $zeigeAnpassen) {
                RheumaAnalyseAnpassenView(sektionen: $sektionen)
            }
            .onChange(of: sektionen) { _, new in sektionenSpeichern(new) }
            .onChange(of: zeitraum) { _, _ in
                verlaufScrollPosition = Date().addingTimeInterval(-60*60*24*30*5)
            }
        }
    }

    // MARK: Section Dispatcher

    @ViewBuilder
    private func sektionView(_ sektion: RheumaAnalyseSektion) -> some View {
        switch sektion {
        case .zusammenfassung:   summaryKarte
        case .verlauf:           verlaufKarte
        case .morgensteifigkeit: morgensteifigkeitKarte
        case .schubMuster:       schubMusterKarte
        case .gelenke:           gelenkHaeufigkeitKarte
        case .haqVerlauf:        haqVerlaufKarte
        }
    }

    // MARK: Helpers

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
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    private func leerKarte(_ sektion: RheumaAnalyseSektion) -> some View {
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

    // MARK: Zusammenfassung

    private var summaryKarte: some View {
        karte(titel: "Zusammenfassung", symbol: "chart.bar.fill", farbe: .purple,
              info: "Überblick über den gewählten Zeitraum. Schübe sind Einträge mit aktiviertem Schub-Marker. Morgensteifigkeit wird nur eingerechnet, wenn sie erfasst wurde. Der HAQ-Score zeigt den letzten Messwert im Zeitraum.") {
            if gefiltert.isEmpty {
                Text("Keine Einträge in diesem Zeitraum")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                HStack(spacing: 0) {
                    statZelle("\(gefiltert.count)", label: "Einträge", farbe: .purple)
                    Divider().frame(height: 44)
                    statZelle("\(mitSchub.count)", label: "Schübe",
                              farbe: mitSchub.isEmpty ? .secondary : .red)
                    Divider().frame(height: 44)
                    statZelle(String(format: "%.1f", avgSchmerz), label: "Ø Schmerz",
                              farbe: avgSchmerz <= 3 ? .green : avgSchmerz <= 6 ? .orange : .red)
                    Divider().frame(height: 44)
                    if avgMorgen > 0 {
                        statZelle(String(format: "%.0f'", avgMorgen), label: "Ø Steifigkeit",
                                  farbe: avgMorgen > 30 ? .orange : .teal)
                    } else {
                        statZelle("–", label: "Steifigkeit", farbe: .secondary)
                    }
                }
                if let letzterHAQ = gefilterteHAQ.first {
                    Divider()
                    HStack {
                        Label("HAQ-Score", systemImage: "chart.line.downtrend.xyaxis")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.2f – %@", letzterHAQ.haqScore, letzterHAQ.haqGradText))
                            .font(.caption.bold()).foregroundStyle(.indigo)
                    }
                }
            }
        }
    }

    // MARK: Verlauf

    private var verlaufKarte: some View {
        karte(titel: "Schmerzverlauf", symbol: "chart.line.uptrend.xyaxis", farbe: .purple,
              info: "Durchschnittliche Schmerzstärke pro Monat. Monate mit mindestens einem Schub sind orange markiert. Scrolle nach links für ältere Monate.") {
            if monatlicherVerlauf.isEmpty {
                Text("Keine Daten für diesen Zeitraum")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                Chart(monatlicherVerlauf) { p in
                    BarMark(
                        x: .value("Monat", p.monat, unit: .month),
                        y: .value("Schmerz", p.avgSchmerz)
                    )
                    .foregroundStyle(p.schube > 0 ? Color.orange : Color.purple.opacity(0.7))
                    .cornerRadius(4)
                }
                .chartScrollableAxes(.horizontal)
                .chartXVisibleDomain(length: 60*60*24*30 * zeitraum.verlaufMonate)
                .chartScrollPosition(x: $verlaufScrollPosition)
                .chartYScale(domain: 0...10)
                .chartXAxis {
                    AxisMarks(values: .stride(by: zeitraum.verlaufMonate > 6 ? .quarter : .month)) { _ in
                        AxisValueLabel(
                            format: zeitraum.verlaufMonate > 6
                                ? .dateTime.month(.abbreviated).year()
                                : .dateTime.month(.abbreviated)
                        )
                        AxisGridLine()
                    }
                }
                .frame(height: 160)
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.purple.opacity(0.7)).frame(width: 12, height: 12)
                        Text("Ø Schmerz").font(.caption2).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.orange).frame(width: 12, height: 12)
                        Text("Monat mit Schub").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: Morgensteifigkeit

    private var morgensteifigkeitKarte: some View {
        karte(titel: "Morgensteifigkeit", symbol: "sunrise.fill", farbe: .orange,
              info: "Durchschnittliche Dauer der Morgensteifigkeit in Minuten pro Monat. Bei Rheumatoider Arthritis gilt Morgensteifigkeit über 30 Minuten als klinisch relevantes Entzündungszeichen und sollte dem Arzt mitgeteilt werden.") {
            if morgensteifigkeitVerlauf.isEmpty {
                Text("Noch keine Morgensteifigkeit erfasst")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                Chart(morgensteifigkeitVerlauf) { p in
                    BarMark(
                        x: .value("Monat", p.monat, unit: .month),
                        y: .value("Minuten", p.avg)
                    )
                    .foregroundStyle(p.avg > 30 ? Color.orange : Color.teal.opacity(0.75))
                    .cornerRadius(4)

                    RuleMark(y: .value("Grenzwert", 30))
                        .lineStyle(StrokeStyle(dash: [4]))
                        .foregroundStyle(Color.orange.opacity(0.5))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("30 Min.").font(.caption2).foregroundStyle(.orange)
                        }
                }
                .chartYAxisLabel("Minuten")
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                        AxisGridLine()
                    }
                }
                .frame(height: 150)
                HStack {
                    Text("Ø im Zeitraum")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.0f Minuten", avgMorgen))
                        .font(.caption.bold())
                        .foregroundStyle(avgMorgen > 30 ? .orange : .teal)
                }
            }
        }
    }

    // MARK: Schub-Muster

    private var schubMusterKarte: some View {
        karte(titel: "Schub-Muster", symbol: "flame.fill", farbe: .red,
              info: "Häufigkeit von Schüben nach Wochentag. So erkennst du, ob bestimmte Tage – z.B. nach körperlich anstrengenden Wochenenden – anfälliger für Schübe sind.") {
            if mitSchub.isEmpty {
                Text("Keine Schübe in diesem Zeitraum erfasst")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                Chart(schubNachWochentag, id: \.tag) { item in
                    BarMark(
                        x: .value("Tag", item.tag),
                        y: .value("Schübe", item.anzahl)
                    )
                    .foregroundStyle(Color.red.opacity(0.75))
                    .cornerRadius(4)
                }
                .frame(height: 120)
                HStack {
                    Text("Schübe gesamt")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(mitSchub.count)")
                        .font(.caption.bold()).foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: Gelenke

    @ViewBuilder
    private var gelenkHaeufigkeitKarte: some View {
        if topGelenke.isEmpty {
            leerKarte(.gelenke)
        } else {
            karte(titel: "Betroffene Gelenke", symbol: "figure.arms.open", farbe: .purple,
                  info: "Die häufigsten betroffenen Gelenke aus allen Einträgen mit Gelenkstatus – sowohl schmerzhafte als auch geschwollene Gelenke werden gezählt. Hilft dir und deinem Arzt, Muster in der Gelenkbeteiligung zu erkennen.") {
                VStack(spacing: 8) {
                    ForEach(topGelenke) { g in
                        HStack(spacing: 8) {
                            Text(g.name)
                                .font(.caption)
                                .frame(width: 130, alignment: .leading)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.secondary.opacity(0.12))
                                        .frame(height: 18)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.purple.opacity(0.7))
                                        .frame(
                                            width: geo.size.width * CGFloat(g.anzahl) / CGFloat(topGelenke.first?.anzahl ?? 1),
                                            height: 18
                                        )
                                }
                            }
                            .frame(height: 18)
                            Text("\(g.anzahl)×")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .frame(width: 30, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }

    // MARK: HAQ-Verlauf

    @ViewBuilder
    private var haqVerlaufKarte: some View {
        if gefilterteHAQ.isEmpty {
            leerKarte(.haqVerlauf)
        } else {
            karte(titel: "HAQ-Verlauf", symbol: "chart.line.downtrend.xyaxis", farbe: .indigo,
                  info: "Der HAQ-DI (Health Assessment Questionnaire Disability Index) misst die körperliche Einschränkung auf einer Skala von 0 (keine Einschränkung) bis 3 (schwere Einschränkung). Ein sinkender Wert bedeutet Verbesserung der Funktionsfähigkeit.") {
                let sorted = gefilterteHAQ.sorted { $0.datum < $1.datum }
                Chart(sorted) { e in
                    LineMark(
                        x: .value("Datum", e.datum),
                        y: .value("HAQ", e.haqScore)
                    )
                    .foregroundStyle(Color.indigo)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Datum", e.datum),
                        y: .value("HAQ", e.haqScore)
                    )
                    .foregroundStyle(Color.indigo)
                    .symbolSize(35)
                }
                .chartYScale(domain: 0...3)
                .chartYAxis {
                    AxisMarks(values: [0, 1, 2, 3]) { _ in
                        AxisValueLabel()
                        AxisGridLine()
                    }
                }
                .frame(height: 150)
                if let letzter = gefilterteHAQ.first {
                    HStack {
                        Text("Letzter HAQ-Score")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.2f – %@", letzter.haqScore, letzter.haqGradText))
                            .font(.caption.bold()).foregroundStyle(.indigo)
                    }
                }
            }
        }
    }
}

// MARK: - Anpassen

struct RheumaAnalyseAnpassenView: View {
    @Binding var sektionen: [RheumaAnalyseSektion]
    @Environment(\.dismiss) private var dismiss
    @State private var editMode: EditMode = .active

    var body: some View {
        NavigationStack {
            List {
                ForEach(sektionen) { sektion in
                    Label(sektion.rawValue, systemImage: sektion.symbol)
                }
                .onMove { from, to in
                    sektionen.move(fromOffsets: from, toOffset: to)
                }
            }
            .environment(\.editMode, $editMode)
            .navigationTitle("Reihenfolge anpassen")
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
