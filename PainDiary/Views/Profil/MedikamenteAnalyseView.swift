import SwiftUI
import Charts

// MARK: - Section Enum

enum MedAnalyseSektion: String, CaseIterable, Codable, Identifiable {
    case zusammenfassung = "Zusammenfassung"
    case verlauf         = "Adherenz-Verlauf"
    case wirksamkeit     = "Wirksamkeit"
    case beiBedarf       = "Bei Bedarf"
    case kiInsicht       = "KI-Einblick"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .zusammenfassung: return "chart.bar.fill"
        case .verlauf:         return "waveform.path.ecg"
        case .wirksamkeit:     return "star.fill"
        case .beiBedarf:       return "pills.fill"
        case .kiInsicht:       return "sparkles"
        }
    }
}

// MARK: - Main View

struct MedikamenteAnalyseView: View {
    let medikamente: [Dauermedikation]
    let logs: [EinnahmeLog]

    @State private var sektionen: [MedAnalyseSektion] = MedikamenteAnalyseView.sektionenLaden()
    @State private var zeitraum: Zeitraum = .woche
    @State private var zeigeAnpassen = false
    @Environment(\.dismiss) private var dismiss

    private let notif = NotificationManager.shared

    enum Zeitraum: String, CaseIterable {
        case woche      = "7 T"
        case monat      = "30 T"
        case dreiMonate = "3 M"
        case alle       = "Alle"

        var tage: Int {
            switch self {
            case .woche:      return 7
            case .monat:      return 30
            case .dreiMonate: return 90
            case .alle:       return 180
            }
        }
    }

    // MARK: - Base Helpers

    private var kal: Calendar { Calendar.current }
    private var heute: Date { kal.startOfDay(for: Date()) }
    private var grenze: Date { kal.date(byAdding: .day, value: -zeitraum.tage, to: heute) ?? heute }

    private var gefilterteLogs: [EinnahmeLog] {
        logs.filter { $0.datum >= grenze && $0.eingenommen }
    }

    private var aktivePlanMeds: [Dauermedikation] {
        medikamente.filter { $0.aktiv && $0.frequenz != "Bei Bedarf" && notif.anzahlDosen($0.frequenz) > 0 }
    }

    private var beiBedArfMeds: [Dauermedikation] {
        medikamente.filter { $0.frequenz == "Bei Bedarf" }
    }

    private var beiBedArfNamen: Set<String> { Set(beiBedArfMeds.map(\.name)) }

    // MARK: - Stats

    private var adherenzGesamt: Double {
        var erwartet = 0; var eingenommen = 0
        for offset in 0..<zeitraum.tage {
            guard let tag = kal.date(byAdding: .day, value: -offset, to: heute),
                  let tagEnde = kal.date(byAdding: .day, value: 1, to: tag) else { continue }
            for med in aktivePlanMeds {
                guard med.startDatum <= tagEnde else { continue }
                let n = notif.anzahlDosen(med.frequenz)
                erwartet += n
                let taken = logs.filter {
                    $0.medikamentName == med.name && $0.dosierung == med.dosierung &&
                    $0.eingenommen && $0.datum >= tag && $0.datum < tagEnde
                }.count
                eingenommen += min(taken, n)
            }
        }
        return erwartet > 0 ? Double(eingenommen) / Double(erwartet) * 100 : 0
    }

    private var adherenzFarbe: Color { adherenzGesamt >= 80 ? .green : adherenzGesamt >= 50 ? .orange : .red }

    private var bewerteteLogs: [EinnahmeLog] { gefilterteLogs.filter { !$0.wirkung.isEmpty } }
    private var wirkungGut: Int       { bewerteteLogs.filter { $0.wirkung == "gut" }.count }
    private var wirkungTeilweise: Int { bewerteteLogs.filter { $0.wirkung == "teilweise" }.count }
    private var wirkungNicht: Int     { bewerteteLogs.filter { $0.wirkung == "nicht" }.count }
    private var wirkungsrate: Double  { bewerteteLogs.isEmpty ? 0 : Double(wirkungGut) / Double(bewerteteLogs.count) * 100 }
    private var wirkungsFarbe: Color  { wirkungsrate >= 70 ? .green : wirkungsrate >= 40 ? .orange : .red }

