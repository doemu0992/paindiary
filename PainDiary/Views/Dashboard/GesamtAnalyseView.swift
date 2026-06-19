import SwiftUI
import Charts
import SwiftData

// MARK: - Persistence

private let kGesamtAnalyseSektionenKey = "gesamtAnalyseSektionen"

private func sektionenLaden() -> [GesamtAnalyseSektion] {
    guard let data = UserDefaults.standard.data(forKey: kGesamtAnalyseSektionenKey),
          let decoded = try? JSONDecoder().decode([GesamtAnalyseSektion].self, from: data)
    else { return GesamtAnalyseSektion.allCases }
    let decoded2 = decoded.filter { GesamtAnalyseSektion.allCases.contains($0) }
    let missing = GesamtAnalyseSektion.allCases.filter { !decoded2.contains($0) }
    return decoded2 + missing
}

private func sektionenSpeichern(_ s: [GesamtAnalyseSektion]) {
    if let data = try? JSONEncoder().encode(s) {
        UserDefaults.standard.set(data, forKey: kGesamtAnalyseSektionenKey)
    }
}

// MARK: - Sections Enum

enum GesamtAnalyseSektion: String, CaseIterable, Codable, Identifiable {
    case schmerzUebersicht = "Schmerzüberblick"
    case modulTimeline     = "Modul-Aktivität"
    case migraeneSchmerz   = "Migräne & Schmerz"
    case zyklusSchmerz     = "Zyklus & Schmerz"
    case rheumaSchmerz     = "Rheuma & Schmerz"
    case diabetesSchmerz   = "Diabetes & Schmerz"
    case hautWohlbefinden  = "Haut & Wohlbefinden"
    case kiInsicht         = "KI-Gesamteinblick"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .schmerzUebersicht: return "waveform.path.ecg"
        case .modulTimeline:     return "calendar.badge.clock"
        case .migraeneSchmerz:   return "brain.head.profile"
        case .zyklusSchmerz:     return "drop.fill"
        case .rheumaSchmerz:     return "figure.arms.open"
        case .diabetesSchmerz:   return "drop.triangle.fill"
        case .hautWohlbefinden:  return "bandage.fill"
        case .kiInsicht:         return "sparkles"
        }
    }

    var tint: Color {
        switch self {
        case .schmerzUebersicht: return .red
        case .modulTimeline:     return .indigo
        case .migraeneSchmerz:   return .purple
        case .zyklusSchmerz:     return .pink
        case .rheumaSchmerz:     return .teal
        case .diabetesSchmerz:   return .blue
        case .hautWohlbefinden:  return .orange
        case .kiInsicht:         return .indigo
        }
    }
}

// MARK: - Main View

struct GesamtAnalyseView: View {
    let eintraege: [PainEntry]
    let migraeneAnfaelle: [MigraeneEintrag]
    @Query(sort: \ZyklusEintrag.datum, order: .reverse) private var zyklusEintraege: [ZyklusEintrag]
    let blutzuckerMessungen: [BlutzuckerEintrag]
    let haqEintraege: [HAQEintrag]

    @Environment(\.dismiss) private var dismiss
    @State private var zeitraum: Zeitraum = .monat
    @State private var sektionen: [GesamtAnalyseSektion] = sektionenLaden()
    @State private var zeigeAnpassen = false

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

    // MARK: - Filtered Data

    private var gefilterteEintraege: [PainEntry] {
        guard let tage = zeitraum.tage else { return eintraege }
        let grenze = Calendar.current.date(byAdding: .day, value: -tage, to: Date()) ?? Date()
        return eintraege.filter { $0.datum >= grenze }
    }

    private var schmerzEintraege: [PainEntry] {
        gefilterteEintraege.filter { !$0.istHautEintrag && $0.koerperstelle != "Rheuma" }
    }

    private var rheumaEintraege: [PainEntry] {
        gefilterteEintraege.filter { $0.koerperstelle == "Rheuma" }
    }

