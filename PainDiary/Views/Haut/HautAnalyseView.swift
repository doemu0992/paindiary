import SwiftUI
import Charts
import SwiftData

// MARK: - Section Enum

enum HautAnalyseSektion: String, CaseIterable, Codable, Identifiable {
    case zusammenfassung = "Zusammenfassung"
    case verlauf         = "Verlauf"
    case stellen         = "Körperstellen"
    case arten           = "Hautbild-Arten"
    case wohlbefinden    = "Wohlbefinden-Muster"
    case kiInsicht       = "KI-Einblick"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .zusammenfassung: return "chart.bar.fill"
        case .verlauf:         return "chart.line.uptrend.xyaxis"
        case .stellen:         return "figure.stand"
        case .arten:           return "bandage.fill"
        case .wohlbefinden:    return "heart.text.square.fill"
        case .kiInsicht:       return "sparkles"
        }
    }
}

// MARK: - Main View

struct HautAnalyseView: View {
    @Query(sort: \PainEntry.datum, order: .reverse) private var alleEintraege: [PainEntry]
    private var eintraege: [PainEntry] { alleEintraege.filter { $0.istHautEintrag } }

    @State private var sektionen: [HautAnalyseSektion] = HautAnalyseView.sektionenLaden()
    @State private var zeitraum: Zeitraum = .woche
    @State private var zeigeAnpassen = false
    @Environment(\.dismiss) private var dismiss

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
        var wochen: Int {
            switch self {
            case .woche:       return 2
            case .monat:       return 5
            case .dreiMonate:  return 13
            case .sechsMonate: return 26
            case .jahr:        return 52
            case .alle:        return 104
            }
        }
    }

    // MARK: Filtered

    private var gefiltert: [PainEntry] {
        guard let tage = zeitraum.tage else { return eintraege }
        let grenze = Calendar.current.date(byAdding: .day, value: -tage, to: Date()) ?? Date()
        return eintraege.filter { $0.datum >= grenze }
    }

    // MARK: Verlauf (wöchentliche Anzahl)

    private struct WochenPunkt: Identifiable {
        let id = UUID()
        let woche: Date
        let anzahl: Int
    }

    private var wochenVerlauf: [WochenPunkt] {
        let cal = Calendar.current
        return (0..<zeitraum.wochen).reversed().compactMap { offset -> WochenPunkt? in
            guard let ref = cal.date(byAdding: .weekOfYear, value: -offset, to: Date()),
                  let beginn = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: ref)),
                  let ende   = cal.date(byAdding: .day, value: 7, to: beginn)
            else { return nil }
            let n = gefiltert.filter { $0.datum >= beginn && $0.datum < ende }.count
            return n > 0 ? WochenPunkt(woche: beginn, anzahl: n) : nil
        }
    }

    // MARK: Top-Stellen & Arten

    private struct HaeufigkeitEintrag: Identifiable {
        let id = UUID()
        let name: String
        let anzahl: Int
    }

    private func topListe(aus keyPath: KeyPath<PainEntry, String>) -> [HaeufigkeitEintrag] {
        let alle = gefiltert.flatMap { $0[keyPath: keyPath].components(separatedBy: ", ").filter { !$0.isEmpty } }
        return Dictionary(grouping: alle, by: { $0 })
            .map { HaeufigkeitEintrag(name: $0.key, anzahl: $0.value.count) }
            .sorted { $0.anzahl > $1.anzahl }
            .prefix(8)
            .map { $0 }
    }

    // MARK: Wohlbefinden

    private var avgStress: Double? {
        let r = gefiltert.filter { $0.stressLevel > 0 }
        guard !r.isEmpty else { return nil }
        return Double(r.map(\.stressLevel).reduce(0, +)) / Double(r.count)
    }
    private var avgSchlaf: Double? {
        let r = gefiltert.filter { $0.schlafStunden > 0 }
        guard !r.isEmpty else { return nil }
        return r.map(\.schlafStunden).reduce(0, +) / Double(r.count)
    }
    private var avgStimmung: Double? {
        let r = gefiltert.filter { $0.stimmung > 0 }
        guard !r.isEmpty else { return nil }
        return Double(r.map(\.stimmung).reduce(0, +)) / Double(r.count)
    }

    // MARK: Persistence

    private static let kSektionenKey = "hautAnalyseSektionen"

    static func sektionenLaden() -> [HautAnalyseSektion] {
        guard let data = UserDefaults.standard.data(forKey: kSektionenKey),
              let decoded = try? JSONDecoder().decode([HautAnalyseSektion].self, from: data)
        else { return HautAnalyseSektion.allCases }
        let missing = HautAnalyseSektion.allCases.filter { !decoded.contains($0) }
        return decoded + missing
    }

    private func sektionenSpeichern(_ s: [HautAnalyseSektion]) {
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
            .navigationTitle("Haut-Analyse")
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
                HautAnalyseAnpassenView(sektionen: $sektionen)
            }
            .onChange(of: sektionen) { _, new in sektionenSpeichern(new) }
        }
    }

    // MARK: Section Dispatcher

    @ViewBuilder
    private func sektionView(_ sektion: HautAnalyseSektion) -> some View {
        switch sektion {
        case .zusammenfassung: zusammenfassungKarte
        case .verlauf:
            if wochenVerlauf.isEmpty { leerKarte(sektion) }
            else { verlaufKarte }
        case .stellen:
            let liste = topListe(aus: \.hautStellen)
            if liste.isEmpty { leerKarte(sektion) }
            else { stellenKarte(liste) }
        case .arten:
            let liste = topListe(aus: \.hautArt)
            if liste.isEmpty { leerKarte(sektion) }
            else { artenKarte(liste) }
        case .wohlbefinden:
            if avgStress == nil && avgSchlaf == nil { leerKarte(sektion) }
            else { wohlbefindenKarte }
        case .kiInsicht: KIAnalyseKarte(prompt: kiPrompt, modulTint: .orange)
        }
    }

    private var kiPrompt: String {
        let topArten   = topListe(aus: \.hautArt).prefix(3).map(\.name).joined(separator: ", ")
        let topStellen = topListe(aus: \.hautStellen).prefix(3).map(\.name).joined(separator: ", ")
        return """
        Hautveränderungs-Analyse (\(zeitraum.rawValue)):
        - \(gefiltert.count) Einträge
        - Häufigste Arten: \(topArten.isEmpty ? "–" : topArten)
        - Häufigste Körperstellen: \(topStellen.isEmpty ? "–" : topStellen)
        - Ø Stress: \(avgStress.map { String(format: "%.1f", $0) } ?? "–")/5
        - Ø Schlaf: \(avgSchlaf.map { String(format: "%.1f h", $0) } ?? "–")
        Identifiziere Muster und gib 3–4 kurze Einblicke.
        """
    }

    // MARK: Helpers

    private func karte<Content: View>(
        titel: String,
        symbol: String,
        farbe: Color = .orange,
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

    private func leerKarte(_ sektion: HautAnalyseSektion) -> some View {
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

    private func statZelle(_ wert: String, label: String, farbe: Color = .orange) -> some View {
        VStack(spacing: 4) {
            Text(wert).font(.title2.bold()).foregroundStyle(farbe)
            Text(label).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Zusammenfassung

    private var zusammenfassungKarte: some View {
        karte(
            titel: "Zusammenfassung",
            symbol: "chart.bar.fill",
            info: "Überblick über alle Hautveränderungs-Einträge im gewählten Zeitraum."
        ) {
            if gefiltert.isEmpty {
                Text("Keine Einträge in diesem Zeitraum")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                let topA = topListe(aus: \.hautArt).first?.name
                let topS = topListe(aus: \.hautStellen).first?.name
                HStack(spacing: 0) {
                    statZelle("\(gefiltert.count)", label: "Einträge")
                    Divider().frame(height: 44)
                    statZelle(topA ?? "–", label: "Häufigste Art", farbe: topA != nil ? .orange : .secondary)
                    Divider().frame(height: 44)
                    statZelle(topS ?? "–", label: "Häufigste Stelle", farbe: topS != nil ? .orange : .secondary)
                }

                if let erster = gefiltert.last?.datum, let letzter = gefiltert.first?.datum {
                    Divider()
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Erster Eintrag").font(.caption).foregroundStyle(.secondary)
                            Text(erster, style: .date).font(.caption.bold())
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Letzter Eintrag").font(.caption).foregroundStyle(.secondary)
                            Text(letzter, style: .date).font(.caption.bold())
                        }
                    }
                }
            }
        }
    }

    // MARK: Verlauf

    private var verlaufKarte: some View {
        karte(
            titel: "Verlauf",
            symbol: "chart.line.uptrend.xyaxis",
            info: "Anzahl der Hautveränderungs-Einträge pro Woche."
        ) {
            Chart(wochenVerlauf) { p in
                BarMark(
                    x: .value("Woche", p.woche, unit: .weekOfYear),
                    y: .value("Einträge", p.anzahl)
                )
                .foregroundStyle(Color.orange.opacity(0.75))
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) {
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
            .frame(height: 140)
        }
    }

    // MARK: Stellen

    private func stellenKarte(_ liste: [HaeufigkeitEintrag]) -> some View {
        karte(
            titel: "Körperstellen",
            symbol: "figure.stand",
            info: "Am häufigsten betroffene Körperstellen im gewählten Zeitraum."
        ) {
            let maxAnzahl = liste.first?.anzahl ?? 1
            VStack(spacing: 8) {
                ForEach(liste) { eintrag in
                    HStack(spacing: 10) {
                        Text(eintrag.name)
                            .font(.subheadline)
                            .frame(width: 120, alignment: .leading)
                            .lineLimit(1)
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.orange.opacity(0.7))
                                .frame(width: geo.size.width * CGFloat(eintrag.anzahl) / CGFloat(maxAnzahl))
                        }
                        .frame(height: 18)
                        Text("\(eintrag.anzahl)×")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .frame(width: 28, alignment: .trailing)
                    }
                }
            }
        }
    }

    // MARK: Arten

    private func artenKarte(_ liste: [HaeufigkeitEintrag]) -> some View {
        karte(
            titel: "Hautbild-Arten",
            symbol: "bandage.fill",
            info: "Am häufigsten erfasste Arten der Hautveränderung."
        ) {
            let maxAnzahl = liste.first?.anzahl ?? 1
            VStack(spacing: 8) {
                ForEach(liste) { eintrag in
                    HStack(spacing: 10) {
                        Text(eintrag.name)
                            .font(.subheadline)
                            .frame(width: 120, alignment: .leading)
                            .lineLimit(1)
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.orange.opacity(0.7))
                                .frame(width: geo.size.width * CGFloat(eintrag.anzahl) / CGFloat(maxAnzahl))
                        }
                        .frame(height: 18)
                        Text("\(eintrag.anzahl)×")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .frame(width: 28, alignment: .trailing)
                    }
                }
            }
        }
    }

    // MARK: Wohlbefinden

    private var wohlbefindenKarte: some View {
        karte(
            titel: "Wohlbefinden-Muster",
            symbol: "heart.text.square.fill",
            info: "Durchschnittswerte für Stress, Schlaf und Stimmung an Tagen mit Hautveränderungen."
        ) {
            HStack(spacing: 0) {
                if let s = avgStress {
                    statZelle(String(format: "%.1f", s), label: "Ø Stress",
                              farbe: s <= 2 ? .green : s <= 3 ? .yellow : s <= 4 ? .orange : .red)
                }
                if avgStress != nil && (avgSchlaf != nil || avgStimmung != nil) {
                    Divider().frame(height: 44)
                }
                if let schlaf = avgSchlaf {
                    statZelle(String(format: "%.1f h", schlaf), label: "Ø Schlaf",
                              farbe: schlaf >= 7 ? .green : schlaf >= 5 ? .orange : .red)
                }
                if avgSchlaf != nil && avgStimmung != nil {
                    Divider().frame(height: 44)
                }
                if let stimmung = avgStimmung {
                    statZelle(String(format: "%.1f", stimmung), label: "Ø Stimmung",
                              farbe: stimmung >= 4 ? .green : stimmung >= 3 ? .orange : .red)
                }
            }

            if let s = avgStress, s >= 3.5 {
                Divider()
                Label("Erhöhter Stress bei Hautveränderungen erkennbar", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }
}

// MARK: - Anpassen View

struct HautAnalyseAnpassenView: View {
    @Binding var sektionen: [HautAnalyseSektion]
    @Environment(\.dismiss) private var dismiss
    @State private var editMode: EditMode = .active

    var body: some View {
        NavigationStack {
            List {
                ForEach(sektionen) { sektion in
                    Label(sektion.rawValue, systemImage: sektion.symbol)
                        .foregroundStyle(.orange)
                }
                .onMove { sektionen.move(fromOffsets: $0, toOffset: $1) }
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
    }
}