    private var beiBedArfLogs: [EinnahmeLog] {
        gefilterteLogs.filter { beiBedArfNamen.contains($0.medikamentName) }
    }

    private var beiBedArfTagZaehlung: [(datum: Date, anzahl: Int)] {
        var d: [Date: Int] = [:]
        for log in beiBedArfLogs { d[kal.startOfDay(for: log.datum), default: 0] += 1 }
        return d.map { (datum: $0.key, anzahl: $0.value) }.sorted { $0.datum < $1.datum }
    }

    // MARK: - Adherenz Verlauf

    private struct TagAdherenz: Identifiable {
        let id = UUID()
        let datum: Date
        let prozent: Double  // 0–100; -1 = no scheduled meds
    }

    private var verlaufGranularitaet: Calendar.Component {
        switch zeitraum {
        case .woche, .monat: return .day
        default:             return .weekOfYear
        }
    }

    private var adherenzVerlauf: [TagAdherenz] {
        let tage = zeitraum.tage
        return (0..<tage).compactMap { offset -> TagAdherenz? in
            guard let tag = kal.date(byAdding: .day, value: -(tage - 1 - offset), to: heute),
                  let tagEnde = kal.date(byAdding: .day, value: 1, to: tag) else { return nil }
            var erwartet = 0; var eingenommen = 0
            for med in aktivePlanMeds {
                guard med.startDatum <= tagEnde else { continue }
                let n = notif.anzahlDosen(med.frequenz)
                erwartet += n
                let taken = logs.filter {
                    $0.medikamentName == med.name && $0.dosierung == med.dosierung &&
                    $0.eingenommen && $0.datum >= tag && $0.datum < tagEnde
                }.count
                eingenommen += min(taken, n)
            }
            let p = erwartet > 0 ? Double(eingenommen) / Double(erwartet) * 100 : -1
            return TagAdherenz(datum: tag, prozent: p)
        }
    }