    private var hautEintraege: [PainEntry] {
        gefilterteEintraege.filter { $0.istHautEintrag }
    }

    private var gefilterteMigraene: [MigraeneEintrag] {
        guard let tage = zeitraum.tage else { return migraeneAnfaelle }
        let grenze = Calendar.current.date(byAdding: .day, value: -tage, to: Date()) ?? Date()
        return migraeneAnfaelle.filter { $0.datum >= grenze }
    }

    private var gefilterteBlutzucker: [BlutzuckerEintrag] {
        guard let tage = zeitraum.tage else { return blutzuckerMessungen }
        let grenze = Calendar.current.date(byAdding: .day, value: -tage, to: Date()) ?? Date()
        return blutzuckerMessungen.filter { $0.datum >= grenze }
    }

    private var gefilterteZyklus: [ZyklusEintrag] {
        guard let tage = zeitraum.tage else { return zyklusEintraege }
        let grenze = Calendar.current.date(byAdding: .day, value: -tage, to: Date()) ?? Date()
        return zyklusEintraege.filter { $0.datum >= grenze }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("Zeitraum", selection: $zeitraum) {
                        ForEach(Zeitraum.allCases, id: \.self) { z in
                            Text(z.rawValue).tag(z)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 4)

                    ForEach(sektionen) { sektion in
                        sektionView(sektion)
                    }

                    Spacer(minLength: 24)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Gesamtanalyse")
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
                GesamtAnalyseAnpassenView(sektionen: $sektionen)
            }
            .onChange(of: sektionen) { _, new in sektionenSpeichern(new) }
        }
    }
}

// MARK: - Section Views

extension GesamtAnalyseView {

    // MARK: Dispatcher

    @ViewBuilder
    private func sektionView(_ sektion: GesamtAnalyseSektion) -> some View {
        switch sektion {
        case .schmerzUebersicht: schmerzUebersichtKarte
        case .modulTimeline:     modulTimelineKarte
        case .migraeneSchmerz:   migraeneSchmerzKarte
        case .zyklusSchmerz:     zyklusSchmerzKarte
        case .rheumaSchmerz:     rheumaSchmerzKarte
        case .diabetesSchmerz:   diabetesSchmerzKarte
        case .hautWohlbefinden:  hautWohlbefindenKarte
        case .kiInsicht:
            karte {
                KIAnalyseKarte(prompt: kiPrompt, modulTint: .indigo)
            }
        }
    }

    // MARK: Card Wrapper

    private func karte<Content: View>(@ViewBuilder inhalt: () -> Content) -> some View {
        inhalt()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
    }

    // MARK: Stat Pill

