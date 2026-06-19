import SwiftUI
import SwiftData
import Charts

// MARK: - Sektionen

enum ZyklusAnalyseSektion: String, CaseIterable, Codable, Identifiable {
    case uebersicht          = "Übersicht"
    case vorhersage          = "Adaptive Vorhersage"
    case genauigkeit         = "Vorhersagegenauigkeit"
    case verlauf             = "Zyklusverlauf"
    case schleim             = "Zervixschleim"
    case symptome            = "Häufigste Symptome"
    case temperatur          = "Basaltemperatur"
    case ovulationstests     = "Ovulationstests"
    case schmerzKorrelation  = "Schmerz & Zyklus"
    case migraeneKorrelation = "Migräne & Zyklus"
    case kiInsicht           = "KI-Einblick"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .uebersicht:          return "drop.fill"
        case .vorhersage:          return "brain.head.profile"
        case .genauigkeit:         return "target"
        case .verlauf:             return "chart.line.uptrend.xyaxis"
        case .schleim:             return "drop.halffull"
        case .symptome:            return "list.bullet.clipboard.fill"
        case .temperatur:          return "thermometer.medium"
        case .ovulationstests:     return "circle.dotted"
        case .schmerzKorrelation:  return "cross.fill"
        case .migraeneKorrelation: return "brain"
        case .kiInsicht:           return "sparkles"
        }
    }
}

private let kZyklusSektionenKey = "zyklusAnalyseSektionen"

private func zyklusSektionenLaden() -> [ZyklusAnalyseSektion] {
    guard let data = UserDefaults.standard.data(forKey: kZyklusSektionenKey),
          let decoded = try? JSONDecoder().decode([ZyklusAnalyseSektion].self, from: data)
    else { return ZyklusAnalyseSektion.allCases }
    let existing = Set(decoded)
    let missing = ZyklusAnalyseSektion.allCases.filter { !existing.contains($0) }
    return decoded + missing
}

private func zyklusSektionenSpeichern(_ sektionen: [ZyklusAnalyseSektion]) {
    if let data = try? JSONEncoder().encode(sektionen) {
        UserDefaults.standard.set(data, forKey: kZyklusSektionenKey)
    }
}

// MARK: - View

struct ZyklusAnalyseView: View {
    @Query(sort: \ZyklusEintrag.datum, order: .forward) private var eintraege: [ZyklusEintrag]
    @Query(sort: \PainEntry.datum, order: .reverse) private var painEntries: [PainEntry]
    @Query(sort: \MigraeneEintrag.datum, order: .reverse) private var migraeneAnfaelle: [MigraeneEintrag]
    @Query(sort: \HAQEintrag.datum, order: .reverse) private var haqEintraege: [HAQEintrag]
    @Query(sort: \FACITEintrag.datum, order: .reverse) private var facitEintraege: [FACITEintrag]
    @Query(sort: \BlutzuckerEintrag.datum, order: .reverse) private var blutzuckerEintraege: [BlutzuckerEintrag]
    @Query(sort: \KortisonEintrag.datum, order: .reverse) private var kortisonEintraege: [KortisonEintrag]
    @Environment(\.dismiss) private var dismiss

    @State private var zeitraum: Zeitraum = .woche
    @State private var sektionen: [ZyklusAnalyseSektion] = zyklusSektionenLaden()
    @State private var zeigeAnpassen = false

    private var analyse: ZyklusAnalyse {
        ZyklusRechner.analyse(eintraege: Array(eintraege))
    }

