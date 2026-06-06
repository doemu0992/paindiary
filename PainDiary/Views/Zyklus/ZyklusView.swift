import SwiftUI
import SwiftData
import Charts

struct ZyklusView: View {
    @Query(sort: \ZyklusEintrag.datum, order: .reverse) private var eintraege: [ZyklusEintrag]
    @Query(sort: \PainEntry.datum, order: .reverse) private var painEntries: [PainEntry]
    @Environment(\.modelContext) private var modelContext

    @State private var anzeigeMonat = Date()
    @State private var ausgewaehlterTag: ZyklusTagAuswahl? = nil
    @State private var notifManager = NotificationManager.shared

    private var analyse: ZyklusAnalyse { ZyklusRechner.analyse(eintraege: Array(eintraege)) }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                zyklusHeader
                kalender
                quickLog
                zyklusNotifBanner
                statistik
                if !painEntries.isEmpty && !analyse.zyklusStarts.isEmpty {
                    schmerzKorrelation
                }
            }
            .padding(.bottom, 30)
        }
        .navigationTitle("Zyklus")
        .sheet(item: $ausgewaehlterTag) { auswahl in
            ZyklusEintragSheet(
                datum: auswahl.datum,
                bestehend: eintraege.first { Calendar.current.isDate($0.datum, inSameDayAs: auswahl.datum) }
            )
        }
        .onChange(of: eintraege) { _, _ in planeZyklusNotifs() }
        .onAppear { planeZyklusNotifs() }
    }

    private func planeZyklusNotifs() {
        NotificationManager.shared.planeZyklusErinnerungen(analyse: analyse)
    }

    @ViewBuilder
    private var zyklusNotifBanner: some View {
        if !analyse.zyklusStarts.isEmpty {
            if notifManager.status == .notDetermined {
                HStack(spacing: 12) {
                    Image(systemName: "bell.badge.fill")
                        .font(.title3)
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Zyklus-Erinnerungen")
                            .font(.subheadline.bold())
                        Text("Erhalte Benachrichtigungen für Periode, fruchtbare Tage und Eisprung.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Button("Aktivieren") {
                        Task {
                            let granted = await notifManager.berechtigungAnfordern()
                            if granted { planeZyklusNotifs() }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding()
                .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            } else if notifManager.status == .denied {
                HStack(spacing: 12) {
                    Image(systemName: "bell.slash.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Erinnerungen deaktiviert")
                            .font(.subheadline.bold())
                        Text("Aktiviere Benachrichtigungen in den iOS-Einstellungen.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
#if os(iOS)
                    Button("Einstellungen") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
#endif
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }
        }
    }

    private func wechselMonat(_ richtung: Int) {
        withAnimation {
            anzeigeMonat = Calendar.current.date(byAdding: .month, value: richtung, to: anzeigeMonat) ?? anzeigeMonat
        }
    }

    // MARK: - Header

    private var zyklusHeader: some View {
        VStack(spacing: 10) {
            if let tag = analyse.aktuellerZyklustag {
                // Row 1: cycle day / next period / cycle length
                HStack(spacing: 0) {
                    headerBadge(wert: "\(tag)", einheit: "Tag", label: "Zyklustag", farbe: .pink)
                    Divider().frame(height: 40)
                    headerBadge(
                        wert: naechstePeriodeBadge,
                        einheit: "",
                        label: "Nächste Periode",
                        farbe: .red
                    )
                    Divider().frame(height: 40)
                    headerBadge(
                        wert: String(format: "%.0f", analyse.zykluslaenge),
                        einheit: "d",
                        label: "Ø Zyklus (\(analyse.zyklusStarts.count) Zyklen)",
                        farbe: .purple
                    )
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

                // Row 2: fertile window + ovulation dates
                fruchtbarkeitsCard
            } else {
                Text("Erfasse deinen ersten Periodentag um zu beginnen.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }

            legende
        }
        .padding(.horizontal)
    }

    private var fruchtbarkeitsCard: some View {
        let fenster = naechstesFruchtbaresF
        let ov = analyse.vorhergesagteOvulation
        return HStack(spacing: 0) {
            VStack(spacing: 2) {
                if let (start, end) = fenster {
                    Text("\(kurzDatum(start)) – \(kurzDatum(end))")
                        .font(.subheadline.bold()).foregroundStyle(.teal)
                } else {
                    Text("–").font(.subheadline.bold()).foregroundStyle(.teal)
                }
                HStack(spacing: 3) {
                    Text("Fruchtbares Fenster").font(.caption2).foregroundStyle(.secondary)
                    InfoButton(titel: "Fruchtbares Fenster",
                               text: "Das nächste vorhergesagte Zeitfenster maximaler Fruchtbarkeit. Basiert auf dem erwarteten Eisprung ±5 Tage. Wässriger oder Eiweiss-Zervixschleim verschiebt das Fenster automatisch.")
                }
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 36)

            VStack(spacing: 2) {
                if let ov {
                    Text(kurzDatum(ov)).font(.subheadline.bold()).foregroundStyle(.orange)
                } else {
                    Text("–").font(.subheadline.bold()).foregroundStyle(.orange)
                }
                HStack(spacing: 3) {
                    Text("Eisprung erwartet").font(.caption2).foregroundStyle(.secondary)
                    InfoButton(titel: "Eisprung erwartet",
                               text: "Vorhergesagtes Datum des Eisprungs. Die App lernt aus deinen Zervixschleim-Einträgen und passt den Zeitpunkt anhand des persönlichen Musters an.")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 10).padding(.horizontal, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var naechstePeriodeBadge: String {
        guard let n = analyse.naechstePeriodeStart else { return "–" }
        let tage = Calendar.current.dateComponents([.day], from: Date(), to: n).day ?? 0
        if tage <= 0 { return "Heute" }
        return "in \(tage)d"
    }

    // Next contiguous block of fertile days from today onward
    private var naechstesFruchtbaresF: (Date, Date)? {
        let kal = Calendar.current
        let heute = kal.startOfDay(for: Date())
        let sorted = analyse.fruchtbareTageSet.filter { $0 >= heute }.sorted()
        guard let first = sorted.first else { return nil }
        var end = first
        for tag in sorted.dropFirst() {
            if (kal.dateComponents([.day], from: end, to: tag).day ?? 99) <= 1 { end = tag } else { break }
        }
        return (first, end)
    }

    private func kurzDatum(_ d: Date) -> String {
        d.formatted(.dateTime.day().month(.abbreviated))
    }

    private func headerBadge(wert: String, einheit: String, label: String, farbe: Color) -> some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(wert).font(.title3.bold()).foregroundStyle(farbe)
                if !einheit.isEmpty {
                    Text(einheit).font(.caption).foregroundStyle(farbe.opacity(0.7))
                }
            }
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var legende: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                  alignment: .leading, spacing: 8) {
            // Spalte links / rechts im 2er-Raster
            HStack(spacing: 4) {
                ForEach([0.25, 0.5, 0.8, 1.0] as [Double], id: \.self) { op in
                    Circle().fill(Color.red.opacity(op)).frame(width: 7, height: 7)
                }
                Text("Periode")
            }

            legendeItem(farbe: .red, gefuellt: false, text: "Vorhergesagt",
                        info: ("Vorhergesagte Periode",
                               "Geschätzter Periodenbeginn basierend auf deinen bisherigen Zyklen. Wird mit jedem erfassten Zyklus genauer."))

            legendeItem(farbe: .teal, gefuellt: true, text: "Fruchtbar",
                        info: ("Fruchtbare Tage",
                               "Die 5 Tage vor und 1 Tag nach dem Eisprung. In dieser Zeit ist eine Befruchtung möglich, da Spermien bis zu 5 Tage überleben können."))

            legendeItem(farbe: .orange, gefuellt: true, text: "Eisprung",
                        info: ("Eisprung (Ovulation)",
                               "Der Moment, in dem ein Ei aus dem Eierstock freigesetzt wird. Tritt meist 12–16 Tage vor der nächsten Periode auf und ist der fruchtbarste Punkt im Zyklus."))

            HStack(spacing: 4) {
                Circle().fill(Color.purple.opacity(0.6)).frame(width: 7, height: 7)
                Text("Symptome")
            }

            HStack(spacing: 4) {
                Circle().fill(Color.blue.opacity(0.7)).frame(width: 7, height: 7)
                Text("Zervixschleim")
                InfoButton(titel: "Zervixschleim",
                           text: "Blauer Punkt = Zervixschleim erfasst. Wässrige oder Eiweiss-Konsistenz gilt als Zeichen der Fruchtbarkeit (Symptothermalmethode) und beeinflusst die Eisprungvorhersage.")
            }

            HStack(spacing: 4) {
                Circle().fill(Color.pink.opacity(0.8)).frame(width: 7, height: 7)
                Text("Sex. Aktivität")
            }

            HStack(spacing: 4) {
                Circle().fill(Color.gray.opacity(0.5)).frame(width: 7, height: 7)
                Text("Andere Daten")
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func legendeItem(farbe: Color, gefuellt: Bool, text: String, info: (String, String)? = nil) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(gefuellt ? farbe : farbe.opacity(0.15))
                .overlay(gefuellt ? nil : Circle().stroke(farbe, style: StrokeStyle(lineWidth: 1, dash: [2])))
                .frame(width: 9, height: 9)
            Text(text)
            if let (titel, erklärung) = info {
                InfoButton(titel: titel, text: erklärung)
            }
        }
    }

    // MARK: - Calendar

    private var kalender: some View {
        ZyklusKalender(
            monat: anzeigeMonat,
            eintraege: Array(eintraege),
            analyse: analyse,
            onVorheriger: { wechselMonat(-1) },
            onNaechster: { wechselMonat(1) }
        ) { tag in
            ausgewaehlterTag = ZyklusTagAuswahl(datum: tag)
        }
        .padding(.horizontal)
    }

    // MARK: - Quick Log

    private var quickLog: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Heute erfassen").font(.headline).padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    quickBtn("drop.fill", .red, "Periode") { logHeute(istPeriode: true, fluss: "mittel") }
                    quickBtn("circle.dotted", .orange, "Eisprung") { logHeute(ovuTest: "positiv") }
                    quickBtn("thermometer.medium", .blue, "Temperatur") { oeffneHeuteSheet() }
                    quickBtn("heart.text.square", .purple, "Symptome") { oeffneHeuteSheet() }
                    quickBtn("drop.halffull", .pink, "Schmierblutung") { logHeute(istPeriode: true, fluss: "schmierblutung") }
                    quickBtn("pencil", .green, "Notiz") { oeffneHeuteSheet() }
                }
                .padding(.horizontal)
            }
        }
    }

    private func quickBtn(_ symbol: String, _ farbe: Color, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle().fill(farbe.opacity(0.15)).frame(width: 52, height: 52)
                    Image(systemName: symbol).foregroundStyle(farbe).font(.system(size: 20))
                }
                Text(label).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func logHeute(istPeriode: Bool = false, fluss: String = "", ovuTest: String = "") {
        let heute = Calendar.current.startOfDay(for: Date())
        if let alt = eintraege.first(where: { Calendar.current.isDate($0.datum, inSameDayAs: heute) }) {
            if istPeriode { alt.istPeriode = true; alt.blutungsfluss = fluss }
            if !ovuTest.isEmpty { alt.ovulationstest = ovuTest }
        } else {
            let neu = ZyklusEintrag(datum: heute)
            neu.istPeriode = istPeriode
            neu.blutungsfluss = fluss
            neu.ovulationstest = ovuTest
            modelContext.insert(neu)
        }
    }

    private func oeffneHeuteSheet() {
        ausgewaehlterTag = ZyklusTagAuswahl(datum: Calendar.current.startOfDay(for: Date()))
    }

    // MARK: - Statistik

    private var statistik: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Statistik").font(.headline)
                Spacer()
                if analyse.zyklusStarts.count >= 2 {
                    Label("Basierend auf \(analyse.zyklusStarts.count) Zyklen", systemImage: "sparkles")
                        .font(.caption2).foregroundStyle(.secondary)
                } else if analyse.zyklusStarts.count == 1 {
                    Text("Ab 2 Zyklen werden Vorhersagen präziser")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statKarte("Ø Zyklus", String(format: "%.0f Tage", analyse.zykluslaenge), "arrow.clockwise", .pink)
                statKarte("Ø Periode", String(format: "%.0f Tage", analyse.periodendauer), "drop.fill", .red)
                statKarte("Variation", String(format: "±%.1f Tage", analyse.variation), "chart.bar", .orange)
                if let ov = analyse.vorhergesagteOvulation {
                    statKarte("Nächster Eisprung", ov.formatted(.dateTime.day().month()), "circle.fill", .teal)
                } else if let n = analyse.naechstePeriodeStart {
                    statKarte("Nächste Periode", n.formatted(.dateTime.day().month()), "calendar", .purple)
                }
            }
            .padding(.horizontal)

            NavigationLink(destination: ZyklusAnalyseView()) {
                HStack {
                    Image(systemName: "chart.xyaxis.line").foregroundStyle(.pink)
                    Text("Detaillierte Analyse").font(.subheadline).fontWeight(.medium)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
        }
    }

    private func statKarte(_ titel: String, _ wert: String, _ symbol: String, _ farbe: Color) -> some View {
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

    // MARK: - Pain Correlation

    private var schmerzKorrelation: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Schmerz & Zyklus").font(.headline)
                Text("Ø Schmerzstärke je Zyklusphase")
                    .font(.caption).foregroundStyle(.secondary)
            }

            let daten = ZyklusRechner.schmerzJePhase(painEntries: Array(painEntries), analyse: analyse)

            if daten.isEmpty {
                Text("Noch nicht genug überlappende Daten.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
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
                .frame(height: 170)

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
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func phaseFarbe(_ p: ZyklusRechner.Zyklusphase) -> Color {
        switch p {
        case .menstruation: return .red
        case .follikelphase: return .yellow
        case .ovulation: return .orange
        case .lutealphase: return .purple
        }
    }
}

// MARK: - Helpers

private struct ZyklusTagAuswahl: Identifiable {
    let id = UUID()
    let datum: Date
}

// MARK: - Calendar

private struct ZyklusKalender: View {
    let monat: Date
    let eintraege: [ZyklusEintrag]
    let analyse: ZyklusAnalyse
    var onVorheriger: () -> Void
    var onNaechster: () -> Void
    let onTap: (Date) -> Void

    private let wochentage = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
    private let kal = Calendar.current

    private var monatsTitel: String {
        monat.formatted(.dateTime.month(.wide).year())
    }

    private var tageImMonat: [Date?] {
        guard let erster = kal.date(from: kal.dateComponents([.year, .month], from: monat)),
              let anzahl = kal.range(of: .day, in: .month, for: monat)?.count else { return [] }
        let wt = (kal.component(.weekday, from: erster) + 5) % 7
        var tage: [Date?] = Array(repeating: nil, count: wt)
        for d in 0..<anzahl {
            tage.append(kal.date(byAdding: .day, value: d, to: erster))
        }
        while tage.count % 7 != 0 { tage.append(nil) }
        return tage
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: onVorheriger) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 36, height: 36)
                }
                Spacer()
                Text(monatsTitel).font(.title3.bold())
                Spacer()
                Button(action: onNaechster) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 36, height: 36)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                ForEach(wochentage, id: \.self) { tag in
                    Text(tag)
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 6)
                }

                ForEach(Array(tageImMonat.enumerated()), id: \.offset) { _, datum in
                    if let datum {
                        let zustand = ZyklusRechner.tagZustand(datum: datum, analyse: analyse)
                        let eintrag = eintraege.first { kal.isDate($0.datum, inSameDayAs: datum) }
                        let hatSymptome = eintrag.map { !$0.symptome.isEmpty } ?? false
                        let fluss = eintrag?.blutungsfluss ?? ""
                        let sexAktiv = eintrag?.sexuelleAktivitaet ?? ""
                        let schleim = eintrag?.zervixschleim ?? ""
                        let hatSonstigeDaten = !(eintrag?.ovulationstest ?? "").isEmpty ||
                                               (eintrag?.basaltemperatur ?? 0) > 0 ||
                                               !(eintrag?.notizen ?? "").isEmpty
                        TagZelle(datum: datum, zustand: zustand, hatSymptome: hatSymptome, blutungsfluss: fluss, sexuelleAktivitaet: sexAktiv, zervixschleim: schleim, hatSonstigeDaten: hatSonstigeDaten) {
                            onTap(datum)
                        }
                    } else {
                        Color.clear.frame(height: 38)
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Day Cell

private struct TagZelle: View {
    let datum: Date
    let zustand: ZyklusTagZustand
    let hatSymptome: Bool
    let blutungsfluss: String
    let sexuelleAktivitaet: String
    let zervixschleim: String
    let hatSonstigeDaten: Bool
    let action: () -> Void

    private var istHeute: Bool { Calendar.current.isDateInToday(datum) }
    private var tagNummer: String { "\(Calendar.current.component(.day, from: datum))" }

    private var periodeHintergrund: Color {
        switch blutungsfluss {
        case "schmierblutung": return Color.red.opacity(0.2)
        case "leicht":         return Color.red.opacity(0.45)
        case "stark":          return Color.red
        default:               return Color.red.opacity(0.75)
        }
    }

    private var streakOpacity: Double {
        switch blutungsfluss {
        case "schmierblutung": return 0.08
        case "leicht":         return 0.14
        case "stark":          return 0.30
        default:               return 0.22
        }
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                // Streak band
                GeometryReader { geo in
                    if zustand.periode {
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.red.opacity(zustand.verbundenLinks ? streakOpacity : 0))
                                .frame(width: geo.size.width / 2)
                            Rectangle()
                                .fill(Color.red.opacity(zustand.verbundenRechts ? streakOpacity : 0))
                                .frame(width: geo.size.width / 2)
                        }
                        .frame(height: 32)
                        .frame(maxHeight: .infinity, alignment: .center)
                    } else if zustand.fruchtbar {
                        Rectangle()
                            .fill(Color.teal.opacity(0.12))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }

                VStack(spacing: 2) {
                    ZStack {
                        // Background circle
                        if zustand.periode {
                            Circle().fill(periodeHintergrund)
                        } else if zustand.ovulation {
                            Circle().fill(Color.orange)
                        } else if zustand.vorhergesagtePeriode {
                            Circle()
                                .fill(Color.red.opacity(0.1))
                                .overlay(Circle().stroke(Color.red.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
                        } else if zustand.fruchtbar {
                            Circle().fill(Color.teal.opacity(0.25))
                        }

                        // Today ring (when not period/ovulation)
                        if istHeute && !zustand.periode && !zustand.ovulation {
                            Circle().stroke(Color.primary, lineWidth: 1.5)
                        }

                        Text(tagNummer)
                            .font(.system(size: 13, weight: zustand.periode || istHeute ? .semibold : .regular))
                            .foregroundStyle(tagTextFarbe)
                    }
                    .frame(width: 30, height: 30)

                    // Status dots — fixed height, no placeholder artifacts
                    HStack(spacing: 2) {
                        if hatSymptome {
                            Circle().fill(Color.purple.opacity(0.6)).frame(width: 4, height: 4)
                        }
                        if !zervixschleim.isEmpty {
                            Circle().fill(Color.blue.opacity(0.7)).frame(width: 4, height: 4)
                        }
                        if !sexuelleAktivitaet.isEmpty {
                            Circle().fill(Color.pink.opacity(0.8)).frame(width: 4, height: 4)
                        }
                        if hatSonstigeDaten {
                            Circle().fill(Color.gray.opacity(0.5)).frame(width: 4, height: 4)
                        }
                    }
                    .frame(height: 6)
                }
            }
            .frame(height: 38)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.2), value: zustand.periode)
    }

    private var tagTextFarbe: Color {
        if zustand.ovulation { return .white }
        if zustand.periode {
            switch blutungsfluss {
            case "schmierblutung", "leicht": return .red.opacity(0.85)
            default: return .white
            }
        }
        if zustand.vorhergesagtePeriode { return .red.opacity(0.7) }
        if zustand.fruchtbar { return .teal }
        if istHeute { return .primary }
        return .secondary
    }
}

// MARK: - Entry Sheet

struct ZyklusEintragSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let datum: Date
    let bestehend: ZyklusEintrag?

    @AppStorage("zusatzSymptome") private var zusatzSymptomeRaw: String = ""
    @State private var neuesSymptom = ""

    @State private var istPeriode = false
    @State private var blutungsfluss = "mittel"
    @State private var symptome: Set<String> = []
    @State private var ovulationstest = ""
    @State private var zervixschleim = ""
    @State private var basaltemperatur = ""
    @State private var sexuelleAktivitaet = ""
    @State private var notizen = ""

    private let flussOptionen = ["schmierblutung", "leicht", "mittel", "stark"]
    private let basisSymptome = [
        "Krämpfe", "Kopfschmerzen", "Rückenschmerzen", "Brustspannen",
        "Völlegefühl", "Blähungen", "Übelkeit", "Müdigkeit",
        "Reizbarkeit", "Stimmungsschwankungen", "Akne", "Schlafprobleme",
        "Hitzewallungen", "Appetitsteigerung"
    ]
    private let schleimOptionen = ["trocken", "klebrig", "cremig", "wässrig", "Eiweiss"]

    private var alleSymptome: [String] {
        let custom = zusatzSymptomeRaw.isEmpty ? [] : zusatzSymptomeRaw.components(separatedBy: "|")
        return basisSymptome + custom.filter { !basisSymptome.contains($0) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(datum.formatted(.dateTime.day().month(.wide).year()))
                        .font(.subheadline.bold())
                }

                Section("Periode") {
                    Toggle("Blutung", isOn: $istPeriode)
                    if istPeriode {
                        Picker("Stärke", selection: $blutungsfluss) {
                            ForEach(flussOptionen, id: \.self) { Text($0.capitalized).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                Section("Symptome") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        ForEach(alleSymptome, id: \.self) { s in
                            Button {
                                if symptome.contains(s) { symptome.remove(s) } else { symptome.insert(s) }
                            } label: {
                                HStack {
                                    Image(systemName: symptome.contains(s) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(symptome.contains(s) ? .pink : .secondary)
                                    Text(s).font(.caption)
                                    Spacer()
                                }
                                .padding(.vertical, 3)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    HStack(spacing: 8) {
                        TextField("Eigenes Symptom hinzufügen", text: $neuesSymptom)
                            .font(.caption)
                            .submitLabel(.done)
                            .onSubmit { symptomHinzufuegen() }
                        Button(action: symptomHinzufuegen) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.pink)
                                .font(.title3)
                        }
                        .disabled(neuesSymptom.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.top, 4)
                }

                Section {
                    Picker("Ovulationstest", selection: $ovulationstest) {
                        Text("Kein Test").tag("")
                        Text("Positiv").tag("positiv")
                        Text("Negativ").tag("negativ")
                        Text("Unklar").tag("unklar")
                    }
                } header: {
                    HStack(spacing: 4) {
                        Text("Eisprung")
                        InfoButton(titel: "Ovulationstest (LH-Test)",
                                   text: "Ein LH-Test aus der Apotheke zeigt den Anstieg des luteinisierenden Hormons, der 24–36 Stunden vor dem Eisprung auftritt. Positiv = Eisprung steht bevor.")
                    }
                }

                Section {
                    Picker("Art", selection: $zervixschleim) {
                        Text("Nicht erfasst").tag("")
                        ForEach(schleimOptionen, id: \.self) { Text($0.capitalized).tag($0) }
                    }
                } header: {
                    HStack(spacing: 4) {
                        Text("Zervixschleim")
                        InfoButton(titel: "Zervixschleim-Typen",
                                   text: "Trocken: kein Schleim, eher unfruchtbar.\nKlebrig: zäh, trüb.\nCremig: weiß, cremig – Übergang.\nWässrig: klar, fließend – fruchtbar.\nEiweiss: dehnbar wie rohes Ei – höchste Fruchtbarkeit, typisch beim Eisprung.")
                    }
                }

                Section {
                    HStack {
                        TextField("z.B. 36.4", text: $basaltemperatur).keyboardType(.decimalPad)
                        Text("°C").foregroundStyle(.secondary)
                    }
                } header: {
                    HStack(spacing: 4) {
                        Text("Basaltemperatur")
                        InfoButton(titel: "Basaltemperatur",
                                   text: "Morgentemperatur direkt nach dem Aufwachen, vor jeder Aktivität. Nach dem Eisprung steigt sie um ca. 0,2–0,5 °C an und bleibt bis zur nächsten Periode erhöht.")
                    }
                }

                Section("Sexuelle Aktivität") {
                    Picker("", selection: $sexuelleAktivitaet) {
                        Text("Keine Angabe").tag("")
                        Text("Geschützt").tag("geschützt")
                        Text("Ungeschützt").tag("ungeschützt")
                    }
                    .pickerStyle(.segmented)
                }

                Section("Notizen") {
                    TextEditor(text: $notizen).frame(minHeight: 60)
                }
            }
            .navigationTitle("Tageseintrag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { abbrechen() } }
                ToolbarItem(placement: .confirmationAction) { Button("Speichern") { speichern() } }
                if bestehend != nil {
                    ToolbarItem(placement: .bottomBar) {
                        Button(role: .destructive) { loeschen() } label: {
                            Label("Eintrag löschen", systemImage: "trash")
                                .font(.caption)
                        }
                    }
                }
            }
            .onAppear { laden() }
        }
    }

    private func laden() {
        guard let e = bestehend else { return }
        istPeriode = e.istPeriode
        blutungsfluss = e.blutungsfluss.isEmpty ? "mittel" : e.blutungsfluss
        symptome = Set(e.symptome.components(separatedBy: ", ").filter { !$0.isEmpty })
        ovulationstest = e.ovulationstest
        zervixschleim = e.zervixschleim
        basaltemperatur = e.basaltemperatur > 0 ? String(format: "%.1f", e.basaltemperatur) : ""
        sexuelleAktivitaet = e.sexuelleAktivitaet
        notizen = e.notizen
    }

    private func symptomHinzufuegen() {
        let s = neuesSymptom.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty, !alleSymptome.contains(s) else { neuesSymptom = ""; return }
        var custom = zusatzSymptomeRaw.isEmpty ? [] : zusatzSymptomeRaw.components(separatedBy: "|")
        custom.append(s)
        zusatzSymptomeRaw = custom.joined(separator: "|")
        symptome.insert(s)
        neuesSymptom = ""
    }

    private var istLeer: Bool {
        !istPeriode &&
        symptome.isEmpty &&
        ovulationstest.isEmpty &&
        zervixschleim.isEmpty &&
        (Double(basaltemperatur.replacingOccurrences(of: ",", with: ".")) ?? 0) == 0 &&
        sexuelleAktivitaet.isEmpty &&
        notizen.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func speichern() {
        // Bestehenden Eintrag löschen wenn alle Felder geleert wurden
        if let alt = bestehend, istLeer {
            modelContext.delete(alt)
            dismiss()
            return
        }
        guard !istLeer else { dismiss(); return }

        let eintrag: ZyklusEintrag
        if let alt = bestehend {
            eintrag = alt
        } else {
            eintrag = ZyklusEintrag(datum: Calendar.current.startOfDay(for: datum))
            modelContext.insert(eintrag)
        }
        eintrag.istPeriode = istPeriode
        eintrag.blutungsfluss = istPeriode ? blutungsfluss : ""
        eintrag.symptome = symptome.sorted().joined(separator: ", ")
        eintrag.ovulationstest = ovulationstest
        eintrag.zervixschleim = zervixschleim
        eintrag.basaltemperatur = Double(basaltemperatur.replacingOccurrences(of: ",", with: ".")) ?? 0
        eintrag.sexuelleAktivitaet = sexuelleAktivitaet
        eintrag.notizen = notizen
        dismiss()
    }

    private func abbrechen() {
        // Ghost-Einträge ohne Daten beim Abbrechen bereinigen
        if let alt = bestehend, istLeer {
            modelContext.delete(alt)
        }
        dismiss()
    }

    private func loeschen() {
        if let alt = bestehend { modelContext.delete(alt) }
        dismiss()
    }
}