    private func statPill(_ wert: String, label: String, farbe: Color) -> some View {
        VStack(spacing: 4) {
            Text(wert).font(.title2.bold()).foregroundStyle(farbe)
            Text(label).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Schmerzüberblick

    private var schmerzUebersichtKarte: some View {
        karte {
            VStack(alignment: .leading, spacing: 12) {
                Label("Schmerzüberblick", systemImage: "waveform.path.ecg")
                    .font(.headline).foregroundStyle(.red)
                Divider()

                let alleSchmerzEintraege = schmerzEintraege + rheumaEintraege
                let avgSchmerz: Double = alleSchmerzEintraege.isEmpty ? 0 :
                    Double(alleSchmerzEintraege.map { $0.schmerzstaerke }.reduce(0, +)) / Double(alleSchmerzEintraege.count)
                let migraeneAnzahl = gefilterteMigraene.count
                let schmerztage = Set(alleSchmerzEintraege.map { Calendar.current.startOfDay(for: $0.datum) })
                    .union(Set(gefilterteMigraene.map { Calendar.current.startOfDay(for: $0.datum) }))
                    .count

                HStack(spacing: 0) {
                    statPill(
                        alleSchmerzEintraege.isEmpty ? "–" : String(format: "%.1f", avgSchmerz),
                        label: "Ø Schmerz",
                        farbe: avgSchmerz > 6 ? .red : avgSchmerz > 3 ? .orange : .green
                    )
                    Divider().frame(height: 40)
                    statPill("\(migraeneAnzahl)", label: "Migräne", farbe: .purple)
                    Divider().frame(height: 40)
                    statPill("\(schmerztage)", label: "Schmerztage", farbe: .secondary)
                }

                if !alleSchmerzEintraege.isEmpty || !gefilterteMigraene.isEmpty {
                    schmerzVerlaufChart(alleSchmerzEintraege: alleSchmerzEintraege)
                } else {
                    Text("Keine Schmerzdaten im Zeitraum")
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                }
            }
        }
    }

    @ViewBuilder
    private func schmerzVerlaufChart(alleSchmerzEintraege: [PainEntry]) -> some View {
        let punkte = berechneTagesPunkte(aus: alleSchmerzEintraege)
        let cal = Calendar.current
        let migraeneCopy = gefilterteMigraene
        let zeitraumCopy = zeitraum

        Chart {
            ForEach(punkte, id: \.datum) { p in
                AreaMark(
                    x: .value("Tag", p.datum),
                    y: .value("Schmerz", p.wert)
                )
                .foregroundStyle(Color.red.opacity(0.1))
                .interpolationMethod(.catmullRom)
                LineMark(
                    x: .value("Tag", p.datum),
                    y: .value("Schmerz", p.wert)
                )
                .foregroundStyle(Color.red)
                .interpolationMethod(.catmullRom)
            }
            ForEach(migraeneCopy, id: \.datum) { m in
                PointMark(
                    x: .value("Tag", cal.startOfDay(for: m.datum)),
                    y: .value("Stärke", Double(m.staerke))
                )
                .foregroundStyle(Color.purple)
                .symbolSize(40)
            }
        }
        .chartYScale(domain: 0...10)
        .chartXAxis {
            AxisMarks(values: .stride(
                by: zeitraumCopy == .woche ? .day : zeitraumCopy == .monat ? .weekOfYear : .month
            )) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(
                    format: zeitraumCopy == .woche
                        ? .dateTime.day()
                        : zeitraumCopy == .monat
                            ? .dateTime.day()
                            : .dateTime.month(.abbreviated)
                )
            }
        }
        .frame(height: 140)
        .padding(.top, 8)
    }

    // MARK: Modul-Aktivität

    private var modulTimelineKarte: some View {
        karte {
            VStack(alignment: .leading, spacing: 12) {
                Label("Modul-Aktivität", systemImage: "calendar.badge.clock")
                    .font(.headline).foregroundStyle(.indigo)
                Divider()
                Text("Aktive Module in den letzten 14 Tagen")
                    .font(.caption).foregroundStyle(.secondary)

                let cal = Calendar.current
                let heute = cal.startOfDay(for: Date())
                let letzten14: [Date] = (0..<14)
                    .compactMap { cal.date(byAdding: .day, value: -(13 - $0), to: heute) }

                HStack(spacing: 0) {
                    Text("").frame(width: 70)
                    ForEach(Array(letzten14.enumerated()), id: \.offset) { _, tag in
                        let wt = cal.component(.weekday, from: tag)
                        let wtStr = ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"][wt - 1]
                        Text(wtStr)
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }

                let eintraegeRef = eintraege
                let migraeneRef = migraeneAnfaelle
                let bwRef = blutzuckerMessungen
                let zyklusRef = zyklusEintraege

                let module: [(name: String, farbe: Color, hatDaten: (Date) -> Bool)] = [
                    ("Schmerz", .red, { tag in
                        eintraegeRef.contains { !$0.istHautEintrag && $0.koerperstelle != "Rheuma" && cal.startOfDay(for: $0.datum) == tag }
                    }),
                    ("Rheuma", .teal, { tag in
                        eintraegeRef.contains { $0.koerperstelle == "Rheuma" && cal.startOfDay(for: $0.datum) == tag }
                    }),
                    ("Migräne", .purple, { tag in
                        migraeneRef.contains { cal.startOfDay(for: $0.datum) == tag }
                    }),
                    ("Haut", .orange, { tag in
                        eintraegeRef.contains { $0.istHautEintrag && cal.startOfDay(for: $0.datum) == tag }
                    }),
                    ("Diabetes", .blue, { tag in
                        bwRef.contains { cal.startOfDay(for: $0.datum) == tag }
                    }),
                    ("Zyklus", .pink, { tag in
                        zyklusRef.contains { cal.startOfDay(for: $0.datum) == tag }
                    }),
                ]

                ForEach(module, id: \.name) { modul in
                    HStack(spacing: 0) {
                        Text(modul.name)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 70, alignment: .leading)
                        ForEach(Array(letzten14.enumerated()), id: \.offset) { _, tag in
                            Circle()
                                .fill(modul.hatDaten(tag) ? modul.farbe : Color(.systemGray5))
                                .frame(width: 10, height: 10)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    // MARK: Migräne & Schmerz

    private var migraeneSchmerzKarte: some View {
        karte {
            VStack(alignment: .leading, spacing: 12) {
                Label("Migräne & Schmerz", systemImage: "brain.head.profile")
                    .font(.headline).foregroundStyle(.purple)
                Divider()

                if gefilterteMigraene.isEmpty {
                    Text("Keine Migräne-Daten im Zeitraum")
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                } else {
                    let cal = Calendar.current
                    let migraeneTage = Set(gefilterteMigraene.map { cal.startOfDay(for: $0.datum) })
                    let alleSchmerz = schmerzEintraege + rheumaEintraege

                    let anMigraeneTagen = alleSchmerz.filter { migraeneTage.contains(cal.startOfDay(for: $0.datum)) }
                    let ohneMigraene = alleSchmerz.filter { !migraeneTage.contains(cal.startOfDay(for: $0.datum)) }

                    let avgMitMigraene: Double = anMigraeneTagen.isEmpty ? 0 :
                        Double(anMigraeneTagen.map { $0.schmerzstaerke }.reduce(0, +)) / Double(anMigraeneTagen.count)
                    let avgOhneMigraene: Double = ohneMigraene.isEmpty ? 0 :
                        Double(ohneMigraene.map { $0.schmerzstaerke }.reduce(0, +)) / Double(ohneMigraene.count)
                    let avgMigraeneStaerke: Double = Double(gefilterteMigraene.map { $0.staerke }.reduce(0, +)) / Double(gefilterteMigraene.count)

                    HStack(spacing: 0) {
                        statPill(
                            anMigraeneTagen.isEmpty ? "–" : String(format: "%.1f", avgMitMigraene),
                            label: "Schmerz bei\nMigräne",
                            farbe: .red
                        )
                        Divider().frame(height: 40)
                        statPill(
                            ohneMigraene.isEmpty ? "–" : String(format: "%.1f", avgOhneMigraene),
                            label: "Schmerz\nohne Migräne",
                            farbe: .secondary
                        )
                        Divider().frame(height: 40)
                        statPill(
                            String(format: "%.1f", avgMigraeneStaerke),
                            label: "Ø Migräne-\nStärke",
                            farbe: .purple
                        )
                    }

                    if !anMigraeneTagen.isEmpty || !ohneMigraene.isEmpty {
                        let vergleich: [(label: String, wert: Double, farbe: Color)] = [
                            ("Mit Migräne", avgMitMigraene, .red),
                            ("Ohne Migräne", avgOhneMigraene, .secondary),
                        ]
                        Chart(vergleich, id: \.label) { item in
                            BarMark(x: .value("Kategorie", item.label), y: .value("Ø Schmerz", item.wert))
                                .foregroundStyle(item.farbe)
                                .cornerRadius(6)
                            RuleMark(y: .value("Max", 10)).foregroundStyle(.clear)
                        }
                        .chartYScale(domain: 0...10)
                        .frame(height: 100)
                        .padding(.top, 8)
                    }

                    Text("\(gefilterteMigraene.count) Migräne-Anfälle · \(migraeneTage.count) betroffene Tage")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Zyklus & Schmerz

    private var zyklusSchmerzKarte: some View {
        karte {
            VStack(alignment: .leading, spacing: 12) {
                Label("Zyklus & Schmerz", systemImage: "drop.fill")
                    .font(.headline).foregroundStyle(.pink)
                Divider()

                if gefilterteZyklus.isEmpty {
                    Text("Keine Zyklus-Daten im Zeitraum")
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                } else {
                    let analyse = ZyklusRechner.analyse(eintraege: gefilterteZyklus)
                    let cal = Calendar.current
                    let alleSchmerz = schmerzEintraege + rheumaEintraege
                    let istPeriodeTage = Set(gefilterteZyklus.filter { $0.istPeriode }.map { cal.startOfDay(for: $0.datum) })
                    let phasenDaten = berechnePhasenDaten(alleSchmerz: alleSchmerz, istPeriodeTage: istPeriodeTage, analyse: analyse, cal: cal)
                    let schmerzProPhase = phasenDaten.schmerzProPhase
                    let migraeneProPhase = phasenDaten.migraeneProPhase
                    let phasen = ["Menstruation", "Fruchtbar", "Eisprung", "Sonstige"]

                    let chartDaten = phasen.map { p -> (phase: String, avg: Double, migraene: Int) in
                        let werte = schmerzProPhase[p] ?? []
                        let avg = werte.isEmpty ? 0 : Double(werte.reduce(0, +)) / Double(werte.count)
                        return (p, avg, migraeneProPhase[p] ?? 0)
                    }

                    Chart {
                        ForEach(chartDaten, id: \.phase) { item in
                            BarMark(
                                x: .value("Phase", item.phase),
                                y: .value("Ø Schmerz", item.avg)
                            )
                            .foregroundStyle(Color.red.opacity(0.7))
                            .cornerRadius(6)
                            if item.migraene > 0 {
                                PointMark(
                                    x: .value("Phase", item.phase),
                                    y: .value("Migräne", Double(item.migraene))
                                )
                                .foregroundStyle(Color.purple)
                                .symbolSize(60)
                            }
                            RuleMark(y: .value("Max", 10)).foregroundStyle(.clear)
                        }
                    }
                    .chartYScale(domain: 0...10)
                    .frame(height: 120)

                    if let staerkstePhase = chartDaten.max(by: { $0.avg < $1.avg }), staerkstePhase.avg > 0 {
                        Text("Stärkster Schmerz in: \(staerkstePhase.phase) (\(String(format: "%.1f", staerkstePhase.avg)) Ø)")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    if let meisteMigraene = chartDaten.max(by: { $0.migraene < $1.migraene }), meisteMigraene.migraene > 0 {
                        Text("Meiste Migräne: \(meisteMigraene.phase) (\(meisteMigraene.migraene) Anfälle)")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: Rheuma & Schmerz

    private var rheumaSchmerzKarte: some View {
        karte {
            VStack(alignment: .leading, spacing: 12) {
                Label("Rheuma & Schmerz", systemImage: "figure.arms.open")
                    .font(.headline).foregroundStyle(.teal)
                Divider()

                if rheumaEintraege.isEmpty {
                    Text("Keine Rheuma-Daten im Zeitraum")
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                } else {
                    let cal = Calendar.current
                    let schubTage = Set(rheumaEintraege.filter { $0.istSchub }.map { cal.startOfDay(for: $0.datum) })
                    let alleSchmerz = schmerzEintraege + rheumaEintraege

                    let anSchubTagen = alleSchmerz.filter { schubTage.contains(cal.startOfDay(for: $0.datum)) }
                    let ohneSchub = alleSchmerz.filter { !schubTage.contains(cal.startOfDay(for: $0.datum)) }

                    let avgSchub: Double = anSchubTagen.isEmpty ? 0 :
                        Double(anSchubTagen.map { $0.schmerzstaerke }.reduce(0, +)) / Double(anSchubTagen.count)
                    let avgNormal: Double = ohneSchub.isEmpty ? 0 :
                        Double(ohneSchub.map { $0.schmerzstaerke }.reduce(0, +)) / Double(ohneSchub.count)

                    HStack(spacing: 0) {
                        statPill(
                            anSchubTagen.isEmpty ? "–" : String(format: "%.1f", avgSchub),
                            label: "Schmerz\nan Schub-Tagen",
                            farbe: .red
                        )
                        Divider().frame(height: 40)
                        statPill(
                            ohneSchub.isEmpty ? "–" : String(format: "%.1f", avgNormal),
                            label: "Schmerz\nnormale Tage",
                            farbe: .secondary
                        )
                        Divider().frame(height: 40)
                        statPill("\(schubTage.count)", label: "Schübe\nim Zeitraum", farbe: .teal)
                    }

                    if !anSchubTagen.isEmpty || !ohneSchub.isEmpty {
                        let vergleich: [(label: String, wert: Double, farbe: Color)] = [
                            ("Schub", avgSchub, .red),
                            ("Kein Schub", avgNormal, Color.teal.opacity(0.6)),
                        ]
                        Chart(vergleich, id: \.label) { item in
                            BarMark(x: .value("Kategorie", item.label), y: .value("Ø Schmerz", item.wert))
                                .foregroundStyle(item.farbe)
                                .cornerRadius(6)
                            RuleMark(y: .value("Max", 10)).foregroundStyle(.clear)
                        }
                        .chartYScale(domain: 0...10)
                        .frame(height: 100)
                        .padding(.top, 8)
                    }
                }
            }
        }
    }

    // MARK: Diabetes & Schmerz

    private var diabetesSchmerzKarte: some View {
        karte {
            VStack(alignment: .leading, spacing: 12) {
                Label("Diabetes & Schmerz", systemImage: "drop.triangle.fill")
                    .font(.headline).foregroundStyle(.blue)
                Divider()

                if gefilterteBlutzucker.isEmpty {
                    Text("Keine Blutzucker-Daten im Zeitraum")
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                } else {
                    let cal = Calendar.current
                    let alleSchmerz = schmerzEintraege + rheumaEintraege
                    let bzTage = berechneBZTage(cal: cal)
                    let hypoTage = bzTage.hypo
                    let normalTage = bzTage.normal
                    let erhoehtTage = bzTage.erhoehte

                    let avgHypo = avgSchmerzAn(tagen: hypoTage, alleSchmerz: alleSchmerz, cal: cal)
                    let avgNormal = avgSchmerzAn(tagen: normalTage, alleSchmerz: alleSchmerz, cal: cal)
                    let avgErh = avgSchmerzAn(tagen: erhoehtTage, alleSchmerz: alleSchmerz, cal: cal)

                    HStack(spacing: 0) {
                        statPill(
                            hypoTage.isEmpty ? "–" : String(format: "%.1f", avgHypo),
                            label: "Hypo\n(<3.9)",
                            farbe: .orange
                        )
                        Divider().frame(height: 40)
                        statPill(
                            normalTage.isEmpty ? "–" : String(format: "%.1f", avgNormal),
                            label: "Normal\n(3.9–7.8)",
                            farbe: .green
                        )
                        Divider().frame(height: 40)
                        statPill(
                            erhoehtTage.isEmpty ? "–" : String(format: "%.1f", avgErh),
                            label: "Erhöht\n(>7.8)",
                            farbe: .red
                        )
                    }

                    let vergleich: [(label: String, wert: Double, farbe: Color)] = [
                        ("Hypo", avgHypo, .orange),
                        ("Normal", avgNormal, .green),
                        ("Erhöht", avgErh, .red),
                    ]

                    let gefiltertVergleich = vergleich.filter { $0.wert > 0 }
                    if !gefiltertVergleich.isEmpty {
                        Chart(gefiltertVergleich, id: \.label) { item in
                            BarMark(x: .value("BZ-Bereich", item.label), y: .value("Ø Schmerz", item.wert))
                                .foregroundStyle(item.farbe)
                                .cornerRadius(6)
                            RuleMark(y: .value("Max", 10)).foregroundStyle(.clear)
                        }
                        .chartYScale(domain: 0...10)
                        .frame(height: 100)
                        .padding(.top, 8)
                    }
                }
            }
        }
    }

    // MARK: Haut & Wohlbefinden

    private var hautWohlbefindenKarte: some View {
        karte {
            VStack(alignment: .leading, spacing: 12) {
                Label("Haut & Wohlbefinden", systemImage: "bandage.fill")
                    .font(.headline).foregroundStyle(.orange)
                Divider()

                if hautEintraege.isEmpty {
                    Text("Keine Haut-Daten im Zeitraum")
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                } else {
                    let cal = Calendar.current
                    let hautTage = Set(hautEintraege.map { cal.startOfDay(for: $0.datum) })
                    let andereEintraege = gefilterteEintraege.filter { !$0.istHautEintrag }

                    let stressHaut: Double = hautEintraege.isEmpty ? 0 :
                        Double(hautEintraege.map { $0.stressLevel }.reduce(0, +)) / Double(hautEintraege.count)
                    let stressAndere: Double = andereEintraege.isEmpty ? 0 :
                        Double(andereEintraege.map { $0.stressLevel }.reduce(0, +)) / Double(andereEintraege.count)
                    let stimmungHaut: Double = hautEintraege.isEmpty ? 0 :
                        Double(hautEintraege.map { $0.stimmung }.reduce(0, +)) / Double(hautEintraege.count)
                    let stimmungAndere: Double = andereEintraege.isEmpty ? 0 :
                        Double(andereEintraege.map { $0.stimmung }.reduce(0, +)) / Double(andereEintraege.count)

                    HStack(spacing: 0) {
                        statPill(String(format: "%.1f", stressHaut), label: "Stress\nHaut-Tage", farbe: .orange)
                        Divider().frame(height: 40)
                        statPill(
                            andereEintraege.isEmpty ? "–" : String(format: "%.1f", stressAndere),
                            label: "Stress\nandere Tage",
                            farbe: .secondary
                        )
                        Divider().frame(height: 40)
                        statPill("\(hautTage.count)", label: "Haut-Tage", farbe: .orange)
                    }

                    HStack(spacing: 0) {
                        statPill(
                            String(format: "%.1f", stimmungHaut),
                            label: "Stimmung\nHaut-Tage",
                            farbe: stimmungHaut < 3 ? .orange : .green
                        )
                        Divider().frame(height: 40)
                        statPill(
                            andereEintraege.isEmpty ? "–" : String(format: "%.1f", stimmungAndere),
                            label: "Stimmung\nandere Tage",
                            farbe: .secondary
                        )
                        Divider().frame(height: 40)
                        statPill("", label: "", farbe: .clear)
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    // MARK: KI Prompt

    private var kiPrompt: String {
        let alleSchmerz = schmerzEintraege + rheumaEintraege
        let avgSchmerz: Double = alleSchmerz.isEmpty ? 0 :
            Double(alleSchmerz.map { $0.schmerzstaerke }.reduce(0, +)) / Double(alleSchmerz.count)

        return """
        Gesamtanalyse PainDiary (\(zeitraum.rawValue)):
        - Schmerzeinträge: \(alleSchmerz.count), Ø Stärke: \(String(format: "%.1f", avgSchmerz))/10
        - Rheuma-Schübe: \(rheumaEintraege.filter { $0.istSchub }.count)
        - Migräne-Anfälle: \(gefilterteMigraene.count)
        - Haut-Einträge: \(hautEintraege.count)
        - Blutzucker-Messungen: \(gefilterteBlutzucker.count)
        - Zyklus-Einträge: \(gefilterteZyklus.count)
        Analysiere die Zusammenhänge zwischen den Modulen und gib 3–4 kurze Einblicke auf Deutsch.
        """
    }
}

// MARK: - Helpers

extension GesamtAnalyseView {
    private func berechneTagesPunkte(aus eintraege: [PainEntry]) -> [(datum: Date, wert: Double)] {
        let cal = Calendar.current
        var tageDaten: [Date: [Int]] = [:]
        for e in eintraege {
            let tag = cal.startOfDay(for: e.datum)
            tageDaten[tag, default: []].append(e.schmerzstaerke)
        }
        return tageDaten
            .map { (datum: $0.key, wert: Double($0.value.reduce(0, +)) / Double($0.value.count)) }
            .sorted { $0.datum < $1.datum }
    }

    private func zyklusPhase(fuer datum: Date, istPeriodeTage: Set<Date>, analyse: ZyklusAnalyse, cal: Calendar) -> String {
        let tag = cal.startOfDay(for: datum)
        if istPeriodeTage.contains(tag) { return "Menstruation" }
        if analyse.ovulationsTageSet.contains(tag) { return "Eisprung" }
        if analyse.fruchtbareTageSet.contains(tag) { return "Fruchtbar" }
        return "Sonstige"
    }

    private func berechnePhasenDaten(
        alleSchmerz: [PainEntry],
        istPeriodeTage: Set<Date>,
        analyse: ZyklusAnalyse,
        cal: Calendar
    ) -> (schmerzProPhase: [String: [Int]], migraeneProPhase: [String: Int]) {
        var schmerzProPhase: [String: [Int]] = [:]
        var migraeneProPhase: [String: Int] = [:]
        for e in alleSchmerz {
            let p = zyklusPhase(fuer: e.datum, istPeriodeTage: istPeriodeTage, analyse: analyse, cal: cal)
            schmerzProPhase[p, default: []].append(e.schmerzstaerke)
        }
        for m in gefilterteMigraene {
            let p = zyklusPhase(fuer: m.datum, istPeriodeTage: istPeriodeTage, analyse: analyse, cal: cal)
            migraeneProPhase[p, default: 0] += 1
        }
        return (schmerzProPhase, migraeneProPhase)
    }

    private func berechneBZTage(cal: Calendar) -> (hypo: Set<Date>, normal: Set<Date>, erhoehte: Set<Date>) {
        var hypo = Set<Date>()
        var normal = Set<Date>()
        var erhoehte = Set<Date>()
        for b in gefilterteBlutzucker {
            let tag = cal.startOfDay(for: b.datum)
            if b.wert < 3.9 { hypo.insert(tag) }
            else if b.wert <= 7.8 { normal.insert(tag) }
            else { erhoehte.insert(tag) }
        }
        return (hypo, normal, erhoehte)
    }

    private func avgSchmerzAn(tagen: Set<Date>, alleSchmerz: [PainEntry], cal: Calendar) -> Double {
        let eintr = alleSchmerz.filter { tagen.contains(cal.startOfDay(for: $0.datum)) }
        guard !eintr.isEmpty else { return 0 }
        return Double(eintr.map { $0.schmerzstaerke }.reduce(0, +)) / Double(eintr.count)
    }
}

// MARK: - AnpassenView

private struct GesamtAnalyseAnpassenView: View {
    @Binding var sektionen: [GesamtAnalyseSektion]
    @Environment(\.dismiss) private var dismiss
    @State private var editMode: EditMode = .active

    var body: some View {
        NavigationStack {
            List {
                ForEach(sektionen) { sektion in
                    HStack(spacing: 12) {
                        Image(systemName: sektion.symbol)
                            .foregroundStyle(sektion.tint)
                            .frame(width: 24)
                        Text(sektion.rawValue).font(.subheadline)
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
