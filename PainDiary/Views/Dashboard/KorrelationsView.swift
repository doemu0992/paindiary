import SwiftUI
import SwiftData
import Charts

struct KorrelationsView: View {
    @Query(sort: \PainEntry.datum, order: .reverse) private var eintraege: [PainEntry]
    @Query(sort: \ZyklusEintrag.datum, order: .reverse) private var zyklusEintraege: [ZyklusEintrag]
    @Query(sort: \EinnahmeLog.datum, order: .reverse) private var einnahmeLogs: [EinnahmeLog]
    @Query(filter: #Predicate<Dauermedikation> { $0.aktiv }) private var dauermedikationen: [Dauermedikation]
    @Query(sort: \Dauermedikation.name) private var alleDauermedikationen: [Dauermedikation]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if eintraege.count < 5 {
                    ContentUnavailableView(
                        "Zu wenig Daten",
                        systemImage: "chart.xyaxis.line",
                        description: Text("Erfasse mindestens 5 Einträge um Analysen zu sehen.")
                    )
                } else {
                    erkenntnisseKarte

                    abschnittTitel("Schmerzmuster")
                    wochentagChart
                    ausloeserChart
                    koerperstellenChart
                    schmerzartChart

                    abschnittTitel("Körper & Geist")
                    schlafSchmerzChart
                    stressSchmerzChart
                    stimmungSchmerzChart
                    begleiterscheinungenChart
                    massnahmenChart

                    abschnittTitel("Ernährung & Wetter")
                    koffeinSchmerzChart
                    wetterSchmerzChart

                    if !zyklusEintraege.isEmpty {
                        abschnittTitel("Zyklus")
                        zyklusSchmerzChart
                    }

                    if !einnahmeLogs.isEmpty || !medAnalysen.isEmpty || !wöchentlicheMedikamente.isEmpty {
                        abschnittTitel("Medikamente")
                        if !einnahmeLogs.isEmpty { medikamentEffektChart }
                        if !bedarfsTrendDaten.isEmpty { bedarfsTrendChart }
                        if !wirksamkeitDaten.isEmpty { wirksamkeitsChart }
                        injektionsZyklusChart
                        ForEach(medAnalysen) { analyse in
                            dauermedikamentKarte(analyse)
                        }
                    }
                }
            }
            .padding()
            .padding(.bottom, 20)
        }
        .navigationTitle("Analysen")
        .navigationBarTitleDisplayMode(.large)
    }

    private func abschnittTitel(_ titel: String) -> some View {
        HStack {
            Text(titel).font(.title3.bold())
            Spacer()
        }
        .padding(.top, 4)
    }

    // MARK: - Erkenntnisse

    private struct Erkenntnis: Identifiable {
        let id = UUID()
        let text: String
        let symbol: String
        let farbe: Color
    }

    private var alleErkenntnisse: [Erkenntnis] {
        var liste: [Erkenntnis] = []

        // Wochentag mit höchstem / niedrigstem Schmerz
        if let worst = wochentagDaten.max(by: { $0.schmerz < $1.schmerz }),
           let best  = wochentagDaten.min(by: { $0.schmerz < $1.schmerz }),
           worst.schmerz - best.schmerz > 0.5 {
            liste.append(Erkenntnis(
                text: "Am \(worst.tag) ist dein Schmerz am höchsten (Ø \(fmt(worst.schmerz))/10), am \(best.tag) am niedrigsten (Ø \(fmt(best.schmerz))/10)",
                symbol: "calendar", farbe: .orange))
        }

        // Schlaf
        let wenigSchlaf = schlafDaten.filter { $0.schlaf < 6 }
        let vielSchlaf  = schlafDaten.filter { $0.schlaf >= 7 }
        if wenigSchlaf.count >= 3 && vielSchlaf.count >= 3 {
            let dWenig = wenigSchlaf.map(\.schmerz).reduce(0,+) / Double(wenigSchlaf.count)
            let dViel  = vielSchlaf.map(\.schmerz).reduce(0,+)  / Double(vielSchlaf.count)
            let diff = dWenig - dViel
            if abs(diff) > 0.4 {
                liste.append(Erkenntnis(
                    text: "Bei <6h Schlaf ist dein Schmerz Ø \(fmt(abs(diff))) Punkte \(diff > 0 ? "höher" : "niedriger") als bei ≥7h",
                    symbol: "moon.zzz.fill", farbe: .indigo))
            }
        }

        // Stress
        let stressHoch    = eintraege.filter { $0.stressLevel >= 4 }
        let stressNiedrig = eintraege.filter { $0.stressLevel <= 2 }
        if stressHoch.count >= 3 && stressNiedrig.count >= 3 {
            let aH = Double(stressHoch.map(\.schmerzstaerke).reduce(0,+))    / Double(stressHoch.count)
            let aN = Double(stressNiedrig.map(\.schmerzstaerke).reduce(0,+)) / Double(stressNiedrig.count)
            let diff = aH - aN
            if abs(diff) > 0.5 {
                liste.append(Erkenntnis(
                    text: "Hoher Stress (4–5) geht mit Ø \(fmt(abs(diff))) Punkten \(diff > 0 ? "mehr" : "weniger") Schmerz einher",
                    symbol: "bolt.fill", farbe: .red))
            }
        }

        // Häufigster Auslöser
        let ausloeserListe = eintraege.compactMap { $0.ausloeser.isEmpty ? nil : $0.ausloeser }
        if !ausloeserListe.isEmpty,
           let top = Dictionary(ausloeserListe.map { ($0, 1) }, uniquingKeysWith: +).max(by: { $0.value < $1.value }) {
            let pct = Int(round(Double(top.value) / Double(eintraege.count) * 100))
            liste.append(Erkenntnis(
                text: "\"\(top.key)\" ist dein häufigster Auslöser - tritt in \(pct)% der Einträge auf",
                symbol: "exclamationmark.triangle.fill", farbe: .orange))
        }

        // Koffein
        let kHoch  = koffeinDaten.filter { $0.koffein >= 3 }
        let kKeine = koffeinDaten.filter { $0.koffein == 0 }
        if kHoch.count >= 3 && kKeine.count >= 3 {
            let aH = kHoch.map(\.schmerz).reduce(0,+)  / Double(kHoch.count)
            let aK = kKeine.map(\.schmerz).reduce(0,+) / Double(kKeine.count)
            let diff = aH - aK
            if abs(diff) > 0.5 {
                liste.append(Erkenntnis(
                    text: "Nach 3+ Tassen Koffein ist der Folgetag-Schmerz Ø \(fmt(abs(diff))) Punkte \(diff > 0 ? "höher" : "niedriger")",
                    symbol: "cup.and.saucer.fill", farbe: Color(red: 0.55, green: 0.35, blue: 0.15)))
            }
        }

        // Häufigste Körperstelle
        if let topOrt = koerperstellenDaten.first, topOrt.anzahl >= 3 {
            let pct = Int(round(Double(topOrt.anzahl) / Double(eintraege.count) * 100))
            liste.append(Erkenntnis(
                text: "\"\(topOrt.ort)\" ist deine häufigste Schmerzregion – \(pct)% der Einträge (Ø \(fmt(topOrt.avgSchmerz))/10)",
                symbol: "figure.body", farbe: .blue))
        }

        // Häufigste Begleiterscheinung
        if let topBeg = begleitDaten.first, topBeg.anzahl >= 3 {
            let pct = Int(round(Double(topBeg.anzahl) / Double(eintraege.count) * 100))
            liste.append(Erkenntnis(
                text: "\"\(topBeg.symptom)\" kommt in \(pct)% der Einträge als Begleiterscheinung vor",
                symbol: "stethoscope", farbe: .teal))
        }

        // Zyklus
        if !zyklusPhasenDaten.isEmpty,
           let worst = zyklusPhasenDaten.max(by: { $0.schmerz < $1.schmerz }) {
            liste.append(Erkenntnis(
                text: "In der \(worst.phase) ist dein Schmerz am stärksten (Ø \(fmt(worst.schmerz))/10)",
                symbol: "drop.circle.fill", farbe: .pink))
        }

        // Medikament-Wirksamkeit / Einnahmetreue
        for a in medAnalysen {
            if let vor = a.schmerzVorStart, let nach = a.schmerzNachStart,
               a.nVor >= 3, a.nNach >= 5, vor - nach > 1.0 {
                liste.append(Erkenntnis(
                    text: "Seit \(a.med.name): Ø Schmerz von \(fmt(vor)) auf \(fmt(nach)) gesunken (−\(fmt(vor - nach)) Punkte)",
                    symbol: "arrow.down.circle.fill", farbe: .green))
                break
            }
            if a.einnahmetreue >= 0 && a.einnahmetreue < 0.70 {
                liste.append(Erkenntnis(
                    text: "\(a.med.name): Einnahmetreue \(Int(a.einnahmetreue * 100))% – regelmässige Einnahme kann die Wirksamkeit verbessern",
                    symbol: "pill.fill", farbe: .orange))
                break
            }
        }

        return Array(liste.prefix(4))
    }

    private var erkenntnisseKarte: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Deine Erkenntnisse", systemImage: "lightbulb.fill")
                .font(.headline).foregroundStyle(.yellow)

            if alleErkenntnisse.isEmpty {
                Text("Erfasse mehr Einträge um personalisierte Erkenntnisse zu erhalten.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(alleErkenntnisse) { e in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: e.symbol).font(.body)
                            .foregroundStyle(e.farbe).frame(width: 22)
                        Text(e.text).font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if e.id != alleErkenntnisse.last?.id { Divider() }
                }
            }
        }
        .padding()
        .background(Color.yellow.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.yellow.opacity(0.3), lineWidth: 1))
    }

    // MARK: - Wochentag

    private var wochentagDaten: [(tag: String, schmerz: Double)] {
        let reihenfolge: [(tag: String, weekday: Int)] = [
            ("Mo", 2), ("Di", 3), ("Mi", 4), ("Do", 5), ("Fr", 6), ("Sa", 7), ("So", 1)
        ]
        let kal = Calendar.current
        return reihenfolge.compactMap { element in
            let treffer = eintraege.filter { kal.component(.weekday, from: $0.datum) == element.weekday }
            guard !treffer.isEmpty else { return nil }
            let avg = Double(treffer.map(\.schmerzstaerke).reduce(0,+)) / Double(treffer.count)
            return (tag: element.tag, schmerz: avg)
        }
    }

    private var wochentagChart: some View {
        karte {
            Text("Schmerz nach Wochentag").font(.headline)
            Text("Ø Schmerzstärke pro Wochentag").font(.caption).foregroundStyle(.secondary)
            if wochentagDaten.isEmpty {
                Text("Nicht genug Daten.").font(.caption).foregroundStyle(.secondary)
            } else {
                Chart(wochentagDaten, id: \.tag) { p in
                    BarMark(x: .value("Tag", p.tag), y: .value("Schmerz", p.schmerz))
                        .foregroundStyle(SchmerzBadge.farbe(fuer: Int(p.schmerz)).gradient)
                        .cornerRadius(6)
                }
                .chartYScale(domain: 0...10)
                .chartYAxis { AxisMarks(values: [0, 2, 4, 6, 8, 10]) }
                .frame(height: 180)
            }
        }
    }

    // MARK: - Auslöser-Ranking

    private var topAusloeser: [(ausloeser: String, schmerz: Double, anzahl: Int)] {
        let mitAusloeser = eintraege.filter { !$0.ausloeser.isEmpty }
        guard !mitAusloeser.isEmpty else { return [] }
        return Dictionary(grouping: mitAusloeser, by: \.ausloeser)
            .map { key, items in
                let avg = Double(items.map(\.schmerzstaerke).reduce(0,+)) / Double(items.count)
                return (ausloeser: key, schmerz: avg, anzahl: items.count)
            }
            .sorted { $0.anzahl > $1.anzahl }
            .prefix(6).map { $0 }
    }

    private var ausloeserChart: some View {
        karte {
            Text("Auslöser-Ranking").font(.headline)
            Text("Top Auslöser nach Häufigkeit mit Ø Schmerz").font(.caption).foregroundStyle(.secondary)
            if topAusloeser.isEmpty {
                Text("Keine Auslöser erfasst. Trage Auslöser in deinen Einträgen ein.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Chart(topAusloeser, id: \.ausloeser) { item in
                    BarMark(
                        x: .value("Schmerz", item.schmerz),
                        y: .value("Auslöser", item.ausloeser)
                    )
                    .foregroundStyle(SchmerzBadge.farbe(fuer: Int(item.schmerz)).gradient)
                    .cornerRadius(6)
                    .annotation(position: .trailing) {
                        Text("×\(item.anzahl)").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .chartXScale(domain: 0...10)
                .chartXAxis { AxisMarks(values: [0, 2, 4, 6, 8, 10]) }
                .frame(height: CGFloat(topAusloeser.count * 44 + 20))
            }
        }
    }

    // MARK: - Schlaf ↔ Schmerz

    private var schlafDaten: [(schlaf: Double, schmerz: Double)] {
        eintraege.filter { $0.schlafStunden > 0 }
            .map { (schlaf: $0.schlafStunden, schmerz: Double($0.schmerzstaerke)) }
    }

    private var schlafSchmerzChart: some View {
        karte {
            Text("Schlaf ↔ Schmerz").font(.headline)
            Text("Weniger Schlaf = mehr Schmerz?").font(.caption).foregroundStyle(.secondary)
            if schlafDaten.count < 3 {
                Text("Nicht genug Daten. Aktiviere HealthKit oder trage Schlafstunden manuell ein.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Chart(schlafDaten, id: \.schlaf) { p in
                    PointMark(
                        x: .value("Schlaf (Std.)", p.schlaf),
                        y: .value("Schmerz", p.schmerz)
                    )
                    .foregroundStyle(SchmerzBadge.farbe(fuer: Int(p.schmerz)).opacity(0.8))
                    .symbolSize(60)
                }
                .chartXScale(domain: 0...12)
                .chartYScale(domain: 0...10)
                .chartXAxis {
                    AxisMarks(values: [0, 2, 4, 6, 8, 10, 12]) { v in
                        AxisValueLabel { if let d = v.as(Double.self) { Text("\(Int(d))h") } }
                    }
                }
                .frame(height: 180)
                korrBadge(korrelation(schlafDaten.map(\.schlaf), schlafDaten.map(\.schmerz)),
                          label: "Starke Korrelation: mehr Schlaf = weniger Schmerz")
            }
        }
    }

    // MARK: - Stress ↔ Schmerz

    private var stressPegelDaten: [(level: String, schmerz: Double, anzahl: Int)] {
        let labels = ["", "Sehr gering", "Gering", "Mittel", "Hoch", "Sehr hoch"]
        return (1...5).compactMap { level in
            let treffer = eintraege.filter { $0.stressLevel == level }
            guard !treffer.isEmpty else { return nil }
            let avg = Double(treffer.map(\.schmerzstaerke).reduce(0,+)) / Double(treffer.count)
            return (level: labels[level], schmerz: avg, anzahl: treffer.count)
        }
    }

    private var stressSchmerzChart: some View {
        karte {
            Text("Stress ↔ Schmerz").font(.headline)
            Text("Ø Schmerzstärke je Stresslevel (von links: sehr gering → sehr hoch)")
                .font(.caption).foregroundStyle(.secondary)
            if stressPegelDaten.count < 2 {
                Text("Nicht genug Daten für diese Analyse.").font(.caption).foregroundStyle(.secondary)
            } else {
                Chart(stressPegelDaten, id: \.level) { p in
                    BarMark(x: .value("Schmerz", p.schmerz), y: .value("Stress", p.level))
                        .foregroundStyle(Color.orange.gradient).cornerRadius(6)
                        .annotation(position: .trailing) {
                            Text(fmt(p.schmerz)).font(.caption2.bold()).foregroundStyle(.secondary)
                        }
                }
                .chartXScale(domain: 0...10)
                .frame(height: CGFloat(stressPegelDaten.count * 44 + 20))
                let nums = stressPegelDaten.enumerated().map { (Double($0.offset + 1), $0.element.schmerz) }
                korrBadge(korrelation(nums.map(\.0), nums.map(\.1)),
                          label: "Mehr Stress geht mit mehr Schmerz einher")
            }
        }
    }

    // MARK: - Stimmung ↔ Schmerz

    private var stimmungPegelDaten: [(level: String, schmerz: Double, anzahl: Int)] {
        let emojis = ["", "😞", "😕", "😐", "🙂", "😄"]
        return (1...5).compactMap { level in
            let treffer = eintraege.filter { $0.stimmung == level }
            guard !treffer.isEmpty else { return nil }
            let avg = Double(treffer.map(\.schmerzstaerke).reduce(0,+)) / Double(treffer.count)
            return (level: emojis[level], schmerz: avg, anzahl: treffer.count)
        }
    }

    private var stimmungSchmerzChart: some View {
        karte {
            Text("Stimmung ↔ Schmerz").font(.headline)
            Text("Ø Schmerzstärke je Stimmungslage (😞 schlecht → 😄 sehr gut)")
                .font(.caption).foregroundStyle(.secondary)
            if stimmungPegelDaten.count < 2 {
                Text("Nicht genug Daten für diese Analyse.").font(.caption).foregroundStyle(.secondary)
            } else {
                Chart(stimmungPegelDaten, id: \.level) { p in
                    BarMark(x: .value("Stimmung", p.level), y: .value("Schmerz", p.schmerz))
                        .foregroundStyle(Color.pink.gradient).cornerRadius(6)
                        .annotation(position: .top) {
                            Text(fmt(p.schmerz)).font(.caption2.bold()).foregroundStyle(.secondary)
                        }
                }
                .chartYScale(domain: 0...10)
                .frame(height: 160)
            }
        }
    }

    // MARK: - Koffein → Folgetag-Schmerz

    private var koffeinDaten: [(koffein: Int, schmerz: Double)] {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let kal = Calendar.current
        let ud = UserDefaults.standard
        return eintraege.compactMap { e in
            guard let vortag = kal.date(byAdding: .day, value: -1, to: e.datum) else { return nil }
            let key = df.string(from: vortag)
            let koffein = ud.integer(forKey: "koffeinTassen_\(key)")
            let wasser  = ud.integer(forKey: "wasserMl_\(key)")
            let frueh   = ud.bool(forKey: "mahlzeitFruehstueck_\(key)")
            guard koffein > 0 || wasser > 0 || frueh else { return nil }
            return (koffein: koffein, schmerz: Double(e.schmerzstaerke))
        }
    }

    private var koffeinGruppenDaten: [(label: String, schmerz: Double, anzahl: Int)] {
        let gruppen: [(label: String, pred: (Int) -> Bool)] = [
            ("0 Tassen", { $0 == 0 }),
            ("1 Tasse",  { $0 == 1 }),
            ("2 Tassen", { $0 == 2 }),
            ("3+ Tassen",{ $0 >= 3 })
        ]
        return gruppen.compactMap { label, pred in
            let treffer = koffeinDaten.filter { pred($0.koffein) }
            guard treffer.count >= 2 else { return nil }
            let avg = treffer.map(\.schmerz).reduce(0,+) / Double(treffer.count)
            return (label: label, schmerz: avg, anzahl: treffer.count)
        }
    }

    private var koffeinSchmerzChart: some View {
        let braun = Color(red: 0.55, green: 0.35, blue: 0.15)
        return karte {
            Text("Koffein → Folgetag-Schmerz").font(.headline)
            Text("Koffeinkonsum vom Vortag vs. heutiger Schmerz")
                .font(.caption).foregroundStyle(.secondary)
            if koffeinGruppenDaten.count < 2 {
                Text("Nicht genug Daten. Erfasse deinen Koffeinkonsum täglich unter Wohlbefinden.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Chart(koffeinGruppenDaten, id: \.label) { p in
                    BarMark(x: .value("Koffein", p.label), y: .value("Schmerz", p.schmerz))
                        .foregroundStyle(braun.gradient).cornerRadius(6)
                        .annotation(position: .top) {
                            Text(fmt(p.schmerz)).font(.caption2.bold()).foregroundStyle(.secondary)
                        }
                }
                .chartYScale(domain: 0...10)
                .frame(height: 160)
                Text("Basiert auf \(koffeinDaten.count) Tagen mit erfasstem Koffeinkonsum")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Wetter ↔ Schmerz

    private var wetterDaten: [(wetter: String, schmerz: Double)] {
        let mitWetter = eintraege.filter { $0.wetterCode != nil }
        guard !mitWetter.isEmpty else { return [] }
        return Dictionary(grouping: mitWetter) { e -> String in
            guard let c = e.wetterCode else { return "Unbekannt" }
            return WetterSnapshot.beschreibungFuerCode(c)
        }
        .map { key, werte in
            let avg = Double(werte.map(\.schmerzstaerke).reduce(0,+)) / Double(werte.count)
            return (wetter: key, schmerz: avg)
        }
        .sorted { $0.schmerz > $1.schmerz }
    }

    private var wetterSchmerzChart: some View {
        karte {
            Text("Wetter ↔ Schmerz").font(.headline)
            Text("Ø Schmerzstärke je Wetterlage").font(.caption).foregroundStyle(.secondary)
            if wetterDaten.isEmpty {
                Text("Noch keine Wetterdaten. Erlaube Standortzugriff beim Erfassen.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Chart(wetterDaten, id: \.wetter) { p in
                    BarMark(x: .value("Schmerz", p.schmerz), y: .value("Wetter", p.wetter))
                        .foregroundStyle(SchmerzBadge.farbe(fuer: Int(p.schmerz)).gradient)
                        .cornerRadius(6)
                }
                .chartXScale(domain: 0...10)
                .frame(height: CGFloat(wetterDaten.count * 44 + 20))
            }
        }
    }

    // MARK: - Zyklus-Phase ↔ Schmerz

    private var zyklusPhasenDaten: [(phase: String, schmerz: Double, anzahl: Int)] {
        guard !zyklusEintraege.isEmpty else { return [] }
        let analyse = ZyklusRechner.analyse(eintraege: Array(zyklusEintraege))
        guard !analyse.zyklusStarts.isEmpty else { return [] }
        let kal = Calendar.current
        let fruchtbareSet = analyse.fruchtbareTageSet
        let zyklusStarts  = analyse.zyklusStarts.sorted()

        var phasen: [String: [Double]] = [
            "Menstruation": [], "Follikelphase": [], "Fruchtbar": [], "Lutealphase": []
        ]

        for e in eintraege {
            let tag = kal.startOfDay(for: e.datum)
            let s   = Double(e.schmerzstaerke)
            if let ze = zyklusEintraege.first(where: { kal.isDate($0.datum, inSameDayAs: tag) }), ze.istPeriode {
                phasen["Menstruation"]?.append(s)
            } else if fruchtbareSet.contains(tag) {
                phasen["Fruchtbar"]?.append(s)
            } else if let start = zyklusStarts.filter({ $0 <= tag }).last {
                let tage = kal.dateComponents([.day], from: start, to: tag).day ?? 0
                phasen[tage < 8 ? "Follikelphase" : "Lutealphase"]?.append(s)
            }
        }

        return ["Menstruation", "Follikelphase", "Fruchtbar", "Lutealphase"].compactMap { ph in
            guard let v = phasen[ph], v.count >= 2 else { return nil }
            return (phase: ph, schmerz: v.reduce(0,+)/Double(v.count), anzahl: v.count)
        }
    }

    private var zyklusSchmerzChart: some View {
        karte {
            Text("Zyklus-Phase ↔ Schmerz").font(.headline)
            Text("Ø Schmerzstärke je Zyklusphase").font(.caption).foregroundStyle(.secondary)
            if zyklusPhasenDaten.count < 2 {
                Text("Nicht genug Daten. Erfasse mehr Zyklus- und Schmerzeinträge.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Chart(zyklusPhasenDaten, id: \.phase) { p in
                    BarMark(x: .value("Phase", p.phase), y: .value("Schmerz", p.schmerz))
                        .foregroundStyle(Color.pink.gradient).cornerRadius(6)
                        .annotation(position: .top) {
                            VStack(spacing: 0) {
                                Text(fmt(p.schmerz)).font(.caption2.bold()).foregroundStyle(.secondary)
                                Text("n=\(p.anzahl)").font(.system(size: 8)).foregroundStyle(.tertiary)
                            }
                        }
                }
                .chartYScale(domain: 0...10)
                .frame(height: 180)
                if let worst = zyklusPhasenDaten.max(by: { $0.schmerz < $1.schmerz }) {
                    HStack {
                        Image(systemName: "drop.circle.fill").foregroundStyle(.pink)
                        Text("Stärkster Schmerz in der \(worst.phase)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Medikament-Effekt

    private var adherenzDaten: [MedAdherenz] {
        let kal = Calendar.current
        let heute = kal.startOfDay(for: Date())
        let fenster = kal.date(byAdding: .day, value: -90, to: heute)!

        // Group taken days per medication name
        var einnahmenProMed: [String: Set<Date>] = [:]
        for log in einnahmeLogs where log.eingenommen {
            let tag = kal.startOfDay(for: log.datum)
            guard tag >= fenster else { continue }
            einnahmenProMed[log.medikamentName, default: []].insert(tag)
        }

        // All known medication names (active + any seen in logs)
        var medNamen = Set(dauermedikationen.map { $0.name })
        einnahmenProMed.keys.forEach { medNamen.insert($0) }

        return medNamen.sorted().compactMap { name in
            let einnahmen = einnahmenProMed[name] ?? []

            // Earliest log entry for this med within window
            let erstesLogDatum = einnahmeLogs
                .filter { $0.medikamentName == name }
                .map { kal.startOfDay(for: $0.datum) }
                .filter { $0 >= fenster }
                .min() ?? heute
            let erwartetTage = max(kal.dateComponents([.day], from: erstesLogDatum, to: heute).day ?? 1, 1)

            guard !einnahmen.isEmpty else { return nil }

            // Pain on days WITH vs WITHOUT medication
            var mitMed: [Double] = []
            var ohneMed: [Double] = []
            for e in eintraege {
                let tag = kal.startOfDay(for: e.datum)
                guard tag >= fenster else { continue }
                let s = Double(e.schmerzstaerke)
                if einnahmen.contains(tag) { mitMed.append(s) } else { ohneMed.append(s) }
            }

            let dosierung = einnahmeLogs.first { $0.medikamentName == name }?.dosierung ?? ""

            return MedAdherenz(
                name: name,
                dosierung: dosierung,
                adherenzRate: min(Double(einnahmen.count) / Double(erwartetTage), 1.0),
                einnahmenTage: einnahmen.count,
                erwarteterTage: erwartetTage,
                avgSchmerzMit:  mitMed.isEmpty  ? nil : mitMed.reduce(0,+)  / Double(mitMed.count),
                avgSchmerzOhne: ohneMed.isEmpty ? nil : ohneMed.reduce(0,+) / Double(ohneMed.count),
                nMit:  mitMed.count,
                nOhne: ohneMed.count
            )
        }
    }

    private var medikamentEffektChart: some View {
        karte {
            VStack(alignment: .leading, spacing: 4) {
                Text("Medikamenten-Adherenz").font(.headline)
                Text("Einnahmetreue & Ø Schmerz mit / ohne Einnahme (letzte 90 Tage)")
                    .font(.caption).foregroundStyle(.secondary)
            }

            let daten = adherenzDaten
            if daten.isEmpty {
                Text("Noch keine Einnahmen erfasst.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                VStack(spacing: 14) {
                    ForEach(daten, id: \.name) { med in
                        MedAdherenzZeile(med: med, fmt: fmt)
                    }
                }
                Text("Hinweis: Kausale Wirkrichtung ist aus diesen Daten nicht ableitbar.")
                    .font(.caption2).foregroundStyle(.tertiary).italic()
            }
        }
    }

    // MARK: - Körperstellen

    private var koerperstellenDaten: [(ort: String, anzahl: Int, avgSchmerz: Double)] {
        var dict: [String: [Int]] = [:]
        for e in eintraege where !e.koerperstelle.isEmpty {
            e.koerperstelle.components(separatedBy: ", ")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .forEach { dict[$0, default: []].append(e.schmerzstaerke) }
        }
        return dict
            .map { ort, w in (ort: ort, anzahl: w.count, avgSchmerz: Double(w.reduce(0,+)) / Double(w.count)) }
            .sorted { $0.anzahl > $1.anzahl }
            .prefix(7).map { $0 }
    }

    private var koerperstellenChart: some View {
        karte {
            Text("Häufigste Schmerzorte").font(.headline)
            Text("Anzahl Einträge je Körperregion, Farbe = Ø Schmerzstärke")
                .font(.caption).foregroundStyle(.secondary)
            if koerperstellenDaten.isEmpty {
                Text("Keine Körperstellen erfasst.").font(.caption).foregroundStyle(.secondary)
            } else {
                Chart(koerperstellenDaten, id: \.ort) { item in
                    BarMark(x: .value("Anzahl", item.anzahl), y: .value("Ort", item.ort))
                        .foregroundStyle(SchmerzBadge.farbe(fuer: Int(item.avgSchmerz)).gradient)
                        .cornerRadius(6)
                        .annotation(position: .trailing) {
                            Text("×\(item.anzahl)  Ø\(fmt(item.avgSchmerz))")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                }
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
                .frame(height: CGFloat(koerperstellenDaten.count * 42 + 20))
            }
        }
    }

    // MARK: - Schmerzarten

    private var schmerzartDaten: [(art: String, anzahl: Int, avgSchmerz: Double)] {
        var dict: [String: [Int]] = [:]
        for e in eintraege where !e.schmerzart.isEmpty {
            e.schmerzart.components(separatedBy: ", ")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .forEach { dict[$0, default: []].append(e.schmerzstaerke) }
        }
        return dict
            .map { art, w in (art: art, anzahl: w.count, avgSchmerz: Double(w.reduce(0,+)) / Double(w.count)) }
            .sorted { $0.anzahl > $1.anzahl }
            .prefix(8).map { $0 }
    }

    private var schmerzartChart: some View {
        karte {
            Text("Häufige Schmerzarten").font(.headline)
            Text("Wie sich der Schmerz typischerweise anfühlt").font(.caption).foregroundStyle(.secondary)
            if schmerzartDaten.isEmpty {
                Text("Keine Schmerzarten erfasst. Wähle im Wizard unter «Charakter» die Schmerzart.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Chart(schmerzartDaten, id: \.art) { item in
                    BarMark(x: .value("Anzahl", item.anzahl), y: .value("Art", item.art))
                        .foregroundStyle(Color.purple.gradient)
                        .cornerRadius(6)
                        .annotation(position: .trailing) {
                            Text("×\(item.anzahl)").font(.caption2).foregroundStyle(.secondary)
                        }
                }
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
                .frame(height: CGFloat(schmerzartDaten.count * 42 + 20))
            }
        }
    }

    // MARK: - Begleiterscheinungen

    private var begleitDaten: [(symptom: String, anzahl: Int)] {
        var dict: [String: Int] = [:]
        for e in eintraege where !e.begleiterscheinungen.isEmpty {
            e.begleiterscheinungen.components(separatedBy: ", ")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .forEach { dict[$0, default: 0] += 1 }
        }
        return dict.map { ($0.key, $0.value) }.sorted { $0.1 > $1.1 }.prefix(8).map { $0 }
    }

    private var begleiterscheinungenChart: some View {
        karte {
            Text("Häufige Begleiterscheinungen").font(.headline)
            Text("Welche Begleitsymptome am häufigsten auftreten").font(.caption).foregroundStyle(.secondary)
            if begleitDaten.isEmpty {
                Text("Keine Begleiterscheinungen erfasst.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Chart(begleitDaten, id: \.symptom) { item in
                    BarMark(x: .value("Anzahl", item.anzahl), y: .value("Symptom", item.symptom))
                        .foregroundStyle(Color.teal.gradient)
                        .cornerRadius(6)
                        .annotation(position: .trailing) {
                            Text("×\(item.anzahl)").font(.caption2).foregroundStyle(.secondary)
                        }
                }
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
                .frame(height: CGFloat(begleitDaten.count * 42 + 20))
            }
        }
    }

    // MARK: - Massnahmen

    private var massnahmenDaten: [(massnahme: String, anzahl: Int)] {
        var dict: [String: Int] = [:]
        for e in eintraege where !e.massnahmen.isEmpty {
            e.massnahmen.components(separatedBy: ", ")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .forEach { dict[$0, default: 0] += 1 }
        }
        return dict.map { ($0.key, $0.value) }.sorted { $0.1 > $1.1 }.prefix(8).map { $0 }
    }

    private var massnahmenChart: some View {
        karte {
            Text("Angewandte Massnahmen").font(.headline)
            Text("Was du am häufigsten gegen den Schmerz unternimmst").font(.caption).foregroundStyle(.secondary)
            if massnahmenDaten.isEmpty {
                Text("Keine Massnahmen erfasst.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Chart(massnahmenDaten, id: \.massnahme) { item in
                    BarMark(x: .value("Anzahl", item.anzahl), y: .value("Massnahme", item.massnahme))
                        .foregroundStyle(Color.green.gradient)
                        .cornerRadius(6)
                        .annotation(position: .trailing) {
                            Text("×\(item.anzahl)").font(.caption2).foregroundStyle(.secondary)
                        }
                }
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
                .frame(height: CGFloat(massnahmenDaten.count * 42 + 20))
            }
        }
    }

    // MARK: - Dauermedikament-Analyse

    private struct MedAnalyse: Identifiable {
        var id: String { med.notifID }
        let med: Dauermedikation
        let einnahmetreue: Double   // -1 = Bei Bedarf, 0.0–1.0 sonst
        let schmerzMitMed: Double?
        let schmerzOhneMed: Double?
        let schmerzVorStart: Double?
        let schmerzNachStart: Double?
        let nMit: Int
        let nOhne: Int
        let nVor: Int
        let nNach: Int
    }

    private var medAnalysen: [MedAnalyse] {
        let kal = Calendar.current
        let notif = NotificationManager.shared
        let heute = kal.startOfDay(for: Date())

        return dauermedikationen
            .filter { notif.anzahlDosen($0.frequenz) > 0 && $0.frequenz != "Wöchentlich" }
            .compactMap { med in
            let anzDosen = notif.anzahlDosen(med.frequenz)

            // Einnahmetreue: ab startDatum, max 30 Tage
            let tageSeitStart = max(1, kal.dateComponents([.day],
                from: kal.startOfDay(for: med.startDatum), to: heute).day ?? 1)
            let fensterTage = min(30, tageSeitStart)
            let letztenN = (0..<fensterTage).compactMap { kal.date(byAdding: .day, value: -$0, to: heute) }
            let geloggteTage = letztenN.filter { tag in
                einnahmeLogs.filter {
                    kal.isDate($0.datum, inSameDayAs: tag) &&
                    $0.medikamentName == med.name &&
                    $0.dosierung == med.dosierung &&
                    $0.eingenommen
                }.count >= anzDosen
            }
            let treue = Double(geloggteTage.count) / Double(fensterTage)

            // Schmerz mit vs. ohne Einnahme (name + dosierung)
            let logTage = Set(einnahmeLogs
                .filter { $0.medikamentName == med.name && $0.dosierung == med.dosierung && $0.eingenommen }
                .map { kal.startOfDay(for: $0.datum) })
            var mitMed: [Double] = []
            var ohneMed: [Double] = []
            for e in eintraege where e.schmerzstaerke > 0 {
                if logTage.contains(kal.startOfDay(for: e.datum)) {
                    mitMed.append(Double(e.schmerzstaerke))
                } else {
                    ohneMed.append(Double(e.schmerzstaerke))
                }
            }

            // Wirksamkeit: vor vs. nach Startdatum
            let startTag = kal.startOfDay(for: med.startDatum)
            var vorStart: [Double] = []
            var nachStart: [Double] = []
            for e in eintraege where e.schmerzstaerke > 0 {
                let tag = kal.startOfDay(for: e.datum)
                if tag < startTag { vorStart.append(Double(e.schmerzstaerke)) }
                else { nachStart.append(Double(e.schmerzstaerke)) }
            }

            guard mitMed.count >= 3 || nachStart.count >= 3 else { return nil }

            return MedAnalyse(
                med: med,
                einnahmetreue: treue,
                schmerzMitMed: mitMed.isEmpty ? nil : mitMed.reduce(0,+) / Double(mitMed.count),
                schmerzOhneMed: ohneMed.isEmpty ? nil : ohneMed.reduce(0,+) / Double(ohneMed.count),
                schmerzVorStart: vorStart.count >= 3 ? vorStart.reduce(0,+) / Double(vorStart.count) : nil,
                schmerzNachStart: nachStart.count >= 3 ? nachStart.reduce(0,+) / Double(nachStart.count) : nil,
                nMit: mitMed.count,
                nOhne: ohneMed.count,
                nVor: vorStart.count,
                nNach: nachStart.count
            )
        }
    }

    private func dauermedikamentKarte(_ a: MedAnalyse) -> some View {
        karte {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: "pill.fill").foregroundStyle(.blue)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(a.med.name).font(.headline)
                    HStack(spacing: 4) {
                        if !a.med.dosierung.isEmpty { Text(a.med.dosierung) }
                        Text("· Seit \(a.med.startDatum, format: .dateTime.day().month(.abbreviated).year())")
                    }
                    .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                let pct = Int(a.einnahmetreue * 100)
                Text("\(pct)%")
                    .font(.subheadline.bold())
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(treueFarbe(a.einnahmetreue).opacity(0.12), in: Capsule())
                    .foregroundStyle(treueFarbe(a.einnahmetreue))
            }

            if let mit = a.schmerzMitMed, let ohne = a.schmerzOhneMed, a.nMit >= 3 {
                Divider()
                HStack(spacing: 0) {
                    medStatSpalte("Mit Medikament", wert: fmt(mit), farbe: .blue, n: a.nMit)
                    Divider().frame(height: 44)
                    medStatSpalte("Ohne Medikament", wert: fmt(ohne), farbe: .secondary, n: a.nOhne)
                }
            }

            if let vor = a.schmerzVorStart, let nach = a.schmerzNachStart {
                let diff = vor - nach
                Divider()
                HStack(alignment: .center, spacing: 12) {
                    VStack(spacing: 2) {
                        Text(fmt(vor)).font(.title3.bold()).foregroundStyle(.orange)
                        Text("Vor Start").font(.caption2).foregroundStyle(.secondary)
                        Text("n=\(a.nVor)").font(.caption2).foregroundStyle(.tertiary)
                    }
                    Image(systemName: "arrow.right").foregroundStyle(.secondary)
                    VStack(spacing: 2) {
                        Text(fmt(nach)).font(.title3.bold())
                            .foregroundStyle(diff > 0.5 ? .green : diff < -0.5 ? .red : .orange)
                        Text("Nach Start").font(.caption2).foregroundStyle(.secondary)
                        Text("n=\(a.nNach)").font(.caption2).foregroundStyle(.tertiary)
                    }
                    Spacer()
                    if abs(diff) > 0.3 {
                        VStack(spacing: 2) {
                            Text(diff > 0 ? "−\(fmt(diff))" : "+\(fmt(abs(diff)))")
                                .font(.subheadline.bold())
                                .foregroundStyle(diff > 0 ? .green : .red)
                            Text("Ø Schmerz").font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background((diff > 0 ? Color.green : Color.red).opacity(0.1),
                                    in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            let fenster = min(30, max(1, Calendar.current.dateComponents([.day],
                from: Calendar.current.startOfDay(for: a.med.startDatum),
                to: Calendar.current.startOfDay(for: Date())).day ?? 1))
            Text("Einnahmetreue letzte \(fenster) Tage · \(a.nMit + a.nOhne) Schmerzeinträge")
                .font(.caption2).foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private func medStatSpalte(_ titel: String, wert: String, farbe: Color, n: Int) -> some View {
        VStack(spacing: 4) {
            Text(wert).font(.title3.bold()).foregroundStyle(farbe)
            Text(titel).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Text("n=\(n)").font(.caption2).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func treueFarbe(_ treue: Double) -> Color {
        treue >= 0.85 ? .green : treue >= 0.60 ? .orange : .red
    }

    // MARK: - Bedarfstrend-Chart (Feature D)

    private struct BedarfsWoche: Identifiable {
        let id: String; let label: String; let anzahl: Int
    }

    private var bedarfsTrendDaten: [BedarfsWoche] {
        let kal = Calendar.current
        let heute = kal.startOfDay(for: Date())
        let bedarfsMeds = alleDauermedikationen.filter {
            NotificationManager.shared.anzahlDosen($0.frequenz) == 0
        }.map { "\($0.name)|\($0.dosierung)" }
        guard !bedarfsMeds.isEmpty else { return [] }
        let bedarfsLogs = einnahmeLogs.filter { log in
            bedarfsMeds.contains("\(log.medikamentName)|\(log.dosierung)") && log.eingenommen
        }
        guard !bedarfsLogs.isEmpty else { return [] }
        return (0..<8).reversed().map { wocheVor in
            guard let wocheEnde = kal.date(byAdding: .weekOfYear, value: -wocheVor, to: heute),
                  let wocheStart = kal.date(byAdding: .day, value: -6, to: wocheEnde) else {
                return BedarfsWoche(id: "\(wocheVor)", label: "?", anzahl: 0)
            }
            let anzahl = bedarfsLogs.filter { $0.datum >= wocheStart && $0.datum <= wocheEnde }.count
            let label = wocheVor == 0 ? "Heute" : "−\(wocheVor)W"
            return BedarfsWoche(id: "\(wocheVor)", label: label, anzahl: anzahl)
        }
    }

    private var bedarfsTrendChart: some View {
        karte {
            Text("Bedarfsmedikation Trend").font(.headline)
            Text("Einnahmen pro Woche (letzte 8 Wochen) – Warnschwelle 2.5/Woche (MOH)")
                .font(.caption).foregroundStyle(.secondary)
            Chart(bedarfsTrendDaten) { w in
                BarMark(x: .value("Woche", w.label), y: .value("Einnahmen", w.anzahl))
                    .foregroundStyle(w.anzahl > 2 ? Color.orange.gradient : Color.blue.gradient)
                    .cornerRadius(4)
                RuleMark(y: .value("MOH-Grenze", 2.5))
                    .foregroundStyle(.red.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4]))
                    .annotation(position: .trailing, alignment: .leading) {
                        Text("MOH").font(.caption2).foregroundStyle(.red)
                    }
            }
            .chartYScale(domain: 0...max(4, (bedarfsTrendDaten.map(\.anzahl).max() ?? 0) + 1))
            .frame(height: 160)
            if bedarfsTrendDaten.contains(where: { $0.anzahl > 2 }) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text("Häufige Bedarfseinnahme – Risiko für Übergebrauchskopfschmerzen")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Wirksamkeits-Chart (Feature A+D)

    private struct WirksamkeitDaten: Identifiable {
        let id: String; let name: String
        let gut: Int; let teilweise: Int; let nicht: Int
        var gesamt: Int { gut + teilweise + nicht }
        var gutPct: Double { gesamt > 0 ? Double(gut) / Double(gesamt) * 100 : 0 }
    }

    private var wirksamkeitDaten: [WirksamkeitDaten] {
        let bewertet = einnahmeLogs.filter { !$0.wirkung.isEmpty }
        guard !bewertet.isEmpty else { return [] }
        let grouped = Dictionary(grouping: bewertet) { "\($0.medikamentName)|\($0.dosierung)" }
        return grouped.compactMap { key, logs in
            let gut = logs.filter { $0.wirkung == "gut" }.count
            let teilw = logs.filter { $0.wirkung == "teilweise" }.count
            let nicht = logs.filter { $0.wirkung == "nicht" }.count
            guard gut + teilw + nicht > 0 else { return nil }
            let name = logs.first.map { d in
                d.dosierung.isEmpty ? d.medikamentName : "\(d.medikamentName) \(d.dosierung)"
            } ?? key
            return WirksamkeitDaten(id: key, name: name, gut: gut, teilweise: teilw, nicht: nicht)
        }
        .sorted { $0.gutPct > $1.gutPct }
    }

    private var wirksamkeitsChart: some View {
        karte {
            Text("Wirksamkeit Bedarfsmedikation").font(.headline)
            Text("Bewertungen: Gut / Teilweise / Nicht").font(.caption).foregroundStyle(.secondary)
            VStack(spacing: 12) {
                ForEach(wirksamkeitDaten) { d in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(d.name).font(.subheadline.bold())
                            Spacer()
                            Text("\(d.gesamt) Bewertungen").font(.caption).foregroundStyle(.secondary)
                        }
                        GeometryReader { geo in
                            HStack(spacing: 0) {
                                if d.gut > 0 {
                                    RoundedRectangle(cornerRadius: 0).fill(Color.green)
                                        .frame(width: geo.size.width * Double(d.gut) / Double(d.gesamt))
                                }
                                if d.teilweise > 0 {
                                    Rectangle().fill(Color.orange)
                                        .frame(width: geo.size.width * Double(d.teilweise) / Double(d.gesamt))
                                }
                                if d.nicht > 0 {
                                    Rectangle().fill(Color.red)
                                        .frame(width: geo.size.width * Double(d.nicht) / Double(d.gesamt))
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .frame(height: 10)
                        HStack(spacing: 12) {
                            wirkungsLegende("Gut", n: d.gut, farbe: .green)
                            wirkungsLegende("Teilweise", n: d.teilweise, farbe: .orange)
                            wirkungsLegende("Nicht", n: d.nicht, farbe: .red)
                        }
                    }
                }
            }
        }
    }

    private func wirkungsLegende(_ label: String, n: Int, farbe: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(farbe).frame(width: 8, height: 8)
            Text("\(label) (\(n))").font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: - Injektions-Zyklus

    private var wöchentlicheMedikamente: [Dauermedikation] {
        alleDauermedikationen.filter { $0.frequenz == "Wöchentlich" }
    }

    private var injektionsZyklusDaten: [(tag: Int, schmerz: Double, anzahl: Int)] {
        guard !wöchentlicheMedikamente.isEmpty else { return [] }
        let kal = Calendar.current
        let wöchentlicheNamen = Set(wöchentlicheMedikamente.map(\.name))
        let injektionsLogs = einnahmeLogs.filter { wöchentlicheNamen.contains($0.medikamentName) && $0.eingenommen }
        guard injektionsLogs.count >= 2 else { return [] }

        var schmerzProTag: [Int: [Double]] = [:]
        for injektion in injektionsLogs {
            let injTag = kal.startOfDay(for: injektion.datum)
            for e in eintraege {
                let eTag = kal.startOfDay(for: e.datum)
                let diff = kal.dateComponents([.day], from: injTag, to: eTag).day ?? -1
                if diff >= 0 && diff < 7 {
                    schmerzProTag[diff, default: []].append(Double(e.schmerzstaerke))
                }
            }
        }
        return (0..<7).compactMap { tag in
            guard let werte = schmerzProTag[tag], !werte.isEmpty else { return nil }
            return (tag: tag, schmerz: werte.reduce(0,+) / Double(werte.count), anzahl: werte.count)
        }
    }

    @ViewBuilder
    private var injektionsZyklusChart: some View {
        if !wöchentlicheMedikamente.isEmpty {
            karte {
                Text("Schmerz im Injektions-Zyklus").font(.headline)
                Text("Ø Schmerzstärke an den Tagen nach der Injektion (Tag 0 = Injektionstag)")
                    .font(.caption).foregroundStyle(.secondary)

                if injektionsZyklusDaten.count < 2 {
                    Text("Nicht genug Daten. Erfasse mehr Injektionen und Schmerzeinträge.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Chart(injektionsZyklusDaten, id: \.tag) { p in
                        BarMark(
                            x: .value("Tag", "Tag \(p.tag)"),
                            y: .value("Schmerz", p.schmerz)
                        )
                        .foregroundStyle(SchmerzBadge.farbe(fuer: Int(p.schmerz)).gradient)
                        .cornerRadius(6)
                        .annotation(position: .top) {
                            VStack(spacing: 0) {
                                Text(fmt(p.schmerz)).font(.caption2.bold()).foregroundStyle(.secondary)
                                Text("n=\(p.anzahl)").font(.system(size: 8)).foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .chartYScale(domain: 0...10)
                    .chartYAxis { AxisMarks(values: [0, 2, 4, 6, 8, 10]) }
                    .frame(height: 200)

                    if let peak = injektionsZyklusDaten.max(by: { $0.schmerz < $1.schmerz }) {
                        HStack {
                            Image(systemName: "syringe").foregroundStyle(.blue)
                            Text("Stärkster Schmerz an Tag \(peak.tag) nach der Injektion")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Hilfsfunktionen

    @ViewBuilder
    private func karte<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func korrBadge(_ r: Double, label: String) -> some View {
        HStack {
            Image(systemName: korrelationsSymbol(r)).foregroundStyle(korrelationsFarbe(r))
            Text(korrelationsText(r, posLabel: label)).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func korrelation(_ x: [Double], _ y: [Double]) -> Double {
        guard x.count == y.count, x.count > 1 else { return 0 }
        let n = Double(x.count)
        let xM = x.reduce(0,+) / n, yM = y.reduce(0,+) / n
        let z  = zip(x, y).map { ($0 - xM) * ($1 - yM) }.reduce(0,+)
        let nX = sqrt(x.map { pow($0 - xM, 2) }.reduce(0,+))
        let nY = sqrt(y.map { pow($0 - yM, 2) }.reduce(0,+))
        guard nX * nY != 0 else { return 0 }
        return z / (nX * nY)
    }

    private func korrelationsText(_ r: Double, posLabel: String) -> String {
        switch abs(r) {
        case 0.7...: return r < 0 ? posLabel : "Starke positive Korrelation"
        case 0.4...: return r < 0 ? "Mittlere negative Korrelation" : "Mittlere positive Korrelation"
        case 0.2...: return "Schwache Korrelation erkennbar"
        default:     return "Kein klarer Zusammenhang erkennbar"
        }
    }

    private func korrelationsSymbol(_ r: Double) -> String {
        abs(r) > 0.4 ? (r < 0 ? "arrow.down.right" : "arrow.up.right") : "minus"
    }

    private func korrelationsFarbe(_ r: Double) -> Color {
        abs(r) > 0.4 ? (r < 0 ? .green : .red) : .secondary
    }

    private func fmt(_ d: Double) -> String { String(format: "%.1f", d) }
}

// MARK: - Adherence model

private struct MedAdherenz {
    let name: String
    let dosierung: String
    let adherenzRate: Double        // 0–1, capped
    let einnahmenTage: Int
    let erwarteterTage: Int
    let avgSchmerzMit: Double?
    let avgSchmerzOhne: Double?
    let nMit: Int
    let nOhne: Int
}

// MARK: - Adherence row

private struct MedAdherenzZeile: View {
    let med: MedAdherenz
    let fmt: (Double) -> String

    private var adherenzFarbe: Color {
        switch med.adherenzRate {
        case 0.8...: return .green
        case 0.5...: return .orange
        default:     return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(med.name).font(.subheadline.bold())
                    if !med.dosierung.isEmpty {
                        Text(med.dosierung).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text("\(Int(med.adherenzRate * 100)) %")
                    .font(.subheadline.bold())
                    .foregroundStyle(adherenzFarbe)
            }

            // Adherence progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(adherenzFarbe.gradient)
                        .frame(width: geo.size.width * med.adherenzRate, height: 6)
                }
            }
            .frame(height: 6)

            Text("\(med.einnahmenTage) von \(med.erwarteterTage) Tagen eingenommen")
                .font(.caption2).foregroundStyle(.tertiary)

            // Pain comparison
            if let mit = med.avgSchmerzMit {
                HStack(spacing: 12) {
                    PainPill(label: "Mit Einnahme", wert: mit, n: med.nMit, farbe: .blue, fmt: fmt)
                    if let ohne = med.avgSchmerzOhne {
                        PainPill(label: "Ohne Einnahme", wert: ohne, n: med.nOhne, farbe: .secondary, fmt: fmt)
                    }
                }
            } else {
                Text("Nicht genug Schmerzdaten für Vergleich.")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct PainPill: View {
    let label: String
    let wert: Double
    let n: Int
    let farbe: Color
    let fmt: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(fmt(wert))
                    .font(.subheadline.bold())
                    .foregroundStyle(farbe)
                Text("Ø").font(.caption2).foregroundStyle(.secondary)
                Text("(n=\(n))").font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
