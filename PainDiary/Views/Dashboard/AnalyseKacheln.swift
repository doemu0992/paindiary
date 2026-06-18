import SwiftUI
import Charts

// MARK: - Kachel-Container (gemeinsames Layout für alle Analyse-Kacheln)

struct KachelContainer<Content: View>: View {
    let titel: String
    let symbol: String
    let farbe: Color
    let infoText: String
    @ViewBuilder let inhalt: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(titel, systemImage: symbol)
                    .font(.headline).foregroundStyle(farbe)
                InfoButton(titel: titel, text: infoText)
                Spacer()
            }
            Divider()
            inhalt()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }
}

// MARK: - Wetter & Schmerz

struct WetterSchmerzKachel: View {
    let eintraege: [PainEntry]

    private struct Balken: Identifiable {
        var id: String { beschreibung }
        let beschreibung: String
        let avg: Double
        let anzahl: Int
    }

    private var daten: [Balken] {
        let valid = eintraege.filter { !$0.istHautEintrag && $0.wetterCode != nil }
        return Dictionary(grouping: valid) { WetterSnapshot.beschreibungFuerCode($0.wetterCode!) }
            .compactMap { beschreibung, gruppe -> Balken? in
                guard gruppe.count >= 2 else { return nil }
                let avg = Double(gruppe.map(\.schmerzstaerke).reduce(0, +)) / Double(gruppe.count)
                return Balken(beschreibung: beschreibung, avg: avg, anzahl: gruppe.count)
            }
            .sorted { $0.avg > $1.avg }
            .prefix(5).map { $0 }
    }

    var body: some View {
        KachelContainer(titel: "Wetter & Schmerz", symbol: "cloud.sun.fill", farbe: .cyan,
            infoText: "Ø Schmerzstärke pro Wetterlage. Zeigt nur Wetterlagen mit mind. 2 Einträgen.") {
            if daten.isEmpty {
                leer("Noch nicht genug Wetterdaten (mind. 2 Einträge pro Wetterlage).")
            } else {
                Chart(daten) { p in
                    BarMark(x: .value("Ø Schmerz", p.avg), y: .value("Wetter", p.beschreibung))
                        .foregroundStyle(SchmerzBadge.farbe(fuer: Int(p.avg.rounded())).gradient)
                        .cornerRadius(4)
                    .annotation(position: .trailing) {
                        Text(String(format: "%.1f", p.avg))
                            .font(.caption2.bold()).foregroundStyle(.secondary)
                    }
                }
                .chartXScale(domain: 0...10)
                .chartXAxis { AxisMarks(values: [0, 5, 10]) }
                .frame(height: CGFloat(daten.count) * 36 + 16)
            }
        }
    }
}

// MARK: - Stress & Schmerz

struct StressSchmerzKachel: View {
    let eintraege: [PainEntry]

    private struct Balken: Identifiable {
        var id: Int { level }
        let level: Int; let label: String; let avg: Double; let anzahl: Int
    }

    private var daten: [Balken] {
        let labels = ["", "Entspannt", "Leicht", "Mässig", "Hoch", "Extrem"]
        return (1...5).compactMap { level in
            let g = eintraege.filter { $0.stressLevel == level && !$0.istHautEintrag }
            guard !g.isEmpty else { return nil }
            return Balken(level: level, label: labels[level],
                          avg: Double(g.map(\.schmerzstaerke).reduce(0, +)) / Double(g.count),
                          anzahl: g.count)
        }
    }

    var body: some View {
        KachelContainer(titel: "Stress & Schmerz", symbol: "bolt.fill", farbe: .yellow,
            infoText: "Zeigt ob höherer Stress mit stärkerem Schmerz zusammenhängt.") {
            if daten.isEmpty {
                leer("Noch nicht genug Stressdaten.")
            } else {
                Chart(daten) { p in
                    BarMark(x: .value("Stress", p.label), y: .value("Ø Schmerz", p.avg))
                        .foregroundStyle(SchmerzBadge.farbe(fuer: Int(p.avg.rounded())).gradient)
                        .cornerRadius(4)
                }
                .chartYScale(domain: 0...10)
                .frame(height: 110)
            }
        }
    }
}

// MARK: - Schlaf & Schmerz

