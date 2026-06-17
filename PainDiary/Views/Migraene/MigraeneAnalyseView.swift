import SwiftUI
import Charts

enum AnalyseSektion: String, CaseIterable, Codable, Identifiable {
    case zusammenfassung = "Zusammenfassung"
    case verlauf         = "Verlauf (6 Monate)"
    case tageszeit       = "Beginn nach Tageszeit"
    case ausloeser       = "Top Auslöser"
    case auraUndDauer    = "Aura & Dauer"
    case medikament      = "Medikament-Wirksamkeit"
    case wetter          = "Wetter bei Anfällen"
    case zyklus          = "Zyklus-Korrelation"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .zusammenfassung: return "chart.bar.fill"
        case .verlauf:         return "chart.line.uptrend.xyaxis"
        case .tageszeit:       return "clock.fill"
        case .ausloeser:       return "exclamationmark.triangle.fill"
        case .auraUndDauer:    return "eye.fill"
        case .medikament:      return "pill.fill"
        case .wetter:          return "cloud.sun.fill"
        case .zyklus:          return "moon.stars.fill"
        }
    }
}

private let kSektionenKey = "migraeneAnalyseSektionen"

private func sektionenLaden() -> [AnalyseSektion] {
    guard let data = UserDefaults.standard.data(forKey: kSektionenKey),
          let decoded = try? JSONDecoder().decode([AnalyseSektion].self, from: data)
    else { return AnalyseSektion.allCases }
    let existing = Set(decoded)
    let missing = AnalyseSektion.allCases.filter { !existing.contains($0) }
    return decoded + missing
}

private func sektionenSpeichern(_ sektionen: [AnalyseSektion]) {
    if let data = try? JSONEncoder().encode(sektionen) {
        UserDefaults.standard.set(data, forKey: kSektionenKey)
    }
}

struct MigraeneAnalyseView: View {
    let anfaelle: [MigraeneEintrag]
    let zyklusAnalyse: ZyklusAnalyse

    @Environment(\.dismiss) private var dismiss
    @State private var sektionen: [AnalyseSektion] = sektionenLaden()
    @State private var zeigeAnpassen = false
    @State private var zeitraum: Zeitraum = .alle

    enum Zeitraum: String, CaseIterable {
        case monat      = "30 T"
        case dreiMonate = "3 M"
        case sechsMonate = "6 M"
        case jahr       = "1 J"
        case alle       = "Alle"

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

    // MARK: - Filtered base

    private var gefiltert: [MigraeneEintrag] {
        guard let tage = zeitraum.tage,
              let cutoff = Calendar.current.date(byAdding: .day, value: -tage, to: Date())
        else { return anfaelle }
        return anfaelle.filter { $0.datum >= cutoff }
    }

    // MARK: - Computed (all use gefiltert)

    private var monatlicherVerlauf: [(monat: Date, anzahl: Int)] {
        let cal = Calendar.current
        return (0..<zeitraum.verlaufMonate).reversed().compactMap { offset -> (Date, Int)? in
            guard let ref = cal.date(byAdding: .month, value: -offset, to: Date()),
                  let interval = cal.dateInterval(of: .month, for: ref) else { return nil }
            let count = gefiltert.filter { $0.datum >= interval.start && $0.datum < interval.end }.count
            return (interval.start, count)
        }
    }

    private var topAusloeser: [(name: String, anzahl: Int)] {
        var counts: [String: Int] = [:]
        gefiltert.flatMap(\.ausloeserListe).forEach { counts[$0, default: 0] += 1 }
        return counts.map { (name: $0.key, anzahl: $0.value) }
            .sorted(by: { $0.anzahl > $1.anzahl })
            .prefix(6).map { $0 }
    }

    private struct TageszeitPunkt: Identifiable {
        let id = UUID()
        let label: String
        let anzahl: Int
        let farbe: Color
    }

