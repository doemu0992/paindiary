import SwiftUI
import Charts

// MARK: - Section Enum

enum DiabetesAnalyseSektion: String, CaseIterable, Codable, Identifiable {
    case zusammenfassung  = "Zusammenfassung"
    case verlauf          = "Glukoseverlauf"
    case zeitpunkt        = "Messzeitpunkt-Vergleich"
    case ereignisse       = "Hypo- & Hyper-Ereignisse"
    case tageszeitMuster  = "Tageszeit-Muster"
    case insulin          = "Insulin-Überblick"
    case kiInsicht        = "KI-Einblick"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .zusammenfassung: return "chart.bar.fill"
        case .verlauf:         return "chart.line.uptrend.xyaxis"
        case .zeitpunkt:       return "clock.arrow.2.circlepath"
        case .ereignisse:      return "exclamationmark.triangle.fill"
        case .tageszeitMuster: return "clock.fill"
        case .insulin:         return "syringe.fill"
        case .kiInsicht:       return "sparkles"
        }
    }
}

// MARK: - Main View

struct DiabetesAnalyseView: View {
    let messungen: [BlutzuckerEintrag]

    @State private var sektionen: [DiabetesAnalyseSektion] = DiabetesAnalyseView.sektionenLaden()
    @State private var zeitraum: Zeitraum = .monat
    @State private var zeigeAnpassen = false
    @State private var verlaufScrollPosition: Date = Date().addingTimeInterval(-60*60*24*30)
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

    private var gefiltert: [BlutzuckerEintrag] {
        guard let tage = zeitraum.tage else { return messungen }
        let grenze = Calendar.current.date(byAdding: .day, value: -tage, to: Date()) ?? Date()
        return messungen.filter { $0.datum >= grenze }
    }

    private var imZiel: [BlutzuckerEintrag]    { gefiltert.filter(\.zielbereich) }
    private var hypos:  [BlutzuckerEintrag]    { gefiltert.filter { $0.wert < 3.9 } }
    private var hypers: [BlutzuckerEintrag]    { gefiltert.filter { $0.wert > 7.8 } }
    private var nuechtern: [BlutzuckerEintrag] { gefiltert.filter { $0.messZeitpunkt == "Nüchtern" } }
    private var mitInsulin: [BlutzuckerEintrag] { gefiltert.filter { $0.insulinEinheiten > 0 } }

    private var pctZielbereich: Int {
        guard !gefiltert.isEmpty else { return 0 }
        return Int(Double(imZiel.count) / Double(gefiltert.count) * 100)
    }

    private var avgGesamt: Double? {
        guard !gefiltert.isEmpty else { return nil }
        return gefiltert.map(\.wert).reduce(0, +) / Double(gefiltert.count)
    }

    private var avgNuechtern: Double? {
        guard !nuechtern.isEmpty else { return nil }
        return nuechtern.map(\.wert).reduce(0, +) / Double(nuechtern.count)
    }

    // MARK: Computed — Verlauf (7-Tage-Schnitt)

    private struct WochenPunkt: Identifiable {
        let id = UUID()
        let woche: Date
        let avg: Double
        let min: Double
        let max: Double
        let anzahl: Int
    }