struct SchlafSchmerzKachel: View {
    let eintraege: [PainEntry]

    private struct Punkt: Identifiable {
        let id = UUID()
        let stunden: Double; let schmerz: Int
    }

    private var punkte: [Punkt] {
        eintraege.filter { $0.schlafStunden > 0 && !$0.istHautEintrag }
            .map { Punkt(stunden: $0.schlafStunden, schmerz: $0.schmerzstaerke) }
    }

    var body: some View {
        KachelContainer(titel: "Schlaf & Schmerz", symbol: "moon.zzz.fill", farbe: .purple,
            infoText: "Scatter-Plot: Schlafdauer vs. Schmerzstärke. Punkte links oben = wenig Schlaf, viel Schmerz.") {
            if punkte.isEmpty {
                leer("Noch nicht genug Schlafdaten.")
            } else {
                Chart(punkte) { p in
                    PointMark(x: .value("Schlaf (h)", p.stunden), y: .value("Schmerz", p.schmerz))
                        .foregroundStyle(SchmerzBadge.farbe(fuer: p.schmerz).opacity(0.7))
                        .symbolSize(55)
                }
                .chartYScale(domain: 0...10)
                .chartXAxisLabel("Schlaf (Stunden)")
                .frame(height: 120)
            }
        }
    }
}

// MARK: - Tageszeit-Verteilung

struct TageszeitKachel: View {
    let eintraege: [PainEntry]

    private struct Sektor: Identifiable {
        let id: String; let avg: Double; let anzahl: Int
    }

    private var daten: [Sektor] {
        let valid = eintraege.filter { !$0.istHautEintrag }
        let slots: [(String, ClosedRange<Int>)] = [
            ("Nacht 0–5",      0...5),
            ("Morgen 6–11",    6...11),
            ("Nachmittag 12–17", 12...17),
            ("Abend 18–23",    18...23),
        ]
        return slots.compactMap { name, range in
            let g = valid.filter { range.contains(Calendar.current.component(.hour, from: $0.datum)) }
            guard !g.isEmpty else { return nil }
            return Sektor(id: name,
                          avg: Double(g.map(\.schmerzstaerke).reduce(0, +)) / Double(g.count),
                          anzahl: g.count)
        }
    }

    var body: some View {
        KachelContainer(titel: "Tageszeit-Verteilung", symbol: "clock.fill", farbe: .orange,
            infoText: "Wann du am häufigsten Schmerzen erfasst und wie stark sie im Durchschnitt sind.") {
            if daten.isEmpty {
                leer("Noch nicht genug Daten.")
            } else {
                Chart(daten) { s in
                    SectorMark(angle: .value("Einträge", s.anzahl), innerRadius: .ratio(0.5), angularInset: 2)
                        .foregroundStyle(by: .value("Tageszeit", s.id))
                        .cornerRadius(4)
                        .annotation(position: .overlay) {
                            Text(String(format: "%.1f", s.avg))
                                .font(.caption2.bold()).foregroundStyle(.white)
                        }
                }
                .chartLegend(position: .bottom, spacing: 4)
                .frame(height: 160)
            }
        }
    }
}

// MARK: - Häufige Körperstellen

struct KoerperstellenKachel: View {
    let eintraege: [PainEntry]

    private struct Balken: Identifiable {
        var id: String { ort }
        let ort: String; let anzahl: Int; let avg: Double
    }

    private var daten: [Balken] {
        let valid = eintraege.filter { !$0.istHautEintrag && !$0.koerperstelle.isEmpty }
        let alle = valid.flatMap { $0.koerperstelle.components(separatedBy: ", ").filter { !$0.isEmpty } }
        return Dictionary(grouping: alle, by: { $0 })
            .map { ort, list -> Balken in
                let entries = valid.filter { $0.koerperstelle.contains(ort) }
                let avg = entries.isEmpty ? 0.0 : Double(entries.map(\.schmerzstaerke).reduce(0, +)) / Double(entries.count)
                return Balken(ort: ort, anzahl: list.count, avg: avg)
            }
            .sorted { $0.anzahl > $1.anzahl }
            .prefix(6).map { $0 }
    }