    private var gefilterteEintraege: [ZyklusEintrag] {
        guard let tage = zeitraum.tage else { return Array(eintraege) }
        let cutoff = Calendar.current.date(byAdding: .day, value: -tage, to: Date()) ?? Date()
        return eintraege.filter { $0.datum >= cutoff }
    }

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

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if eintraege.isEmpty {
                    ContentUnavailableView(
                        "Keine Daten",
                        systemImage: "drop.circle",
                        description: Text("Erfasse zuerst Zyklusdaten.")
                    )
                } else {
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
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("Zyklus-Analyse")
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
                ZyklusAnalyseAnpassenView(sektionen: $sektionen)
            }
            .onChange(of: sektionen) { _, new in zyklusSektionenSpeichern(new) }
        }
    }

    // MARK: - Section Dispatcher

    @ViewBuilder
    private func sektionView(_ sektion: ZyklusAnalyseSektion) -> some View {
        switch sektion {
        case .uebersicht:          uebersichtKarte
        case .vorhersage:          vorhersageKarte
        case .genauigkeit:         genauigkeitsKarte
        case .verlauf:             zykluslaengenKarte
        case .schleim:             schleimKarte
        case .symptome:            symptomKarte
        case .temperatur:          temperaturKarte
        case .ovulationstests:     ovulationstestKarte
        case .schmerzKorrelation:  schmerzKorrelationKarte
        case .migraeneKorrelation: migraeneKorrelationKarte
        case .kiInsicht:           KIAnalyseKarte(prompt: kiPrompt, modulTint: .pink).id(zeitraum)
        }
    }

    // MARK: - Phasen-Aggregation (generisch)

    private func phasenAggregat<T>(
        _ items: [T],
        datum: KeyPath<T, Date>,
        wert: (T) -> Double?
    ) -> [(phase: ZyklusRechner.Zyklusphase, avg: Double, count: Int)] {
        var map: [ZyklusRechner.Zyklusphase: [Double]] = [:]
        for item in items {
            guard let phase = ZyklusRechner.phase(for: item[keyPath: datum], analyse: analyse),
                  let w = wert(item) else { continue }
            map[phase, default: []].append(w)
        }
        return ZyklusRechner.Zyklusphase.allCases.compactMap { phase in
            guard let werte = map[phase], !werte.isEmpty else { return nil }
            return (phase: phase, avg: werte.reduce(0, +) / Double(werte.count), count: werte.count)
        }
    }

    private func phasenAnzahl<T>(
        _ items: [T],
        datum: KeyPath<T, Date>,
        filter: (T) -> Bool = { _ in true }
    ) -> [(phase: ZyklusRechner.Zyklusphase, count: Int)] {
        var map: [ZyklusRechner.Zyklusphase: Int] = [:]
        for item in items where filter(item) {
            guard let phase = ZyklusRechner.phase(for: item[keyPath: datum], analyse: analyse) else { continue }
            map[phase, default: 0] += 1
        }
        return ZyklusRechner.Zyklusphase.allCases.compactMap { phase in
            guard let c = map[phase], c > 0 else { return nil }
            return (phase: phase, count: c)
        }
    }

    private func fmt(_ data: [(phase: ZyklusRechner.Zyklusphase, avg: Double, count: Int)],
                     _ format: String, _ unit: String) -> String {
        data.map { "\($0.phase.rawValue): Ø \(String(format: format, $0.avg))\(unit)" }
            .joined(separator: "; ")
    }

    // MARK: - KI Prompt

    private var kiPrompt: String {
        let zyklen = max(analyse.zyklusStarts.count - 1, 0)
        var zeilen: [String] = [
            "Zyklus-Analyse (\(zeitraum.rawValue)):",
            "- \(zyklen) vollständige Zyklen erfasst",
            "- Ø Zykluslänge: \(Int(analyse.zykluslaenge.rounded())) Tage, Variation: ±\(String(format: "%.1f", analyse.variation)) Tage",
            "- Ø Periodendauer: \(Int(analyse.periodendauer.rounded())) Tage",
            "",
            "Modul-Daten je Zyklusphase:"
        ]

        // Schmerz
        let sp = ZyklusRechner.schmerzJePhase(painEntries: Array(painEntries), analyse: analyse)
        if !sp.isEmpty {
            let s = sp.map { "\($0.phase.rawValue): Ø \(String(format: "%.1f", $0.avgSchmerz))/10 (\($0.anzahl)×)" }.joined(separator: "; ")
            zeilen.append("- Schmerzstärke: \(s)")
        }

        // Fatigue, Stimmung, Stress aus PainEntry
        let fatigue = phasenAggregat(Array(painEntries), datum: \.datum) { $0.fatigue > 0 ? Double($0.fatigue) : nil }
        if !fatigue.isEmpty { zeilen.append("- Erschöpfung (0–10): \(fmt(fatigue, "%.1f", ""))") }

        let stimmung = phasenAggregat(Array(painEntries), datum: \.datum) { $0.stimmung > 0 ? Double($0.stimmung) : nil }
        if !stimmung.isEmpty { zeilen.append("- Stimmung (1–5): \(fmt(stimmung, "%.1f", ""))") }

        let stress = phasenAggregat(Array(painEntries), datum: \.datum) { $0.stressLevel > 0 ? Double($0.stressLevel) : nil }
        if !stress.isEmpty { zeilen.append("- Stress (1–5): \(fmt(stress, "%.1f", ""))") }

        let schlaf = phasenAggregat(Array(painEntries), datum: \.datum) { $0.schlafStunden > 0 ? $0.schlafStunden : nil }
        if !schlaf.isEmpty { zeilen.append("- Schlaf: \(fmt(schlaf, "%.1f", " h"))") }

        // Morgensteifigkeit & Schübe (Rheuma)
        let steif = phasenAggregat(Array(painEntries), datum: \.datum) { $0.morgensteifigkeit > 0 ? Double($0.morgensteifigkeit) : nil }
        if !steif.isEmpty { zeilen.append("- Morgensteifigkeit: \(fmt(steif, "%.0f", " Min."))") }

        let schube = phasenAnzahl(Array(painEntries), datum: \.datum) { $0.istSchub }
        if !schube.isEmpty {
            let s = schube.map { "\($0.phase.rawValue): \($0.count)×" }.joined(separator: "; ")
            zeilen.append("- Rheumaschübe: \(s)")
        }

        // Haut-Verschlechterungen
        let hautFlares = phasenAnzahl(Array(painEntries), datum: \.datum) { $0.istHautEintrag && $0.verlauf == "schlechter" }
        if !hautFlares.isEmpty {
            let s = hautFlares.map { "\($0.phase.rawValue): \($0.count)×" }.joined(separator: "; ")
            zeilen.append("- Hautflares: \(s)")
        }

        // Migräne
        let mp = ZyklusRechner.migraeneJePhase(anfaelle: Array(migraeneAnfaelle), analyse: analyse).filter { $0.anzahl > 0 }
        if !mp.isEmpty {
            let s = mp.map { "\($0.phase.rawValue): \($0.anzahl) Anfälle (Ø \(String(format: "%.1f", $0.avgStaerke))/10)" }.joined(separator: "; ")
            zeilen.append("- Migräne: \(s)")
        }

        // HAQ (Gelenkfunktion)
        let haq = phasenAggregat(Array(haqEintraege), datum: \.datum) { $0.haqScore }
        if !haq.isEmpty { zeilen.append("- Gelenkfunktion HAQ (0=gut, 3=schlecht): \(fmt(haq, "%.2f", "/3"))") }

        // FACIT (Erschöpfung klinisch)
        let facit = phasenAggregat(Array(facitEintraege), datum: \.datum) { Double($0.facitScore) }
        if !facit.isEmpty { zeilen.append("- FACIT-Fatigue (0=erschöpft, 52=fit): \(fmt(facit, "%.0f", "/52"))") }

        // Blutzucker
        let bz = phasenAggregat(Array(blutzuckerEintraege), datum: \.datum) { $0.wert }
        if !bz.isEmpty { zeilen.append("- Blutzucker: \(fmt(bz, "%.1f", " mmol/L"))") }

        // Kortison
        let krt = phasenAggregat(Array(kortisonEintraege), datum: \.datum) { $0.dosierungMg }
        if !krt.isEmpty {
            let s = krt.map { "\($0.phase.rawValue): Ø \(String(format: "%.1f", $0.avg)) mg (\($0.count)×)" }.joined(separator: "; ")
            zeilen.append("- Kortison: \(s)")
        }

        zeilen.append("")
        zeilen.append("Analysiere hormonelle Einflüsse auf alle erfassten Bereiche. Identifiziere in welchen Zyklusphasen sich Symptome häufen oder verbessern. Gib 3–5 kurze, konkrete Einblicke auf Deutsch. Keine Diagnosen.")

        return zeilen.joined(separator: "\n")
    }

    // MARK: - Übersicht

    private var uebersichtKarte: some View {
        karte(titel: "Übersicht", symbol: "drop.fill", farbe: .pink) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                statCell("Ø Zykluslänge", String(format: "%.0f Tage", analyse.zykluslaenge), .pink)
                statCell("Ø Periode", String(format: "%.0f Tage", analyse.periodendauer), .red)
                statCell("Variation", String(format: "±%.1f Tage", analyse.variation), .orange)
                statCell("Zyklen erfasst", "\(max(analyse.zyklusStarts.count - 1, 0))", .purple)
            }
        }
    }

    // MARK: - Adaptive Vorhersage

    @ViewBuilder
    private var vorhersageKarte: some View {
        let adaptZyklus  = Int(round(analyse.adaptierteZykluslaenge))
        let adaptPeriod  = Int(round(analyse.adaptiertePeriodendauer))
        let avgZyklus    = Int(round(analyse.zykluslaenge))
        let avgPeriod    = Int(round(analyse.periodendauer))
        let zyklusDiff   = adaptZyklus - avgZyklus
        let periodDiff   = adaptPeriod - avgPeriod
        let ovOffset     = analyse.gelernterOvulationsOffset
        let ovDiff       = ovOffset.map { $0 - (avgZyklus - 14) }
        let hatLerndaten = analyse.zyklusStarts.count >= 3

        karte(titel: "Adaptive Vorhersage", symbol: "brain.head.profile", farbe: .pink,
              info: "Die App gewichtet die letzten 3 Zyklen stärker als ältere (50 % / 30 % / 20 %). So werden aktuelle Veränderungen deines Rhythmus schneller erkannt als bei einem einfachen Durchschnitt.") {
            HStack {
                if hatLerndaten {
                    Label("Aktiv", systemImage: "checkmark.circle.fill")
                        .font(.caption).foregroundStyle(.teal)
                } else {
                    Text("Ab 3 Zyklen aktiv").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 0) {
                vorhersageZelle("\(adaptZyklus) Tage", "Vorhersage Zyklus",
                                zyklusDiff != 0 ? .pink : .primary, diff: zyklusDiff)
                Divider().frame(height: 44)
                vorhersageZelle("\(adaptPeriod) Tage", "Vorhersage Periode",
                                periodDiff != 0 ? .red : .primary, diff: periodDiff)
                if let offset = ovOffset, let diff = ovDiff {
                    Divider().frame(height: 44)
                    vorhersageZelle("Tag \(offset)", "Eisprung (gelernt)", .teal, diff: diff)
                }
            }

            Text("Letzte 3 Zyklen gewichtet (50/30/20 %). Ø-Werte bleiben für Statistik unverändert.")
                .font(.caption2).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Vorhersagegenauigkeit

    @ViewBuilder
    private var genauigkeitsKarte: some View {
        let fehler         = vorhersageFehler()
        let absWerte       = fehler.map { abs($0.fehler) }
        let suffixWerte    = Array(absWerte.suffix(3))
        let prefixCount    = max(absWerte.count - 3, 1)
        let prefixWerte    = Array(absWerte.prefix(prefixCount))
        let aktuellFehler  = suffixWerte.isEmpty ? 0.0 : suffixWerte.reduce(0, +) / Double(suffixWerte.count)
        let fruehFehler    = prefixWerte.isEmpty ? 0.0 : prefixWerte.reduce(0, +) / Double(prefixWerte.count)
        let verbessert     = aktuellFehler < fruehFehler - 0.3
        let verschlechtert = aktuellFehler > fruehFehler + 0.3
        let chartHoehe     = max(CGFloat(fehler.count) * 18.0, 100.0)

        if fehler.count >= 2 {
            karte(titel: "Vorhersagegenauigkeit", symbol: "target", farbe: .pink,
                  info: "Differenz in Tagen zwischen vorhergesagtem und tatsächlichem Periodenbeginn. 0 = perfekte Vorhersage. Orange = zu spät vorhergesagt, Blau = zu früh.") {
                HStack(alignment: .firstTextBaseline) {
                    Text("Abweichung: Vorhersage vs. tatsächlicher Start")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("±\(String(format: "%.1f", aktuellFehler)) Tage")
                            .font(.subheadline.bold())
                            .foregroundStyle(aktuellFehler <= 1 ? .green : aktuellFehler <= 2 ? .orange : .red)
                        HStack(spacing: 3) {
                            Image(systemName: verbessert ? "arrow.down.circle.fill" :
                                              verschlechtert ? "arrow.up.circle.fill" : "minus.circle.fill")
                                .foregroundStyle(verbessert ? .green : verschlechtert ? .red : .secondary)
                                .font(.caption2)
                            Text(verbessert ? "Wird besser" : verschlechtert ? "Schwankend" : "Stabil")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }

                Chart(fehler, id: \.zyklusNr) { p in
                    BarMark(x: .value("Zyklus", p.zyklusNr), y: .value("Tage", p.fehler))
                        .foregroundStyle(p.fehler >= 0 ? Color.orange.gradient : Color.blue.gradient)
                        .cornerRadius(3)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { v in
                        AxisValueLabel { Text("Z\(v.as(Int.self) ?? 0)") }
                    }
                }
                .frame(height: chartHoehe)

                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.orange).frame(width: 10, height: 8)
                        Text("Zu spät").font(.caption2).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.blue).frame(width: 10, height: 8)
                        Text("Zu früh").font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("0 = perfekt").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Zyklusverlauf

    @ViewBuilder
    private var zykluslaengenKarte: some View {
        let laengen = berechneLaengen()
        let minDom  = max((laengen.min() ?? 20) - 3, 0)
        let maxDom  = (laengen.max() ?? 35) + 3

        if laengen.count >= 2 {
            karte(titel: "Zyklusverlauf", symbol: "chart.line.uptrend.xyaxis", farbe: .pink) {
                Text("Verlauf der letzten Zyklen").font(.caption).foregroundStyle(.secondary)
                Chart {
                    ForEach(Array(laengen.enumerated()), id: \.offset) { i, laenge in
                        LineMark(x: .value("Zyklus", i + 1), y: .value("Tage", laenge))
                            .foregroundStyle(Color.pink.gradient)
                            .interpolationMethod(.catmullRom)
                        PointMark(x: .value("Zyklus", i + 1), y: .value("Tage", laenge))
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
                .chartYScale(domain: minDom...maxDom)
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisValueLabel { Text("Z\(value.as(Int.self) ?? 0)") }
                    }
                }
                .frame(height: 160)
            }
        }
    }

    // MARK: - Zervixschleim

    @ViewBuilder
    private var schleimKarte: some View {
        let verteilung   = schleimVerteilung()
        let maxAnzahl    = Double(verteilung.map(\.anzahl).max() ?? 1)
        let hatFruchtbar = verteilung.contains { ["wässrig", "eiweiss"].contains($0.typ.lowercased()) }

        if !verteilung.isEmpty {
            karte(titel: "Zervixschleim", symbol: "drop.halffull", farbe: .pink,
                  info: "Wässrig & Eiweiss werden als fruchtbar gewertet (Symptothermalmethode). Beeinflusst die Eisprungvorhersage der App direkt.") {
                Text("Häufigkeit der erfassten Typen").font(.caption).foregroundStyle(.secondary)
                VStack(spacing: 8) {
                    ForEach(verteilung) { item in
                        HStack(spacing: 10) {
                            Circle().fill(schleimFarbe(item.typ)).frame(width: 8, height: 8)
                            Text(item.typ.capitalized)
                                .font(.subheadline).frame(width: 72, alignment: .leading)
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(schleimFarbe(item.typ).opacity(0.3))
                                    .frame(
                                        width: geo.size.width * CGFloat(item.anzahl) / CGFloat(maxAnzahl),
                                        height: 10
                                    )
                                    .frame(maxHeight: .infinity, alignment: .center)
                            }
                            Text("\(item.anzahl)×").font(.caption.bold()).foregroundStyle(.secondary)
                        }
                        .frame(height: 20)
                    }
                }
                if hatFruchtbar {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "info.circle").font(.caption2).foregroundStyle(.secondary)
                        Text("Wässrig & Eiweiss gelten als fruchtbar (Symptothermalmethode).")
                            .font(.caption2).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: - Symptome

    @ViewBuilder
    private var symptomKarte: some View {
        let symptome   = topSymptome()
        let chartHoehe = CGFloat(min(symptome.count, 8)) * 30.0 + 20.0

        if !symptome.isEmpty {
            karte(titel: "Häufigste Symptome", symbol: "list.bullet.clipboard.fill", farbe: .pink) {
                Chart(symptome.prefix(8)) { s in
                    BarMark(x: .value("Anzahl", s.anzahl), y: .value("Symptom", s.name))
                        .foregroundStyle(Color.pink.gradient)
                        .cornerRadius(4)
                        .annotation(position: .trailing) {
                            Text("\(s.anzahl)").font(.caption2).foregroundStyle(.secondary)
                        }
                }
                .frame(height: chartHoehe)
            }
        }
    }

    // MARK: - Basaltemperatur

    @ViewBuilder
    private var temperaturKarte: some View {
        let tempDaten = basaltemperaturDaten()
        let minTemp   = (tempDaten.map(\.temp).min() ?? 36.0) - 0.15
        let maxTemp   = (tempDaten.map(\.temp).max() ?? 37.0) + 0.15

        if tempDaten.count >= 3 {
            karte(titel: "Basaltemperatur", symbol: "thermometer.medium", farbe: .pink,
                  info: "Morgentemperatur direkt nach dem Aufwachen, vor jeder Aktivität. Nach dem Eisprung steigt sie um ca. 0,2–0,5 °C an und bleibt bis zur nächsten Periode erhöht.") {
                Chart(tempDaten, id: \.datum) { punkt in
                    LineMark(x: .value("Tag", punkt.datum, unit: .day), y: .value("°C", punkt.temp))
                        .foregroundStyle(Color.orange.gradient)
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("Tag", punkt.datum, unit: .day), y: .value("°C", punkt.temp))
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

    // MARK: - Ovulationstest

    @ViewBuilder
    private var ovulationstestKarte: some View {
        let tests = ovulationstests()

        if !tests.isEmpty {
            karte(titel: "Ovulationstests", symbol: "circle.dotted", farbe: .pink) {
                VStack(spacing: 8) {
                    ForEach(Array(tests.suffix(10).enumerated()), id: \.offset) { _, test in
                        HStack(spacing: 12) {
                            Circle().fill(ovuFarbe(test.ergebnis)).frame(width: 12, height: 12)
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

    // MARK: - Schmerz & Zyklus

    @ViewBuilder
    private var schmerzKorrelationKarte: some View {
        let daten  = ZyklusRechner.schmerzJePhase(painEntries: Array(painEntries), analyse: analyse)
        let gesamt = daten.map(\.anzahl).reduce(0, +)

        if !painEntries.isEmpty && !analyse.zyklusStarts.isEmpty && !daten.isEmpty {
            karte(titel: "Schmerz & Zyklus", symbol: "cross.fill", farbe: .red) {
                Text("Ø Schmerzstärke je Zyklusphase").font(.caption).foregroundStyle(.secondary)
                Chart(daten, id: \.phase.rawValue) { d in
                    BarMark(x: .value("Phase", d.phase.rawValue), y: .value("Schmerz", d.avgSchmerz))
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
                    Text("Gesamt: \(gesamt)").font(.caption2).foregroundStyle(.secondary)
                }

                VStack(spacing: 4) {
                    ForEach(daten, id: \.phase.rawValue) { d in
                        HStack {
                            Circle().fill(phaseFarbe(d.phase)).frame(width: 8, height: 8)
                            Text(d.phase.rawValue).font(.caption)
                            Spacer()
                            Text("\(d.anzahl) Einträge").font(.caption2).foregroundStyle(.secondary)
                            Text(String(format: "Ø %.1f", d.avgSchmerz)).font(.caption.bold())
                        }
                    }
                }
            }
        }
    }

    // MARK: - Migräne & Zyklus

    @ViewBuilder
    private var migraeneKorrelationKarte: some View {
        let daten     = ZyklusRechner.migraeneJePhase(anfaelle: Array(migraeneAnfaelle), analyse: analyse)
        let maxAnzahl = (daten.map(\.anzahl).max() ?? 4) + 1

        if !migraeneAnfaelle.isEmpty && !analyse.zyklusStarts.isEmpty && !daten.isEmpty {
            karte(titel: "Migräne & Zyklus", symbol: "brain", farbe: .purple) {
                Text("Anfälle je Zyklusphase").font(.caption).foregroundStyle(.secondary)
                Chart(daten, id: \.phase.rawValue) { d in
                    BarMark(x: .value("Phase", d.phase.rawValue), y: .value("Anfälle", d.anzahl))
                        .foregroundStyle(phaseFarbe(d.phase).gradient)
                        .cornerRadius(6)
                        .annotation(position: .top) {
                            Text("\(d.anzahl)").font(.caption2).foregroundStyle(.secondary)
                        }
                }
                .chartYScale(domain: 0...maxAnzahl)
                .frame(height: 150)

                VStack(spacing: 4) {
                    ForEach(daten, id: \.phase.rawValue) { d in
                        HStack {
                            Circle().fill(phaseFarbe(d.phase)).frame(width: 8, height: 8)
                            Text(d.phase.rawValue).font(.caption)
                            Spacer()
                            Text("\(d.anzahl) Anfälle").font(.caption2).foregroundStyle(.secondary)
                            Text(String(format: "Ø %.1f", d.avgStaerke)).font(.caption.bold())
                        }
                    }
                }
            }
        }
    }

    // MARK: - Phase Colors

    private func phaseFarbe(_ p: ZyklusRechner.Zyklusphase) -> Color {
        switch p {
        case .menstruation:  return .red
        case .follikelphase: return .yellow
        case .ovulation:     return .orange
        case .lutealphase:   return .purple
        }
    }

    // MARK: - Data Helpers

    private struct FehlerPunkt {
        let zyklusNr: Int
        let fehler: Double
    }

    private func vorhersageFehler() -> [FehlerPunkt] {
        let laengen = berechneLaengen()
        guard laengen.count >= 2 else { return [] }
        return (1..<laengen.count).map { i in
            let vorherige = Array(laengen[0..<i])
            return FehlerPunkt(zyklusNr: i + 1, fehler: laengen[i] - rollingAdaptiv(vorherige))
        }
    }

    private func rollingAdaptiv(_ laengen: [Double]) -> Double {
        let r = Array(laengen.suffix(3))
        switch r.count {
        case 0:    return 28.0
        case 1:    return r[0]
        case 2:    return r[0] * 0.4 + r[1] * 0.6
        default:   return r[0] * 0.2 + r[1] * 0.3 + r[2] * 0.5
        }
    }

    private func berechneLaengen() -> [Double] {
        let kal    = Calendar.current
        let starts = analyse.zyklusStarts
        guard starts.count >= 2 else { return [] }
        return (1..<starts.count).map { i in
            Double(kal.dateComponents([.day], from: starts[i - 1], to: starts[i]).day ?? 28)
        }
    }

    private struct SchleimItem: Identifiable {
        let typ: String
        let anzahl: Int
        var id: String { typ }
    }

    private func schleimVerteilung() -> [SchleimItem] {
        var zähler: [String: Int] = [:]
        for e in gefilterteEintraege where !e.zervixschleim.isEmpty {
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
        case "cremig":  return .orange
        case "wässrig": return .blue
        case "eiweiss": return .teal
        default:        return .secondary
        }
    }

    private struct SymptomItem: Identifiable {
        let name: String
        let anzahl: Int
        var id: String { name }
    }

    private func topSymptome() -> [SymptomItem] {
        var zähler: [String: Int] = [:]
        for e in gefilterteEintraege {
            for s in e.symptome.components(separatedBy: ", ") where !s.isEmpty {
                zähler[s, default: 0] += 1
            }
        }
        return zähler.map { SymptomItem(name: $0.key, anzahl: $0.value) }
                     .sorted { $0.anzahl > $1.anzahl }
    }

    private struct TempPunkt {
        let datum: Date
        let temp: Double
    }

    private func basaltemperaturDaten() -> [TempPunkt] {
        let kal = Calendar.current
        return gefilterteEintraege
            .filter { $0.basaltemperatur > 0 }
            .map { TempPunkt(datum: kal.startOfDay(for: $0.datum), temp: $0.basaltemperatur) }
            .sorted { $0.datum < $1.datum }
    }

    private struct OvuTest {
        let datum: Date
        let ergebnis: String
    }

    private func ovulationstests() -> [OvuTest] {
        gefilterteEintraege.filter { !$0.ovulationstest.isEmpty }
                            .map { OvuTest(datum: $0.datum, ergebnis: $0.ovulationstest) }
                            .sorted { $0.datum < $1.datum }
    }

    private func ovuFarbe(_ ergebnis: String) -> Color {
        switch ergebnis {
        case "positiv": return .orange
        case "negativ": return .gray.opacity(0.4)
        default:        return .yellow.opacity(0.7)
        }
    }

    // MARK: - View Helpers

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

    private func statCell(_ titel: String, _ wert: String, _ farbe: Color) -> some View {
        VStack(spacing: 4) {
            Text(wert).font(.title3.bold()).foregroundStyle(farbe)
            Text(titel).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func vorhersageZelle(_ wert: String, _ label: String, _ farbe: Color, diff: Int) -> some View {
        VStack(spacing: 4) {
            Text(wert).font(.subheadline.bold()).foregroundStyle(farbe)
            Text(label).font(.caption2).foregroundStyle(.secondary)
            if diff != 0 {
                Text(diff > 0 ? "+\(diff)d" : "\(diff)d")
                    .font(.caption2.bold())
                    .foregroundStyle(diff > 0 ? .orange : .blue)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Reihenfolge anpassen

private struct ZyklusAnalyseAnpassenView: View {
    @Binding var sektionen: [ZyklusAnalyseSektion]
    @Environment(\.dismiss) private var dismiss
    @State private var editMode: EditMode = .active

    var body: some View {
        NavigationStack {
            List {
                ForEach(sektionen) { sektion in
                    HStack(spacing: 12) {
                        Image(systemName: sektion.symbol)
                            .foregroundStyle(.pink)
                            .frame(width: 24)
                        Text(sektion.rawValue)
                            .font(.subheadline)
                    }
                }
                .onMove { from, to in
                    sektionen.move(fromOffsets: from, toOffset: to)
                    zyklusSektionenSpeichern(sektionen)
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