    private var verlaufAggregiert: [TagAdherenz] {
        guard verlaufGranularitaet == .weekOfYear else { return adherenzVerlauf }
        var wochenMap: [Date: (summe: Double, anzahl: Int)] = [:]
        for punkt in adherenzVerlauf where punkt.prozent >= 0 {
            let comps = kal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: punkt.datum)
            let key = kal.date(from: comps) ?? punkt.datum
            let alt = wochenMap[key] ?? (summe: 0, anzahl: 0)
            wochenMap[key] = (summe: alt.summe + punkt.prozent, anzahl: alt.anzahl + 1)
        }
        return wochenMap.map { key, val in
            TagAdherenz(datum: key, prozent: val.anzahl > 0 ? val.summe / Double(val.anzahl) : 0)
        }.sorted { $0.datum < $1.datum }
    }

    // MARK: - KI Prompt

    private var kiPrompt: String {
        var teile = ["Medikamenten-Analyse (\(zeitraum.rawValue)):"]
        teile.append("Aktive Medikamente: \(medikamente.filter(\.aktiv).count)")
        if !aktivePlanMeds.isEmpty {
            teile.append(String(format: "Adherenz: %.0f%%", adherenzGesamt))
        }
        teile.append("Einnahmen im Zeitraum: \(gefilterteLogs.count)")
        if !beiBedArfLogs.isEmpty {
            teile.append("Bei-Bedarf-Einnahmen: \(beiBedArfLogs.count)")
        }
        if !bewerteteLogs.isEmpty {
            teile.append("Wirksamkeit: \(wirkungGut)× gut, \(wirkungTeilweise)× teilweise, \(wirkungNicht)× nicht")
        }
        return teile.joined(separator: "\n")
    }

    // MARK: - Persistence

    private static let kSektionenKey = "medikamenteAnalyseSektionen"

    static func sektionenLaden() -> [MedAnalyseSektion] {
        guard let data = UserDefaults.standard.data(forKey: kSektionenKey),
              let decoded = try? JSONDecoder().decode([MedAnalyseSektion].self, from: data)
        else { return MedAnalyseSektion.allCases }
        let missing = MedAnalyseSektion.allCases.filter { !decoded.contains($0) }
        return decoded + missing
    }

    private func sektionenSpeichern(_ s: [MedAnalyseSektion]) {
        if let data = try? JSONEncoder().encode(s) {
            UserDefaults.standard.set(data, forKey: Self.kSektionenKey)
        }
    }

    // MARK: - Body

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
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Medikamenten-Analyse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fertig") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button { zeigeAnpassen = true } label: {
                        Label("Anpassen", systemImage: "slider.horizontal.3")
                    }
                }
            }
            .sheet(isPresented: $zeigeAnpassen) {
                MedAnalyseAnpassenView(sektionen: $sektionen)
            }
            .onChange(of: sektionen) { _, new in sektionenSpeichern(new) }
        }
    }

    // MARK: - Section Dispatcher

    @ViewBuilder
    private func sektionView(_ sektion: MedAnalyseSektion) -> some View {
        switch sektion {
        case .zusammenfassung: zusammenfassungKarte
        case .verlauf:         verlaufKarte
        case .wirksamkeit:     wirksamkeitKarte
        case .beiBedarf:       beiBedArfKarte
        case .kiInsicht:
            KIAnalyseKarte(prompt: kiPrompt, modulTint: .blue)
                .id(kiPrompt)
        }
    }

    // MARK: - Card Helper

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

    private func leerKarte(_ sektion: MedAnalyseSektion) -> some View {
        karte(titel: sektion.rawValue, symbol: sektion.symbol) {
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

    private func legendPunkt(farbe: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(farbe).frame(width: 8, height: 8)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: - Zusammenfassung

    private var zusammenfassungKarte: some View {
        karte(titel: "Zusammenfassung", symbol: "chart.bar.fill",
              info: "Adherenz = Anteil der tatsächlich eingenommenen Dosen im Verhältnis zu den geplanten. Eine Adherenz über 80% gilt als gut. Unter 50% besteht Risiko für Therapieversagen. Einnahme-Logs werden pro Medikament und Dosierung gezählt.") {
            if logs.isEmpty {
                Text("Noch keine Einnahme-Logs vorhanden")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                HStack(spacing: 0) {
                    if !aktivePlanMeds.isEmpty {
                        statZelle(
                            adherenzGesamt > 0 ? String(format: "%.0f%%", adherenzGesamt) : "–",
                            label: "Adherenz", farbe: adherenzFarbe
                        )
                    } else {
                        statZelle("\(medikamente.filter(\.aktiv).count)", label: "Aktiv", farbe: .blue)
                    }
                    Divider().frame(height: 40)
                    statZelle("\(gefilterteLogs.count)", label: "Einnahmen", farbe: .blue)
                    Divider().frame(height: 40)
                    if !bewerteteLogs.isEmpty {
                        statZelle(String(format: "%.0f%%", wirkungsrate),
                                  label: "Wirkungsrate", farbe: wirkungsFarbe)
                    } else {
                        statZelle("\(beiBedArfLogs.count)", label: "Bei Bedarf", farbe: .secondary)
                    }
                }

                if !aktivePlanMeds.isEmpty {
                    Divider()
                    HStack(spacing: 0) {
                        statZelle("\(aktivePlanMeds.count)", label: "Plan-Meds", farbe: .secondary)
                        Divider().frame(height: 40)
                        statZelle("\(beiBedArfMeds.count)", label: "Bei Bedarf", farbe: .secondary)
                        Divider().frame(height: 40)
                        statZelle("\(medikamente.filter { !$0.aktiv }.count)", label: "Pausiert", farbe: .secondary)
                    }
                }
            }
        }
    }

    // MARK: - Verlauf

    @ViewBuilder
    private var verlaufKarte: some View {
        let daten = verlaufAggregiert.filter { $0.prozent >= 0 }
        if daten.isEmpty {
            karte(titel: "Adherenz-Verlauf", symbol: "waveform.path.ecg",
                  info: "Tägliche Einnahmetreue im Verlauf. Grün = Dosis eingenommen, Lücken = vergessene Einnahmen. Regelmäßige Lücken an denselben Wochentagen können auf Routine-Probleme hinweisen — versuche eine tägliche Erinnerungszeit zu setzen.") {
                Text(aktivePlanMeds.isEmpty
                     ? "Keine geplanten Medikamente eingetragen"
                     : "Keine Einnahme-Logs in diesem Zeitraum")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
        } else {
            karte(titel: "Adherenz-Verlauf", symbol: "waveform.path.ecg",
                  info: "Tägliche Einnahmetreue im Verlauf. Grün = Dosis eingenommen, Lücken = vergessene Einnahmen. Regelmäßige Lücken an denselben Wochentagen können auf Routine-Probleme hinweisen — versuche eine tägliche Erinnerungszeit zu setzen.") {
                let komp = verlaufGranularitaet
                Chart(daten) { punkt in
                    BarMark(
                        x: .value("Tag", punkt.datum, unit: komp),
                        y: .value("Adherenz", punkt.prozent)
                    )
                    .foregroundStyle(
                        punkt.prozent >= 80 ? Color.green.opacity(0.75) :
                        punkt.prozent >= 50 ? Color.orange.opacity(0.75) :
                                              Color.red.opacity(0.75)
                    )
                    .cornerRadius(3)
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(values: [0, 50, 100]) { val in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = val.as(Int.self) { Text("\(v)%").font(.caption2) }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: komp)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated), centered: true)
                    }
                }
                .frame(height: 140)

                HStack(spacing: 16) {
                    legendPunkt(farbe: .green, label: "≥ 80%")
                    legendPunkt(farbe: .orange, label: "≥ 50%")
                    legendPunkt(farbe: .red, label: "< 50%")
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    // MARK: - Wirksamkeit

    private var wirksamkeitKarte: some View {
        Group {
            if bewerteteLogs.isEmpty {
                leerKarte(.wirksamkeit)
            } else {
                karte(titel: "Wirksamkeit", symbol: "star.fill",
                      info: "Eigenbewertung der Medikamentenwirkung beim Einnahme-Log. 'Gut' = deutliche Wirkung. 'Teilweise' = leichte Wirkung. 'Nicht' = keine wahrnehmbare Wirkung. Häufige 'Nicht'-Bewertungen sollten im nächsten Arztgespräch besprochen werden.") {
                    let total = bewerteteLogs.count
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Gesamt (\(total) Bewertungen)").font(.caption).foregroundStyle(.secondary)
                            GeometryReader { geo in
                                HStack(spacing: 2) {
                                    if wirkungGut > 0 {
                                        RoundedRectangle(cornerRadius: 3).fill(Color.green)
                                            .frame(width: geo.size.width * CGFloat(wirkungGut) / CGFloat(total))
                                    }
                                    if wirkungTeilweise > 0 {
                                        RoundedRectangle(cornerRadius: 3).fill(Color.orange)
                                            .frame(width: geo.size.width * CGFloat(wirkungTeilweise) / CGFloat(total))
                                    }
                                    if wirkungNicht > 0 {
                                        RoundedRectangle(cornerRadius: 3).fill(Color.red)
                                            .frame(width: geo.size.width * CGFloat(wirkungNicht) / CGFloat(total))
                                    }
                                }
                            }
                            .frame(height: 14)
                            HStack(spacing: 12) {
                                legendPunkt(farbe: .green, label: "Gut (\(wirkungGut)×)")
                                legendPunkt(farbe: .orange, label: "Teilweise (\(wirkungTeilweise)×)")
                                legendPunkt(farbe: .red, label: "Nicht (\(wirkungNicht)×)")
                            }
                        }

                        let medNamen = Array(Set(bewerteteLogs.map(\.medikamentName))).sorted()
                        if medNamen.count > 1 {
                            Divider()
                            ForEach(medNamen, id: \.self) { name in
                                wirkungZeile(name: name)
                            }
                        }
                    }
                }
            }
        }
    }

    private func wirkungZeile(name: String) -> some View {
        let medLogs = bewerteteLogs.filter { $0.medikamentName == name }
        let gut  = medLogs.filter { $0.wirkung == "gut" }.count
        let tw   = medLogs.filter { $0.wirkung == "teilweise" }.count
        let ni   = medLogs.filter { $0.wirkung == "nicht" }.count
        let tot  = medLogs.count
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name).font(.caption.bold()).lineLimit(1)
                Spacer()
                Text("\(tot)×").font(.caption2).foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                HStack(spacing: 2) {
                    if gut > 0 {
                        RoundedRectangle(cornerRadius: 3).fill(Color.green)
                            .frame(width: geo.size.width * CGFloat(gut) / CGFloat(tot))
                    }
                    if tw > 0 {
                        RoundedRectangle(cornerRadius: 3).fill(Color.orange)
                            .frame(width: geo.size.width * CGFloat(tw) / CGFloat(tot))
                    }
                    if ni > 0 {
                        RoundedRectangle(cornerRadius: 3).fill(Color.red)
                            .frame(width: geo.size.width * CGFloat(ni) / CGFloat(tot))
                    }
                }
            }
            .frame(height: 10)
        }
    }

    // MARK: - Bei Bedarf

    private var beiBedArfKarte: some View {
        Group {
            if beiBedArfLogs.isEmpty {
                leerKarte(.beiBedarf)
            } else {
                karte(titel: "Bei Bedarf", symbol: "pills.fill",
                      info: "Einnahmen von Bedarfsmedikamenten (z.B. Schmerzmittel). Mehr als 10–15 Einnahmen pro Monat können zu einem Medikamenten-Übergebrauchskopfschmerz führen. Spreche mit deinem Arzt, wenn du Bedarfsmedikamente häufig benötigst.") {
                    let avgProTag = Double(beiBedArfLogs.count) / Double(zeitraum.tage)
                    let tageCount = Set(beiBedArfLogs.map { kal.startOfDay(for: $0.datum) }).count

                    HStack(spacing: 0) {
                        statZelle("\(beiBedArfLogs.count)", label: "Einnahmen", farbe: .blue)
                        Divider().frame(height: 40)
                        statZelle(String(format: "%.1f", avgProTag), label: "⌀ / Tag",
                                  farbe: avgProTag > 1.5 ? .orange : .secondary)
                        Divider().frame(height: 40)
                        statZelle("\(tageCount)", label: "Tage", farbe: .secondary)
                    }

                    Divider()

                    Chart(beiBedArfTagZaehlung, id: \.datum) { punkt in
                        BarMark(
                            x: .value("Tag", punkt.datum, unit: .day),
                            y: .value("Einnahmen", punkt.anzahl)
                        )
                        .foregroundStyle(Color.blue.opacity(0.7))
                        .cornerRadius(3)
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis {
                        AxisMarks(position: .trailing) { val in
                            AxisGridLine()
                            AxisValueLabel {
                                if let v = val.as(Int.self) { Text("\(v)").font(.caption2) }
                            }
                        }
                    }
                    .frame(height: 90)

                    if beiBedArfMeds.count > 1 {
                        Divider()
                        let maxCount = beiBedArfMeds.map { med in
                            beiBedArfLogs.filter { $0.medikamentName == med.name }.count
                        }.max() ?? 1
                        ForEach(beiBedArfMeds) { med in
                            beiBedArfZeile(med: med, maxCount: maxCount)
                        }
                    }
                }
            }
        }
    }

    private func beiBedArfZeile(med: Dauermedikation, maxCount: Int) -> some View {
        let count = beiBedArfLogs.filter { $0.medikamentName == med.name }.count
        return Group {
            if count > 0 {
                HStack(spacing: 8) {
                    Text(med.name).font(.caption).frame(width: 110, alignment: .leading).lineLimit(1)
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.blue.opacity(0.6))
                            .frame(width: geo.size.width * CGFloat(count) / CGFloat(maxCount))
                    }
                    .frame(height: 14)
                    Text("\(count)×").font(.caption.bold()).foregroundStyle(.blue)
                        .frame(width: 30, alignment: .trailing)
                }
            }
        }
    }
}

// MARK: - Anpassen View

struct MedAnalyseAnpassenView: View {
    @Binding var sektionen: [MedAnalyseSektion]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach($sektionen) { $sektion in
                    Label(sektion.rawValue, systemImage: sektion.symbol)
                }
                .onMove { sektionen.move(fromOffsets: $0, toOffset: $1) }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Sektionen anpassen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