    var body: some View {
        KachelContainer(titel: "Häufige Körperstellen", symbol: "figure.stand", farbe: .teal,
            infoText: "Top 6 Körperstellen nach Häufigkeit, Farbe zeigt den Ø Schmerz.") {
            if daten.isEmpty {
                leer("Noch nicht genug Daten.")
            } else {
                Chart(daten) { p in
                    BarMark(x: .value("Anzahl", p.anzahl), y: .value("Ort", p.ort))
                        .foregroundStyle(SchmerzBadge.farbe(fuer: Int(p.avg.rounded())).gradient)
                        .cornerRadius(4)
                }
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
                .frame(height: CGFloat(daten.count) * 32 + 16)
            }
        }
    }
}

// MARK: - Häufige Schmerzarten

struct SchmerzartenKachel: View {
    let eintraege: [PainEntry]

    private struct Balken: Identifiable {
        var id: String { art }
        let art: String; let anzahl: Int
    }

    private var daten: [Balken] {
        let valid = eintraege.filter { !$0.istHautEintrag && !$0.schmerzart.isEmpty }
        return Dictionary(grouping: valid.map(\.schmerzart), by: { $0 })
            .map { Balken(art: $0.key, anzahl: $0.value.count) }
            .sorted { $0.anzahl > $1.anzahl }
            .prefix(6).map { $0 }
    }

    var body: some View {
        KachelContainer(titel: "Häufige Schmerzarten", symbol: "waveform", farbe: .blue,
            infoText: "Welche Schmerzarten du am häufigsten erlebst.") {
            if daten.isEmpty {
                leer("Noch nicht genug Daten.")
            } else {
                Chart(daten) { p in
                    BarMark(x: .value("Anzahl", p.anzahl), y: .value("Art", p.art))
                        .foregroundStyle(Color.blue.gradient)
                        .cornerRadius(4)
                }
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
                .frame(height: CGFloat(daten.count) * 32 + 16)
            }
        }
    }
}

// MARK: - Stimmungs-Trend

struct StimmungsTrendKachel: View {
    let eintraege: [PainEntry]

    private struct Punkt: Identifiable {
        var id: Date { datum }
        let datum: Date; let stimmung: Double
    }

    private var tagesDaten: [Punkt] {
        let kal = Calendar.current; let heute = kal.startOfDay(for: .now)
        guard let start = kal.date(byAdding: .day, value: -29, to: heute) else { return [] }
        var tag = start; var result: [Punkt] = []
        while tag <= heute {
            let g = eintraege.filter { kal.isDate($0.datum, inSameDayAs: tag) && $0.stimmung > 0 && !$0.istHautEintrag }
            if !g.isEmpty {
                result.append(Punkt(datum: tag, stimmung: Double(g.map(\.stimmung).reduce(0, +)) / Double(g.count)))
            }
            tag = kal.date(byAdding: .day, value: 1, to: tag) ?? tag
        }
        return result
    }

    var body: some View {
        KachelContainer(titel: "Stimmungs-Trend", symbol: "heart.fill", farbe: .pink,
            infoText: "Ø Stimmung pro Tag der letzten 30 Tage (1 = Schlecht, 5 = Super).") {
            if tagesDaten.isEmpty {
                leer("Noch nicht genug Stimmungsdaten.")
            } else {
                Chart(tagesDaten) { p in
                    LineMark(x: .value("Tag", p.datum, unit: .day), y: .value("Stimmung", p.stimmung))
                        .foregroundStyle(Color.pink.gradient).interpolationMethod(.catmullRom)
                    AreaMark(x: .value("Tag", p.datum, unit: .day), y: .value("Stimmung", p.stimmung))
                        .foregroundStyle(Color.pink.opacity(0.15).gradient).interpolationMethod(.catmullRom)
                }
                .chartYScale(domain: 1...5)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) {
                        AxisValueLabel(format: .dateTime.day().month(.twoDigits))
                    }
                }
                .frame(height: 100)
            }
        }
    }
}

// MARK: - MIDAS-Kachel

struct MidasKachel: View {
    let bewertungen: [MIDASBewertung]