    private var tageszeitMuster: [TageszeitPunkt] {
        var n = 0, m = 0, mi = 0, na = 0, ab = 0
        for a in gefiltert {
            switch Calendar.current.component(.hour, from: a.datum) {
            case 6..<11:  m  += 1
            case 11..<14: mi += 1
            case 14..<18: na += 1
            case 18..<22: ab += 1
            default:      n  += 1
            }
        }
        return [
            .init(label: "Nacht",   anzahl: n,  farbe: .indigo),
            .init(label: "Morgens", anzahl: m,  farbe: .orange),
            .init(label: "Mittags", anzahl: mi, farbe: .yellow),
            .init(label: "Nachm.",  anzahl: na, farbe: .mint),
            .init(label: "Abend",   anzahl: ab, farbe: .purple),
        ]
    }

    private var avgDauerMin: Double? {
        let mit = gefiltert.filter { $0.dauer > 0 }.map { Double($0.dauer) }
        guard !mit.isEmpty else { return nil }
        return mit.reduce(0, +) / Double(mit.count)
    }

    private var auraQuote: Double {
        guard !gefiltert.isEmpty else { return 0 }
        return Double(gefiltert.filter(\.hatAura).count) / Double(gefiltert.count) * 100
    }

    private struct MedWirksamkeit: Identifiable {
        let id = UUID()
        let name: String
        let gut: Int
        let teilweise: Int
        let nicht: Int
        var total: Int { gut + teilweise + nicht }
    }

    private var medWirksamkeit: [MedWirksamkeit] {
        var map: [String: (Int, Int, Int)] = [:]
        for a in gefiltert where !a.akutmedikament.isEmpty {
            var (g, t, n) = map[a.akutmedikament] ?? (0, 0, 0)
            switch a.medikamentWirksam {
            case "Ja":        g += 1
            case "Teilweise": t += 1
            case "Nein":      n += 1
            default: break
            }
            map[a.akutmedikament] = (g, t, n)
        }
        return map.map { MedWirksamkeit(name: $0.key, gut: $0.value.0, teilweise: $0.value.1, nicht: $0.value.2) }
            .filter { $0.total > 0 }
            .sorted { $0.total > $1.total }
    }

    private var zyklusDaten: [(phase: ZyklusRechner.Zyklusphase, anzahl: Int, avgStaerke: Double)] {
        ZyklusRechner.migraeneJePhase(anfaelle: gefiltert, analyse: zyklusAnalyse)
    }

    private struct WetterPunkt: Identifiable {
        let id = UUID()
        let beschreibung: String
        let symbol: String
        let anzahl: Int
    }

    private var wetterVerteilung: [WetterPunkt] {
        var counts: [Int: Int] = [:]
        gefiltert.compactMap(\.wetterCode).forEach { counts[$0, default: 0] += 1 }
        return counts
            .map { WetterPunkt(beschreibung: WetterSnapshot.beschreibungFuerCode($0.key),
                               symbol: WetterSnapshot.symbolFuerCode($0.key),
                               anzahl: $0.value) }
            .sorted(by: { $0.anzahl > $1.anzahl })
    }

    private var avgTemperatur: Double? {
        let temps = gefiltert.compactMap(\.wetterTemperatur)
        guard !temps.isEmpty else { return nil }
        return temps.reduce(0, +) / Double(temps.count)
    }

    private var avgWind: Double? {
        let winds = gefiltert.compactMap(\.wetterWind).filter { $0 > 0 }
        guard !winds.isEmpty else { return nil }
        return winds.reduce(0, +) / Double(winds.count)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("Zeitraum", selection: $zeitraum) {
                        ForEach(Zeitraum.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)

                    ForEach(sektionen) { sektion in
                        sektionView(sektion)
                    }
                }
                .padding()
            }
            .navigationTitle("Migräne-Analyse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { zeigeAnpassen = true } label: {
                        Label("Anpassen", systemImage: "slider.horizontal.3")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .sheet(isPresented: $zeigeAnpassen) {
                AnalyseAnpassenView(sektionen: $sektionen)
            }
            .onChange(of: sektionen) { _, new in sektionenSpeichern(new) }
        }
    }