    private var wochenVerlauf: [WochenPunkt] {
        let cal = Calendar.current
        let anzahlWochen = max(4, zeitraum.verlaufMonate * 4)
        return (0..<anzahlWochen).reversed().compactMap { offset -> WochenPunkt? in
            guard let ref  = cal.date(byAdding: .weekOfYear, value: -offset, to: Date()),
                  let wocheBeginn = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: ref)),
                  let wocheEnde  = cal.date(byAdding: .day, value: 7, to: wocheBeginn)
            else { return nil }
            let werte = gefiltert.filter { $0.datum >= wocheBeginn && $0.datum < wocheEnde }.map(\.wert)
            guard !werte.isEmpty else { return nil }
            return WochenPunkt(
                woche: wocheBeginn,
                avg: werte.reduce(0, +) / Double(werte.count),
                min: werte.min() ?? 0,
                max: werte.max() ?? 0,
                anzahl: werte.count
            )
        }
    }

    // MARK: Computed — Messzeitpunkt-Vergleich

    private struct ZeitpunktStat: Identifiable {
        let id = UUID()
        let name: String
        let avg: Double
        let anzahl: Int
    }

    private var zeitpunktStats: [ZeitpunktStat] {
        let zeitpunkte = ["Nüchtern", "Vor Essen", "2h nach Essen", "Vor Schlaf", "Beliebig"]
        return zeitpunkte.compactMap { zp -> ZeitpunktStat? in
            let gruppe = gefiltert.filter { $0.messZeitpunkt == zp }
            guard !gruppe.isEmpty else { return nil }
            let avg = gruppe.map(\.wert).reduce(0, +) / Double(gruppe.count)
            return ZeitpunktStat(name: zp, avg: avg, anzahl: gruppe.count)
        }
    }

    // MARK: Computed — Ereignisse pro Woche

    private struct EreignisWoche: Identifiable {
        let id = UUID()
        let woche: Date
        let hypos: Int
        let hypers: Int
    }

    private var ereignisseProWoche: [EreignisWoche] {
        let cal = Calendar.current
        let anzahlWochen = max(4, zeitraum.verlaufMonate * 4)
        return (0..<anzahlWochen).reversed().compactMap { offset -> EreignisWoche? in
            guard let ref = cal.date(byAdding: .weekOfYear, value: -offset, to: Date()),
                  let wocheBeginn = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: ref)),
                  let wocheEnde  = cal.date(byAdding: .day, value: 7, to: wocheBeginn)
            else { return nil }
            let woche = gefiltert.filter { $0.datum >= wocheBeginn && $0.datum < wocheEnde }
            let h = woche.filter { $0.wert < 3.9 }.count
            let hy = woche.filter { $0.wert > 7.8 }.count
            guard h + hy > 0 else { return nil }
            return EreignisWoche(woche: wocheBeginn, hypos: h, hypers: hy)
        }
    }

    // MARK: Computed — Tageszeit-Muster

    private struct TageszeitPunkt: Identifiable {
        let id = UUID()
        let label: String
        let avg: Double
        let anzahl: Int
    }

    private var tageszeitMuster: [TageszeitPunkt] {
        let slots: [(String, ClosedRange<Int>)] = [
            ("Nacht",   0...5),
            ("Morgens", 6...10),
            ("Mittags", 11...13),
            ("Nachm.",  14...17),
            ("Abend",   18...21),
            ("Spät",    22...23)
        ]
        return slots.compactMap { label, range in
            let gruppe = gefiltert.filter { range.contains(Calendar.current.component(.hour, from: $0.datum)) }
            guard !gruppe.isEmpty else { return nil }
            let avg = gruppe.map(\.wert).reduce(0, +) / Double(gruppe.count)
            return TageszeitPunkt(label: label, avg: avg, anzahl: gruppe.count)
        }
    }

    // MARK: Computed — Insulin

    private struct InsulinTypStat: Identifiable {
        let id = UUID()
        let typ: String
        let avgEinheiten: Double
        let anzahl: Int
    }

    private var insulinStats: [InsulinTypStat] {
        let typen = ["Kurzzeit", "Langzeit", "Mischung"]
        return typen.compactMap { typ -> InsulinTypStat? in
            let gruppe = mitInsulin.filter { $0.insulinTyp == typ }
            guard !gruppe.isEmpty else { return nil }
            let avg = gruppe.map(\.insulinEinheiten).reduce(0, +) / Double(gruppe.count)
            return InsulinTypStat(typ: typ, avgEinheiten: avg, anzahl: gruppe.count)
        }
    }

    // MARK: Persistence

    private static let kSektionenKey = "diabetesAnalyseSektionen"

    static func sektionenLaden() -> [DiabetesAnalyseSektion] {
        guard let data = UserDefaults.standard.data(forKey: kSektionenKey),
              let decoded = try? JSONDecoder().decode([DiabetesAnalyseSektion].self, from: data)
        else { return DiabetesAnalyseSektion.allCases }
        let missing = DiabetesAnalyseSektion.allCases.filter { !decoded.contains($0) }
        return decoded + missing
    }

    private func sektionenSpeichern(_ s: [DiabetesAnalyseSektion]) {
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
            .navigationTitle("Diabetes-Analyse")
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
                DiabetesAnalyseAnpassenView(sektionen: $sektionen)
            }
            .onChange(of: sektionen) { _, new in sektionenSpeichern(new) }
            .onChange(of: zeitraum) { _, _ in
                verlaufScrollPosition = Date().addingTimeInterval(-60*60*24*30)
            }
        }
    }

    // MARK: Section Dispatcher

    @ViewBuilder
    private func sektionView(_ sektion: DiabetesAnalyseSektion) -> some View {
        switch sektion {
        case .zusammenfassung: summaryKarte
        case .verlauf:         verlaufKarte
        case .zeitpunkt:
            if zeitpunktStats.isEmpty { leerKarte(sektion) }
            else { zeitpunktKarte }
        case .ereignisse:
            if hypos.isEmpty && hypers.isEmpty { leerKarte(sektion) }
            else { ereignisseKarte }
        case .tageszeitMuster:
            if tageszeitMuster.isEmpty { leerKarte(sektion) }
            else { tageszeitKarte }
        case .insulin:
            if mitInsulin.isEmpty { leerKarte(sektion) }
            else { insulinKarte }
        case .kiInsicht: KIAnalyseKarte(prompt: kiPrompt, modulTint: .blue)
        }
    }

    private var kiPrompt: String {
        """
        Diabetes-Analyse (\(zeitraum.rawValue)):
        - \(gefiltert.count) Messungen, Ø Glukose: \(avgGesamt.map { String(format: "%.1f mmol/L", $0) } ?? "–")
        - Zeit im Zielbereich (TIR): \(pctZielbereich)%
        - Hypos (< 3.9 mmol/L): \(hypos.count), Hypers (> 7.8 mmol/L): \(hypers.count)
        - Ø Nüchternwert: \(avgNuechtern.map { String(format: "%.1f mmol/L", $0) } ?? "–")
        - Mit Insulin: \(mitInsulin.count) Messungen
        Identifiziere Muster und gib 3–4 kurze Einblicke.
        """
    }

    // MARK: Helpers

    private func karte<Content: View>(
        titel: String,
        symbol: String,
        farbe: Color = .blue,
        info: String = "",
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Label(titel, systemImage: symbol)
                    .font(.headline).foregroundStyle(farbe)
                if !info.isEmpty {
                    Spacer(minLength: 4)
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

    private func leerKarte(_ sektion: DiabetesAnalyseSektion) -> some View {
        HStack(spacing: 12) {
            Image(systemName: sektion.symbol)
                .font(.title2).foregroundStyle(.secondary.opacity(0.4))
            VStack(alignment: .leading, spacing: 4) {
                Text(sektion.rawValue)
                    .font(.subheadline.bold()).foregroundStyle(.secondary)
                Text("Keine Daten für diesen Zeitraum")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    private func statZelle(_ wert: String, label: String, farbe: Color = .primary) -> some View {
        VStack(spacing: 4) {
            Text(wert).font(.title2.bold()).foregroundStyle(farbe)
            Text(label).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func wertFarbe(_ wert: Double) -> Color {
        switch wert {
        case ..<3.9:    return .red
        case 3.9..<7.8: return .green
        default:        return .orange
        }
    }

    // MARK: Zusammenfassung

    private var summaryKarte: some View {
        karte(
            titel: "Zusammenfassung",
            symbol: "chart.bar.fill",
            info: "Überblick über den gewählten Zeitraum. Zeit im Zielbereich (TIR) ist 3,9–7,8 mmol/L. Hypo < 3,9, Hyper > 7,8 mmol/L."
        ) {
            if gefiltert.isEmpty {
                Text("Keine Messungen in diesem Zeitraum")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                HStack(spacing: 0) {
                    statZelle("\(gefiltert.count)", label: "Messungen", farbe: .blue)
                    Divider().frame(height: 44)
                    statZelle(avgGesamt.map { String(format: "%.1f", $0) } ?? "–",
                              label: "Ø Gesamt",
                              farbe: avgGesamt.map { wertFarbe($0) } ?? .secondary)
                    Divider().frame(height: 44)
                    statZelle("\(pctZielbereich)%",
                              label: "Zeit im Ziel",
                              farbe: pctZielbereich >= 70 ? .green : pctZielbereich >= 50 ? .orange : .red)
                    Divider().frame(height: 44)
                    statZelle(avgNuechtern.map { String(format: "%.1f", $0) } ?? "–",
                              label: "Ø Nüchtern",
                              farbe: avgNuechtern.map { nuechternFarbe($0) } ?? .secondary)
                }

                Divider()

                HStack(spacing: 0) {
                    statZelle("\(hypos.count)", label: "Hypos", farbe: hypos.isEmpty ? .secondary : .red)
                    Divider().frame(height: 44)
                    statZelle("\(hypers.count)", label: "Hypers", farbe: hypers.isEmpty ? .secondary : .orange)
                    Divider().frame(height: 44)
                    let cv: Double? = stdAbweichung()
                    statZelle(cv.map { String(format: "%.2f", $0) } ?? "–",
                              label: "Variabilität (SD)",
                              farbe: cv.map { $0 < 1.5 ? .green : $0 < 2.5 ? .orange : .red } ?? .secondary)
                    Divider().frame(height: 44)
                    statZelle("\(mitInsulin.count)", label: "Mit Insulin", farbe: .blue)
                }
            }
        }
    }

    private func stdAbweichung() -> Double? {
        guard gefiltert.count > 1, let avg = avgGesamt else { return nil }
        let sumSq = gefiltert.map { pow($0.wert - avg, 2) }.reduce(0, +)
        return sqrt(sumSq / Double(gefiltert.count))
    }

    private func nuechternFarbe(_ wert: Double) -> Color {
        switch wert {
        case ..<3.9:    return .red
        case 3.9..<6.0: return .green
        case 6.0..<7.0: return .orange
        default:        return .red
        }
    }

    // MARK: Verlauf

    private var verlaufKarte: some View {
        karte(
            titel: "Glukoseverlauf",
            symbol: "chart.line.uptrend.xyaxis",
            info: "Wöchentlicher Durchschnittswert mit Min/Max-Spannweite. Die gestrichelte Linie zeigt den oberen Zielbereich (7,8 mmol/L). Grüne Bereiche liegen im Ziel."
        ) {
            if wochenVerlauf.isEmpty {
                Text("Keine Daten für diesen Zeitraum")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                Chart {
                    RuleMark(y: .value("Ziel oben", 7.8))
                        .lineStyle(StrokeStyle(dash: [4]))
                        .foregroundStyle(Color.orange.opacity(0.6))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("7.8").font(.caption2).foregroundStyle(.orange)
                        }
                    RuleMark(y: .value("Ziel unten", 3.9))
                        .lineStyle(StrokeStyle(dash: [4]))
                        .foregroundStyle(Color.red.opacity(0.5))
                        .annotation(position: .bottom, alignment: .trailing) {
                            Text("3.9").font(.caption2).foregroundStyle(.red)
                        }
                    ForEach(wochenVerlauf) { p in
                        AreaMark(
                            x: .value("Woche", p.woche),
                            yStart: .value("Min", p.min),
                            yEnd: .value("Max", p.max)
                        )
                        .foregroundStyle(Color.blue.opacity(0.08))
                        LineMark(
                            x: .value("Woche", p.woche),
                            y: .value("Ø", p.avg)
                        )
                        .foregroundStyle(Color.blue)
                        .interpolationMethod(.catmullRom)
                        PointMark(
                            x: .value("Woche", p.woche),
                            y: .value("Ø", p.avg)
                        )
                        .foregroundStyle(wertFarbe(p.avg))
                        .symbolSize(30)
                    }
                }
                .chartScrollableAxes(.horizontal)
                .chartXVisibleDomain(length: 60*60*24*7 * min(wochenVerlauf.count, zeitraum.verlaufMonate * 4))
                .chartScrollPosition(x: $verlaufScrollPosition)
                .chartYScale(domain: 2...16)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                        AxisGridLine()
                    }
                }
                .frame(height: 160)

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Circle().fill(Color.blue).frame(width: 8, height: 8)
                        Text("Ø-Wert").font(.caption2).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.blue.opacity(0.2)).frame(width: 12, height: 8)
                        Text("Min–Max").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: Zeitpunkt-Vergleich

    private var zeitpunktKarte: some View {
        karte(
            titel: "Messzeitpunkt-Vergleich",
            symbol: "clock.arrow.2.circlepath",
            info: "Vergleich der durchschnittlichen Blutzuckerwerte je nach Messzeitpunkt. Hohe Werte 2h nach Essen deuten auf unzureichende Insulinreaktion hin."
        ) {
            Chart(zeitpunktStats) { stat in
                BarMark(
                    x: .value("Zeitpunkt", stat.name),
                    y: .value("Ø mmol/L", stat.avg)
                )
                .foregroundStyle(wertFarbe(stat.avg).gradient)
                .cornerRadius(4)
                .annotation(position: .top) {
                    Text(String(format: "%.1f", stat.avg))
                        .font(.caption2.bold())
                        .foregroundStyle(wertFarbe(stat.avg))
                }
            }
            .chartYScale(domain: 0...14)
            .chartXAxis {
                AxisMarks { val in
                    AxisValueLabel {
                        if let s = val.as(String.self) {
                            Text(s).font(.caption2).lineLimit(2).multilineTextAlignment(.center)
                        }
                    }
                }
            }
            .frame(height: 140)

            HStack(spacing: 12) {
                ForEach(zeitpunktStats) { stat in
                    VStack(spacing: 2) {
                        Text("\(stat.anzahl)×")
                            .font(.caption2.bold()).foregroundStyle(.blue)
                        Text(stat.name)
                            .font(.system(size: 9)).foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: Ereignisse

    private var ereignisseKarte: some View {
        karte(
            titel: "Hypo- & Hyper-Ereignisse",
            symbol: "exclamationmark.triangle.fill",
            farbe: .red,
            info: "Hypoglykämie (Hypo): Wert unter 3,9 mmol/L — gefährlich, sofort Kohlenhydrate zuführen. Hyperglykämie (Hyper): Wert über 7,8 mmol/L — langfristig schädlich für Organe."
        ) {
            HStack(spacing: 0) {
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill").foregroundStyle(.red)
                        Text("Hypo (<3.9)").font(.subheadline.bold())
                    }
                    Text("\(hypos.count)").font(.title.bold()).foregroundStyle(.red)
                    Text("Ereignisse").font(.caption).foregroundStyle(.secondary)
                    if let min = hypos.map(\.wert).min() {
                        Text(String(format: "Min: %.1f", min))
                            .font(.caption2).foregroundStyle(.red.opacity(0.7))
                    }
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 80)

                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.circle.fill").foregroundStyle(.orange)
                        Text("Hyper (>7.8)").font(.subheadline.bold())
                    }
                    Text("\(hypers.count)").font(.title.bold()).foregroundStyle(.orange)
                    Text("Ereignisse").font(.caption).foregroundStyle(.secondary)
                    if let max = hypers.map(\.wert).max() {
                        Text(String(format: "Max: %.1f", max))
                            .font(.caption2).foregroundStyle(.orange.opacity(0.7))
                    }
                }
                .frame(maxWidth: .infinity)
            }

            if !ereignisseProWoche.isEmpty {
                Divider()
                Text("Wochenverlauf").font(.caption).foregroundStyle(.secondary)
                Chart(ereignisseProWoche) { p in
                    BarMark(
                        x: .value("Woche", p.woche, unit: .weekOfYear),
                        y: .value("Hypos", p.hypos)
                    )
                    .foregroundStyle(Color.red.opacity(0.75))
                    .cornerRadius(3)
                    BarMark(
                        x: .value("Woche", p.woche, unit: .weekOfYear),
                        y: .value("Hypers", p.hypers)
                    )
                    .foregroundStyle(Color.orange.opacity(0.75))
                    .cornerRadius(3)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                        AxisGridLine()
                    }
                }
                .frame(height: 100)
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.red.opacity(0.75)).frame(width: 12, height: 12)
                        Text("Hypos").font(.caption2).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.orange.opacity(0.75)).frame(width: 12, height: 12)
                        Text("Hypers").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: Tageszeit-Muster

    private var tageszeitKarte: some View {
        karte(
            titel: "Tageszeit-Muster",
            symbol: "clock.fill",
            info: "Durchschnittlicher Blutzucker je Tageszeit. Morgendlich hohe Werte können auf das Dawn-Phänomen hinweisen (Hormonausschüttung kurz vor dem Aufwachen erhöht die Glukose)."
        ) {
            Chart(tageszeitMuster) { punkt in
                BarMark(
                    x: .value("Zeit", punkt.label),
                    y: .value("Ø mmol/L", punkt.avg)
                )
                .foregroundStyle(wertFarbe(punkt.avg).gradient)
                .cornerRadius(4)
                .annotation(position: .top) {
                    Text(String(format: "%.1f", punkt.avg))
                        .font(.caption2.bold())
                        .foregroundStyle(wertFarbe(punkt.avg))
                }
            }
            .chartYScale(domain: 0...14)
            .frame(height: 130)

            HStack {
                Text("Messungen gesamt")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(tageszeitMuster.map(\.anzahl).reduce(0, +))")
                    .font(.caption.bold()).foregroundStyle(.blue)
            }
        }
    }

    // MARK: Insulin

    private var insulinKarte: some View {
        karte(
            titel: "Insulin-Überblick",
            symbol: "syringe.fill",
            info: "Aufschlüsselung deiner Insulin-Injektionen nach Typ. Kurzzeit-Insulin wirkt schnell bei Mahlzeiten, Langzeit-Insulin hält den Basalspiegel stabil."
        ) {
            HStack(spacing: 0) {
                statZelle("\(mitInsulin.count)", label: "Injektionen", farbe: .blue)
                Divider().frame(height: 44)
                let avgIE = mitInsulin.map(\.insulinEinheiten).reduce(0, +) / Double(mitInsulin.count)
                statZelle(String(format: "%.0f IE", avgIE), label: "Ø Einheiten", farbe: .blue)
                Divider().frame(height: 44)
                let gesamt = mitInsulin.map(\.insulinEinheiten).reduce(0, +)
                statZelle(String(format: "%.0f IE", gesamt), label: "Gesamt", farbe: .blue)
            }

            if !insulinStats.isEmpty {
                Divider()
                VStack(spacing: 10) {
                    ForEach(insulinStats) { stat in
                        HStack {
                            Image(systemName: "syringe.fill")
                                .font(.caption).foregroundStyle(.blue)
                                .frame(width: 16)
                            Text(stat.typ).font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(stat.anzahl)×")
                                .font(.caption).foregroundStyle(.secondary)
                            Text(String(format: "Ø %.0f IE", stat.avgEinheiten))
                                .font(.caption.bold()).foregroundStyle(.blue)
                        }
                        if stat.id != insulinStats.last?.id { Divider() }
                    }
                }
            }
        }
    }
}

// MARK: - Anpassen Sheet

struct DiabetesAnalyseAnpassenView: View {
    @Binding var sektionen: [DiabetesAnalyseSektion]
    @Environment(\.dismiss) private var dismiss
    @State private var editMode: EditMode = .active

    var body: some View {
        NavigationStack {
            List {
                ForEach(sektionen) { sektion in
                    HStack(spacing: 12) {
                        Image(systemName: sektion.symbol)
                            .foregroundStyle(.blue)
                            .frame(width: 24)
                        Text(sektion.rawValue)
                            .font(.subheadline)
                    }
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