    var body: some View {
        KachelContainer(titel: "MIDAS-Score", symbol: "brain.head.profile", farbe: .purple,
            infoText: "MIDAS = Migraine Disability Assessment. Misst die Beeinträchtigung durch Kopfschmerzen.\nGrad I (0–5): Minimal · II (6–10): Leicht · III (11–20): Mässig · IV (≥21): Schwer") {
            if let latest = bewertungen.first {
                HStack(spacing: 20) {
                    ZStack {
                        Circle().fill(midasFarbe(latest.score).opacity(0.15)).frame(width: 64, height: 64)
                        Text("\(latest.score)").font(.title.bold()).foregroundStyle(midasFarbe(latest.score))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(latest.gradText).font(.subheadline.bold()).foregroundStyle(midasFarbe(latest.score))
                        Text(latest.datum, style: .date).font(.caption).foregroundStyle(.secondary)
                        if bewertungen.count > 1 {
                            let diff = latest.score - bewertungen[1].score
                            HStack(spacing: 4) {
                                Image(systemName: diff > 0 ? "arrow.up" : diff < 0 ? "arrow.down" : "minus")
                                Text(diff == 0 ? "Unverändert" : "\(abs(diff)) vs. vorher")
                            }
                            .font(.caption2)
                            .foregroundStyle(diff > 0 ? .red : diff < 0 ? .green : .secondary)
                        }
                    }
                    Spacer()
                    NavigationLink(destination: MIDASView()) {
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "brain.head.profile").font(.system(size: 32)).foregroundStyle(.secondary)
                    Text("Noch kein MIDAS-Score erfasst.").font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 60)
            }
        }
    }

    private func midasFarbe(_ score: Int) -> Color {
        switch score { case 0...5: .green; case 6...10: .yellow; case 11...20: .orange; default: .red }
    }
}

// MARK: - Konfigurierte Korrelation

struct KonfigKorrelationsKachel: View {
    let kachel: KachelKonfiguration
    let eintraege: [PainEntry]
    let einnahmeLogs: [EinnahmeLog]

    private var xVariable: String { kachel.xVariable }
    private var yVariable: String { kachel.yVariable }
    private var anzeigeTitel: String { kachel.anzeigeTitel.isEmpty ? "Korrelation" : kachel.anzeigeTitel }

    private var infoText: String {
        var teile = ["Benutzerdefinierte Korrelation: \(xLabel) → \(yLabel)."]
        if !kachel.filterRegionen.isEmpty { teile.append("Region: \(kachel.filterRegionen.joined(separator: ", ")).") }
        if !kachel.filterSchmerzarten.isEmpty { teile.append("Art: \(kachel.filterSchmerzarten.joined(separator: ", ")).") }
        if !kachel.filterMedikament.isEmpty { teile.append("Medikament: \(kachel.filterMedikament).") }
        if kachel.filterZeitraum > 0 { teile.append("Zeitraum: letzte \(kachel.filterZeitraum) Tage.") }
        if kachel.filterMinStaerke > 0 { teile.append("Nur Einträge ≥ \(kachel.filterMinStaerke).") }
        return teile.joined(separator: " ")
    }

    var body: some View {
        KachelContainer(titel: anzeigeTitel, symbol: "slider.horizontal.3", farbe: .indigo, infoText: infoText) {
            kachelInhalt
        }
    }

    // MARK: - Gefilterte Einträge

    private var gefilterteEintraege: [PainEntry] {
        var result = eintraege.filter { !$0.istHautEintrag }

        if kachel.filterZeitraum > 0 {
            let cutoff = Calendar.current.date(byAdding: .day, value: -kachel.filterZeitraum, to: Date()) ?? Date()
            result = result.filter { $0.datum >= cutoff }
        }
        if !kachel.filterRegionen.isEmpty {
            result = result.filter { entry in
                let regionen = entry.koerperstelle.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                return kachel.filterRegionen.contains(where: { regionen.contains($0) })
            }
        }
        if !kachel.filterSchmerzarten.isEmpty {
            result = result.filter { kachel.filterSchmerzarten.contains($0.schmerzart) }
        }
        if !kachel.filterMedikament.isEmpty {
            let kal = Calendar.current
            let medName = kachel.filterMedikament
            let medTage = Set(einnahmeLogs
                .filter { $0.medikamentName == medName && $0.eingenommen }
                .map { kal.startOfDay(for: $0.datum) })
            result = result.filter { medTage.contains(kal.startOfDay(for: $0.datum)) }
        }
        if kachel.filterMinStaerke > 0 {
            result = result.filter { $0.schmerzstaerke >= kachel.filterMinStaerke }
        }
        return result
    }