    @ViewBuilder
    private func sektionView(_ sektion: AnalyseSektion) -> some View {
        switch sektion {
        case .zusammenfassung: summaryKarte
        case .verlauf:         verlaufKarte
        case .tageszeit:       tageszeitKarte
        case .ausloeser:
            if !topAusloeser.isEmpty { ausloeserKarte }
            else { leerKarte(sektion) }
        case .auraUndDauer:
            HStack(alignment: .top, spacing: 12) {
                auraKarte
                dauerKarte
            }
        case .medikament:
            if !medWirksamkeit.isEmpty { medikamentKarte }
            else { leerKarte(sektion) }
        case .wetter:
            if !wetterVerteilung.isEmpty { wetterKarte }
            else { leerKarte(sektion) }
        case .zyklus: zyklusKarte
        }
    }

    // MARK: - Summary

    private var summaryKarte: some View {
        let count = gefiltert.count
        let avg = gefiltert.isEmpty ? 0.0
            : Double(gefiltert.map(\.staerke).reduce(0, +)) / Double(gefiltert.count)
        let mitAura = gefiltert.filter(\.hatAura).count
        return HStack(spacing: 0) {
            statZelle("\(count)", label: "Anfälle", farbe: .purple)
            Divider().frame(height: 44)
            statZelle(gefiltert.isEmpty ? "–" : String(format: "%.1f", avg), label: "Ø Stärke", farbe: .red)
            Divider().frame(height: 44)
            statZelle("\(mitAura)", label: "Mit Aura", farbe: .indigo)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    private func statZelle(_ wert: String, label: String, farbe: Color) -> some View {
        VStack(spacing: 4) {
            Text(wert).font(.title2.bold()).foregroundStyle(farbe)
            Text(label).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Verlauf

    private var verlaufKarte: some View {
        karte(titel: "Verlauf (6 Monate)", symbol: "chart.bar.fill", farbe: .purple, info: "Zeigt die Anzahl der Migräne-Anfälle pro Monat. Ein Anstieg über mehrere Monate kann auf eine Verschlechterung hinweisen und sollte mit dem Arzt besprochen werden.") {
            Chart(monatlicherVerlauf, id: \.monat) { item in
                BarMark(
                    x: .value("Monat", item.monat, unit: .month),
                    y: .value("Anfälle", item.anzahl)
                )
                .foregroundStyle(Color.purple.gradient)
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) {
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
            .frame(height: 130)
        }
    }

    // MARK: - Tageszeit

    private var tageszeitKarte: some View {
        karte(titel: "Beginn nach Tageszeit", symbol: "clock.fill", farbe: .indigo, info: "Zu welcher Tageszeit beginnen deine Anfälle am häufigsten? Morgens häufige Anfälle können auf Schlaf oder Hormonschwankungen hinweisen. Anfälle am Abend können stressbedingt sein.") {
            Chart(tageszeitMuster) { item in
                BarMark(
                    x: .value("Zeit", item.label),
                    y: .value("Anzahl", item.anzahl)
                )
                .foregroundStyle(item.farbe.gradient)
                .cornerRadius(4)
            }
            .frame(height: 110)
        }
    }

    // MARK: - Auslöser

    private var ausloeserKarte: some View {
        karte(titel: "Top Auslöser", symbol: "exclamationmark.triangle.fill", farbe: .orange, info: "Die häufigsten von dir eingetragenen Auslöser. Achte besonders auf Auslöser die du beeinflussen kannst (Schlaf, Stress, Ernährung) – das sind die wirksamsten Ansatzpunkte zur Anfallsreduktion.") {
            let maxVal = topAusloeser.first?.anzahl ?? 1
            VStack(spacing: 10) {
                ForEach(topAusloeser, id: \.name) { item in
                    HStack(spacing: 10) {
                        Text(item.name)
                            .font(.subheadline)
                            .frame(width: 110, alignment: .leading)
                            .lineLimit(1)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.orange.opacity(0.15))
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.orange.gradient)
                                    .frame(width: geo.size.width * CGFloat(item.anzahl) / CGFloat(maxVal))
                            }
                        }
                        .frame(height: 18)
                        Text("\(item.anzahl)")
                            .font(.caption.bold()).foregroundStyle(.orange)
                            .frame(width: 20, alignment: .trailing)
                    }
                }
            }
        }
    }

    // MARK: - Aura & Dauer

    private var auraKarte: some View {
        VStack(spacing: 8) {
            Image(systemName: "eye.fill").font(.title2).foregroundStyle(.purple)
            Text(String(format: "%.0f%%", auraQuote))
                .font(.title.bold()).foregroundStyle(.purple)
            Text("mit Aura").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    private var dauerKarte: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.fill").font(.title2).foregroundStyle(.teal)
            Group {
                if let avg = avgDauerMin {
                    let h = Int(avg) / 60; let m = Int(avg) % 60
                    Text(h > 0 ? "\(h)h\(m > 0 ? " \(m)m" : "")" : "\(m)m")
                } else {
                    Text("–")
                }
            }
            .font(.title.bold()).foregroundStyle(.teal)
            Text("Ø Dauer").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    // MARK: - Medikament

    private var medikamentKarte: some View {
        karte(titel: "Medikament-Wirksamkeit", symbol: "pill.fill", farbe: .blue, info: "Zeigt wie wirksam du deine Akutmedikamente einschätzt. Medikamente die häufig als 'nicht wirksam' bewertet werden, sollten im nächsten Arztgespräch besprochen werden – möglicherweise gibt es wirksamere Alternativen.") {
            VStack(spacing: 14) {
                ForEach(medWirksamkeit) { med in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(med.name).font(.subheadline.bold())
                        GeometryReader { geo in
                            HStack(spacing: 2) {
                                if med.gut > 0 {
                                    RoundedRectangle(cornerRadius: 3).fill(Color.green)
                                        .frame(width: geo.size.width * CGFloat(med.gut) / CGFloat(med.total))
                                }
                                if med.teilweise > 0 {
                                    RoundedRectangle(cornerRadius: 3).fill(Color.orange)
                                        .frame(width: geo.size.width * CGFloat(med.teilweise) / CGFloat(med.total))
                                }
                                if med.nicht > 0 {
                                    RoundedRectangle(cornerRadius: 3).fill(Color.red)
                                        .frame(width: geo.size.width * CGFloat(med.nicht) / CGFloat(med.total))
                                }
                            }
                            .frame(height: 10)
                        }
                        .frame(height: 10)
                        HStack(spacing: 10) {
                            if med.gut > 0 {
                                Label("\(med.gut)× wirksam", systemImage: "circle.fill")
                                    .font(.caption).foregroundStyle(.green)
                            }
                            if med.teilweise > 0 {
                                Label("\(med.teilweise)× teilweise", systemImage: "circle.fill")
                                    .font(.caption).foregroundStyle(.orange)
                            }
                            if med.nicht > 0 {
                                Label("\(med.nicht)× nicht", systemImage: "circle.fill")
                                    .font(.caption).foregroundStyle(.red)
                            }
                        }
                    }
                    if med.id != medWirksamkeit.last?.id { Divider() }
                }
            }
        }
    }

    // MARK: - Zyklus

    private var zyklusKarte: some View {
        karte(titel: "Zyklus-Korrelation", symbol: "moon.stars.fill", farbe: .pink, info: "Ordnet jeden Migräne-Anfall einer Zyklusphase zu. Hormonelle Schwankungen – besonders der Östrogenabfall vor der Periode – sind ein bekannter Migräne-Trigger. Diese Ansicht hilft dein persönliches Muster zu erkennen.") {
            if zyklusDaten.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "moon.stars.fill")
                        .font(.title2).foregroundStyle(.pink.opacity(0.4))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Keine Daten verfügbar")
                            .font(.subheadline.bold()).foregroundStyle(.secondary)
                        Text("Erfasse Zyklusdaten im Zyklus-Modul um die Korrelation mit Migräne-Anfällen zu sehen.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    Chart(zyklusDaten, id: \.phase) { item in
                        BarMark(
                            x: .value("Phase", item.phase.rawValue),
                            y: .value("Anfälle", item.anzahl)
                        )
                        .foregroundStyle(phaseFarbe(item.phase).gradient)
                        .cornerRadius(4)
                        .annotation(position: .top) {
                            Text("\(item.anzahl)").font(.caption2.bold())
                                .foregroundStyle(phaseFarbe(item.phase))
                        }
                    }
                    .frame(height: 120)

                    Divider()

                    // Ø Stärke je Phase
                    VStack(spacing: 8) {
                        ForEach(zyklusDaten, id: \.phase) { item in
                            HStack(spacing: 10) {
                                Circle().fill(phaseFarbe(item.phase))
                                    .frame(width: 8, height: 8)
                                Text(item.phase.rawValue)
                                    .font(.caption).foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(item.anzahl) Anfall\(item.anzahl == 1 ? "" : "älle")")
                                    .font(.caption).foregroundStyle(.secondary)
                                Text(String(format: "Ø %.1f", item.avgStaerke))
                                    .font(.caption.bold())
                                    .foregroundStyle(phaseFarbe(item.phase))
                                    .frame(width: 50, alignment: .trailing)
                            }
                        }
                    }

                    if let risikoPhase = zyklusDaten.max(by: { $0.anzahl < $1.anzahl }) {
                        Divider()
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.pink).font(.caption)
                            Text("Höchstes Risiko: \(risikoPhase.phase.rawValue)")
                                .font(.caption.bold()).foregroundStyle(.pink)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Wetter

    private var wetterKarte: some View {
        karte(titel: "Wetter bei Anfällen", symbol: "cloud.sun.fill", farbe: .blue, info: "Welche Wetterbedingungen traten bei deinen Anfällen am häufigsten auf? Wetterempfindlichkeit ist bei Migräne-Patienten häufig – besonders Föhn, Tiefdruckgebiete und rasche Temperaturwechsel gelten als Trigger.") {
            VStack(spacing: 12) {
                let maxVal = wetterVerteilung.first?.anzahl ?? 1
                ForEach(wetterVerteilung) { item in
                    HStack(spacing: 10) {
                        Image(systemName: item.symbol)
                            .font(.title3)
                            .foregroundStyle(.yellow)
                            .frame(width: 28)
                        Text(item.beschreibung)
                            .font(.subheadline)
                            .frame(width: 100, alignment: .leading)
                            .lineLimit(1)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.blue.opacity(0.15))
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.blue.gradient)
                                    .frame(width: geo.size.width * CGFloat(item.anzahl) / CGFloat(maxVal))
                            }
                        }
                        .frame(height: 18)
                        Text("\(item.anzahl)")
                            .font(.caption.bold()).foregroundStyle(.blue)
                            .frame(width: 20, alignment: .trailing)
                    }
                }
                if avgTemperatur != nil || avgWind != nil {
                    Divider()
                    HStack(spacing: 0) {
                        if let temp = avgTemperatur {
                            VStack(spacing: 4) {
                                Image(systemName: "thermometer.medium").foregroundStyle(.orange)
                                Text(String(format: "%.0f°C", temp))
                                    .font(.subheadline.bold())
                                Text("Ø Temperatur").font(.caption).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        if let wind = avgWind {
                            VStack(spacing: 4) {
                                Image(systemName: "wind").foregroundStyle(.teal)
                                Text(String(format: "%.0f km/h", wind))
                                    .font(.subheadline.bold())
                                Text("Ø Wind").font(.caption).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private func phaseFarbe(_ phase: ZyklusRechner.Zyklusphase) -> Color {
        switch phase {
        case .menstruation:  return .red
        case .follikelphase: return .yellow
        case .ovulation:     return .orange
        case .lutealphase:   return .purple
        }
    }

    // MARK: - Helper

    private func leerKarte(_ sektion: AnalyseSektion) -> some View {
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
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    private func karte<Content: View>(titel: String, symbol: String, farbe: Color, info: String = "", @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 4) {
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
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }
}

// MARK: - Anpassen Sheet

struct AnalyseAnpassenView: View {
    @Binding var sektionen: [AnalyseSektion]
    @Environment(\.dismiss) private var dismiss
    @State private var editMode: EditMode = .active

    var body: some View {
        NavigationStack {
            List {
                ForEach(sektionen) { sektion in
                    HStack(spacing: 12) {
                        Image(systemName: sektion.symbol)
                            .foregroundStyle(.purple)
                            .frame(width: 24)
                        Text(sektion.rawValue)
                            .font(.subheadline)
                    }
                }
                .onMove { from, to in
                    sektionen.move(fromOffsets: from, toOffset: to)
                    sektionenSpeichern(sektionen)
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