    // MARK: - Diagramm-Typ

    private var effektiverDiagrammTyp: String {
        if kachel.diagrammTyp != "auto" { return kachel.diagrammTyp }
        return xVariable == "schlaf" ? "scatter" : "balken"
    }

    // MARK: - Body

    @ViewBuilder
    private var kachelInhalt: some View {
        let entries = gefilterteEintraege
        if effektiverDiagrammTyp == "scatter" {
            scatterDiagramm(entries)
        } else {
            balkenDiagramm(entries)
        }
    }

    // MARK: - Balken

    private struct Balken: Identifiable {
        var id: String { kategorie }
        let kategorie: String; let avg: Double; let anzahl: Int
    }

    @ViewBuilder
    private func balkenDiagramm(_ entries: [PainEntry]) -> some View {
        let balken = xKategorien(entries)
        if balken.isEmpty {
            leer("Noch nicht genug Daten für diese Korrelation.")
        } else {
            Chart(balken) { p in
                BarMark(x: .value(yLabel, p.avg), y: .value(xLabel, p.kategorie))
                    .foregroundStyle(yFarbe(p.avg).gradient)
                    .cornerRadius(4)
                    .annotation(position: .trailing) {
                        Text(String(format: "%.1f", p.avg))
                            .font(.caption2.bold()).foregroundStyle(.secondary)
                    }
            }
            .chartXScale(domain: 0...yMaxWert)
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
            .frame(height: CGFloat(balken.count) * 36 + 16)
        }
    }

    // MARK: - Scatter

    private struct ScatterPunkt: Identifiable {
        let id = UUID()
        let x: Double; let y: Double
    }

    @ViewBuilder
    private func scatterDiagramm(_ entries: [PainEntry]) -> some View {
        let punkte: [ScatterPunkt] = entries
            .filter { $0.schlafStunden > 0 }
            .map { ScatterPunkt(x: $0.schlafStunden, y: yWert($0)) }

        if punkte.isEmpty {
            leer("Noch nicht genug Daten für dieses Diagramm.")
        } else {
            Chart(punkte) { p in
                PointMark(x: .value("Schlaf (h)", p.x), y: .value(yLabel, p.y))
                    .foregroundStyle(yFarbe(p.y).opacity(0.75))
                    .symbolSize(55)
            }
            .chartXScale(domain: 0...12)
            .chartYScale(domain: 0...yMaxWert)
            .chartXAxisLabel("Schlaf (h)")
            .chartYAxisLabel(yLabel)
            .frame(height: 180)
        }
    }

    // MARK: - X-Kategorien

    private func xKategorien(_ entries: [PainEntry]) -> [Balken] {
        var gruppen: [(String, [PainEntry])] = []
        switch xVariable {
        case "wetter":
            let d = Dictionary(grouping: entries.filter { $0.wetterCode != nil }) { WetterSnapshot.beschreibungFuerCode($0.wetterCode!) }
            gruppen = d.map { ($0.key, $0.value) }.filter { $0.1.count >= 2 }
        case "stress":
            let labels = ["", "Entspannt", "Leicht", "Mässig", "Hoch", "Extrem"]
            gruppen = (1...5).compactMap { i in
                let g = entries.filter { $0.stressLevel == i }
                return g.isEmpty ? nil : (labels[i], g)
            }
        case "schlaf":
            gruppen = [("< 5h", entries.filter { $0.schlafStunden > 0 && $0.schlafStunden < 5 }),
                       ("5–6h", entries.filter { $0.schlafStunden >= 5 && $0.schlafStunden < 7 }),
                       ("7–8h", entries.filter { $0.schlafStunden >= 7 && $0.schlafStunden <= 8 }),
                       ("> 8h", entries.filter { $0.schlafStunden > 8 })].filter { !$0.1.isEmpty }
        case "stimmung":
            let labels = ["", "Schlecht", "Mässig", "Okay", "Gut", "Super"]
            gruppen = (1...5).compactMap { i in
                let g = entries.filter { $0.stimmung == i }
                return g.isEmpty ? nil : (labels[i], g)
            }
        case "tageszeit":
            let slots: [(String, ClosedRange<Int>)] = [
                ("Nacht", 0...5), ("Morgen", 6...11), ("Nachmittag", 12...17), ("Abend", 18...23)
            ]
            gruppen = slots.compactMap { name, range in
                let g = entries.filter { range.contains(Calendar.current.component(.hour, from: $0.datum)) }
                return g.isEmpty ? nil : (name, g)
            }
        case "wochentag":
            let tage = ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]
            gruppen = (1...7).compactMap { i in
                let g = entries.filter { Calendar.current.component(.weekday, from: $0.datum) == i }
                return g.isEmpty ? nil : (tage[i - 1], g)
            }
        case "medikament":
            let kal = Calendar.current
            let uniqueMeds = Array(Set(einnahmeLogs.filter(\.eingenommen).map(\.medikamentName))).sorted()
            gruppen = uniqueMeds.compactMap { medName in
                let medTage = Set(einnahmeLogs
                    .filter { $0.medikamentName == medName && $0.eingenommen }
                    .map { kal.startOfDay(for: $0.datum) })
                let g = entries.filter { medTage.contains(kal.startOfDay(for: $0.datum)) }
                return g.count >= 2 ? (medName, g) : nil
            }
        default:
            return []
        }

        return gruppen.map { name, gruppe in
            Balken(kategorie: name, avg: yDurchschnitt(gruppe), anzahl: gruppe.count)
        }
    }

    // MARK: - Y-Werte

    private func yWert(_ entry: PainEntry) -> Double {
        switch yVariable {
        case "schmerzstaerke": return Double(entry.schmerzstaerke)
        case "stimmung":       return Double(entry.stimmung)
        case "stress":         return Double(entry.stressLevel)
        case "schlafstunden":  return entry.schlafStunden
        default:               return Double(entry.schmerzstaerke)
        }
    }

    private func yDurchschnitt(_ entries: [PainEntry]) -> Double {
        let values: [Double]
        switch yVariable {
        case "schmerzstaerke": values = entries.map { Double($0.schmerzstaerke) }
        case "stimmung":       values = entries.filter { $0.stimmung > 0 }.map { Double($0.stimmung) }
        case "stress":         values = entries.filter { $0.stressLevel > 0 }.map { Double($0.stressLevel) }
        case "schlafstunden":  values = entries.filter { $0.schlafStunden > 0 }.map(\.schlafStunden)
        default:               values = entries.map { Double($0.schmerzstaerke) }
        }
        return values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }

    private var yMaxWert: Double {
        switch yVariable {
        case "stimmung", "stress": return 5
        case "schlafstunden":      return 12
        default:                   return 10
        }
    }

    private var xLabel: String {
        switch xVariable {
        case "wetter": "Wetter"; case "stress": "Stress"; case "schlaf": "Schlaf"
        case "stimmung": "Stimmung"; case "tageszeit": "Tageszeit"; case "wochentag": "Wochentag"
        case "medikament": "Medikament"
        default: xVariable
        }
    }

    private var yLabel: String {
        switch yVariable {
        case "schmerzstaerke": "Schmerzstärke"; case "stimmung": "Stimmung"
        case "stress": "Stress"; case "schlafstunden": "Schlaf (h)"
        default: yVariable
        }
    }

    private func yFarbe(_ avg: Double) -> Color {
        switch yVariable {
        case "stimmung":
            switch Int(avg.rounded()) { case 1: return .red; case 2: return .orange; case 3: return .yellow; case 4: return .mint; default: return .green }
        case "stress":
            switch Int(avg.rounded()) { case 1: return .green; case 2: return .mint; case 3: return .yellow; case 4: return .orange; default: return .red }
        case "schlafstunden":
            return avg >= 7 ? .green : avg >= 5 ? .orange : .red
        default:
            return SchmerzBadge.farbe(fuer: Int(avg.rounded()))
        }
    }
}

// MARK: - Leerer Zustand (geteilt)

private func leer(_ text: String) -> some View {
    Text(text)
        .font(.caption).foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, minHeight: 60)
        .multilineTextAlignment(.center)
}
