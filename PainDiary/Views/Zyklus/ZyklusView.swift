import SwiftUI
import SwiftData
import Charts

struct ZyklusView: View {
    @Query(sort: \ZyklusEintrag.datum, order: .reverse) private var eintraege: [ZyklusEintrag]
    @Query(sort: \PainEntry.datum, order: .reverse) private var painEntries: [PainEntry]
    @Query(sort: \MigraeneEintrag.datum, order: .reverse) private var migraeneAnfaelle: [MigraeneEintrag]
    @Environment(\.modelContext) private var modelContext

    @State private var anzeigeMonat = Date()
    @State private var ausgewaehlterTag: ZyklusTagAuswahl? = nil
    @State private var zeigeAnalyse = false
    @State private var notifManager = NotificationManager.shared

    private var analyse: ZyklusAnalyse { ZyklusRechner.analyse(eintraege: Array(eintraege)) }

    var body: some View {
        List {
            Section {
                statistikKarte
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)

            if !analyse.zyklusStarts.isEmpty {
                Section {
                    Button { zeigeAnalyse = true } label: {
                        Label("Zyklusanalyse öffnen", systemImage: "chart.bar.xaxis.ascending")
                            .font(.subheadline.bold()).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Color.pink, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            }

            Section {
                kalenderMitLegende
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            Section("Heute erfassen") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        quickBtn("drop.fill", .red, "Periode") { logHeute(istPeriode: true, fluss: "mittel") }
                        quickBtn("circle.dotted", .orange, "Eisprung") { logHeute(ovuTest: "positiv") }
                        quickBtn("thermometer.medium", .blue, "Temperatur") { oeffneHeuteSheet() }
                        quickBtn("heart.text.square", .purple, "Symptome") { oeffneHeuteSheet() }
                        quickBtn("drop.halffull", .pink, "Schmierblutung") { logHeute(istPeriode: true, fluss: "schmierblutung") }
                        quickBtn("pencil", .green, "Notiz") { oeffneHeuteSheet() }
                    }
                    .padding(.vertical, 4).padding(.trailing, 8)
                }
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 0))

            zyklusNotifBanner

            if !painEntries.isEmpty && !analyse.zyklusStarts.isEmpty {
                Section {
                    schmerzKorrelation
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            if !migraeneAnfaelle.isEmpty && !analyse.zyklusStarts.isEmpty {
                Section {
                    migraeneKorrelation
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .navigationTitle("Zyklus")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { oeffneHeuteSheet() } label: { Image(systemName: "plus") }
            }
        }
        .sheet(item: $ausgewaehlterTag) { auswahl in
            ZyklusEintragSheet(
                datum: auswahl.datum,
                bestehend: eintraege.first { Calendar.current.isDate($0.datum, inSameDayAs: auswahl.datum) }
            )
        }
        .sheet(isPresented: $zeigeAnalyse) { ZyklusAnalyseView() }
        .onChange(of: eintraege) { _, _ in planeZyklusNotifs() }
        .onAppear { planeZyklusNotifs() }
    }

    private func planeZyklusNotifs() {
        NotificationManager.shared.planeZyklusErinnerungen(analyse: analyse)
    }

    // MARK: - Notification Banner

    @ViewBuilder
    private var zyklusNotifBanner: some View {
        if !analyse.zyklusStarts.isEmpty {
            if notifManager.status == .notDetermined {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "bell.badge.fill").font(.title3).foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Zyklus-Erinnerungen").font(.subheadline.bold())
                            Text("Erhalte Benachrichtigungen für Periode, fruchtbare Tage und Eisprung.")
                                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Button("Aktivieren") {
                            Task {
                                let granted = await notifManager.berechtigungAnfordern()
                                if granted { planeZyklusNotifs() }
                            }
                        }
                        .buttonStyle(.borderedProminent).controlSize(.small)
                    }
                }
                .listRowBackground(Color.orange.opacity(0.08))
            } else if notifManager.status == .denied {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "bell.slash.fill").font(.title3).foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Erinnerungen deaktiviert").font(.subheadline.bold())
                            Text("Aktiviere Benachrichtigungen in den iOS-Einstellungen.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
#if os(iOS)
                        Button("Einstellungen") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.caption).buttonStyle(.bordered).controlSize(.small)
#endif
                    }
                }
            }
        }
    }

    private func wechselMonat(_ richtung: Int) {
        withAnimation {
            anzeigeMonat = Calendar.current.date(byAdding: .month, value: richtung, to: anzeigeMonat) ?? anzeigeMonat
        }
    }

    // MARK: - Stats Header

    private var statistikKarte: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Zyklus-Überblick", systemImage: "drop.fill")
                .font(.headline).foregroundStyle(.pink)
            Divider()
            HStack(spacing: 0) {
                statPill(zyklusTagText, label: "Zyklustag",
                         farbe: analyse.aktuellerZyklustag != nil ? .pink : .secondary)
                Divider().frame(height: 40)
                statPill(naechstePeriodeBadge, label: "Nächste Periode", farbe: .red)
                Divider().frame(height: 40)
                statPill(zyklusLaengeText, label: "Ø Zyklus", farbe: .purple)
            }
            if analyse.aktuellerZyklustag != nil {
                Divider()
                fruchtbarkeitReihe(naechstesFruchtbaresF)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    private var zyklusTagText: String {
        analyse.aktuellerZyklustag.map { "Tag \($0)" } ?? "–"
    }

    private var zyklusLaengeText: String {
        analyse.zyklusStarts.count >= 2 ? String(format: "%.0f T", analyse.zykluslaenge) : "–"
    }

    private func fruchtbarkeitReihe(_ fenster: (Date, Date)?) -> some View {
        HStack(spacing: 0) {
            VStack(spacing: 3) {
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

            VStack(spacing: 3) {
                if let ov = analyse.vorhergesagteOvulation {
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
    }

    private func statPill(_ wert: String, label: String, farbe: Color) -> some View {
        VStack(spacing: 4) {
            Text(wert).font(.title2.bold()).foregroundStyle(farbe)
            Text(label).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Calendar Section

    private var kalenderMitLegende: some View {
        VStack(spacing: 12) {
            ZyklusKalender(
                monat: anzeigeMonat,
                eintraege: Array(eintraege),
                analyse: analyse,
                onVorheriger: { wechselMonat(-1) },
                onNaechster: { wechselMonat(1) }
            ) { tag in
                ausgewaehlterTag = ZyklusTagAuswahl(datum: tag)
            }
            legende
        }
    }

    private var legende: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                  alignment: .leading, spacing: 8) {
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

    // MARK: - Quick Log

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

    // MARK: - Correlations

    private var schmerzKorrelation: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Schmerz & Zyklus").font(.headline)
                Text("Ø Schmerzstärke je Zyklusphase").font(.caption).foregroundStyle(.secondary)
            }

            let daten = ZyklusRechner.schmerzJePhase(painEntries: Array(painEntries), analyse: analyse)

            if daten.isEmpty {
                Text("Noch nicht genug überlappende Daten.").font(.caption).foregroundStyle(.secondary)
            } else {
                Chart(daten, id: \.phase.rawValue) { d in
                    BarMark(x: .value("Phase", d.phase.rawValue), y: .value("Schmerz", d.avgSchmerz))
                        .foregroundStyle(phaseFarbe(d.phase).gradient).cornerRadius(6)
                        .annotation(position: .top) {
                            Text(String(format: "%.1f", d.avgSchmerz)).font(.caption2).foregroundStyle(.secondary)
                        }
                }
                .chartYScale(domain: 0...10).frame(height: 170)

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
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var migraeneKorrelation: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Migräne & Zyklus").font(.headline)
                Text("Anfälle je Zyklusphase").font(.caption).foregroundStyle(.secondary)
            }

            let daten = ZyklusRechner.migraeneJePhase(anfaelle: Array(migraeneAnfaelle), analyse: analyse)

            if daten.isEmpty {
                Text("Noch nicht genug überlappende Daten.").font(.caption).foregroundStyle(.secondary)
            } else {
                Chart(daten, id: \.phase.rawValue) { d in
                    BarMark(x: .value("Phase", d.phase.rawValue), y: .value("Anfälle", d.anzahl))
                        .foregroundStyle(phaseFarbe(d.phase).gradient).cornerRadius(6)
                        .annotation(position: .top) {
                            Text("\(d.anzahl)").font(.caption2).foregroundStyle(.secondary)
                        }
                }
                .chartYScale(domain: 0...(daten.map(\.anzahl).max().map { $0 + 1 } ?? 5))
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
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func phaseFarbe(_ p: ZyklusRechner.Zyklusphase) -> Color {
        switch p {
        case .menstruation: return .red
        case .follikelphase: return .yellow
        case .ovulation: return .orange
        case .lutealphase: return .purple
        }
    }

    // MARK: - Helpers

    private var naechstePeriodeBadge: String {
        guard let n = analyse.naechstePeriodeStart else { return "–" }
        let tage = Calendar.current.dateComponents([.day], from: Date(), to: n).day ?? 0
        if tage <= 0 { return "Heute" }
        return "in \(tage)d"
    }

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
                .buttonStyle(.plain)
                Spacer()
                Text(monatsTitel).font(.title3.bold())
                Spacer()
                Button(action: onNaechster) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
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
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
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

    // Data state
    @State private var istPeriode: Bool
    @State private var blutungsfluss: String
    @State private var nurHalberTag: Bool
    @State private var symptome: Set<String>
    @State private var ovulationstest: String
    @State private var zervixschleim: String
    @State private var basaltemperatur: String
    @State private var sexuelleAktivitaet: String
    @State private var notizen: String

    // Wizard state
    @State private var schritt = 0
    private let maxSchritt = 2
    private let pflichtSchritte: Set<Int> = [0]

    init(datum: Date, bestehend: ZyklusEintrag?) {
        self.datum = datum
        self.bestehend = bestehend
        if let e = bestehend {
            _istPeriode = State(initialValue: e.istPeriode)
            _blutungsfluss = State(initialValue: e.blutungsfluss.isEmpty ? "mittel" : e.blutungsfluss)
            _nurHalberTag = State(initialValue: e.nurHalberTag)
            _symptome = State(initialValue: Set(e.symptome.components(separatedBy: ", ").filter { !$0.isEmpty }))
            _ovulationstest = State(initialValue: e.ovulationstest)
            _zervixschleim = State(initialValue: e.zervixschleim)
            _basaltemperatur = State(initialValue: e.basaltemperatur > 0 ? String(format: "%.1f", e.basaltemperatur) : "")
            _sexuelleAktivitaet = State(initialValue: e.sexuelleAktivitaet)
            _notizen = State(initialValue: e.notizen)
        } else {
            _istPeriode = State(initialValue: false)
            _blutungsfluss = State(initialValue: "mittel")
            _nurHalberTag = State(initialValue: false)
            _symptome = State(initialValue: [])
            _ovulationstest = State(initialValue: "")
            _zervixschleim = State(initialValue: "")
            _basaltemperatur = State(initialValue: "")
            _sexuelleAktivitaet = State(initialValue: "")
            _notizen = State(initialValue: "")
        }
    }

    private let basisSymptome = [
        "Krämpfe", "Kopfschmerzen", "Rückenschmerzen", "Brustspannen",
        "Völlegefühl", "Blähungen", "Übelkeit", "Müdigkeit",
        "Reizbarkeit", "Stimmungsschwankungen", "Akne", "Schlafprobleme",
        "Hitzewallungen", "Appetitsteigerung"
    ]

    private var alleSymptome: [String] {
        let custom = zusatzSymptomeRaw.isEmpty ? [] : zusatzSymptomeRaw.components(separatedBy: "|")
        return basisSymptome + custom.filter { !basisSymptome.contains($0) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.pink.opacity(0.15)).frame(height: 3)
                        Capsule().fill(Color.pink)
                            .frame(width: geo.size.width * CGFloat(schritt + 1) / CGFloat(maxSchritt + 1), height: 3)
                            .animation(.easeInOut(duration: 0.3), value: schritt)
                    }
                }
                .frame(height: 3).padding(.horizontal).padding(.top, 10)

                Group {
                    switch schritt {
                    case 0: schritt0
                    case 1: schritt1
                    default: schritt2
                    }
                }
                .frame(maxHeight: .infinity)

                navigationsLeiste
            }
            .navigationTitle(datum.formatted(.dateTime.day().month(.wide).year()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { abbrechen() }
                }
                if bestehend != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) { loeschen() } label: {
                            Image(systemName: "trash").foregroundStyle(.red)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Step 0: Periode

    private var schritt0: some View {
        ScrollView {
            VStack(spacing: 20) {
                schrittHeader(symbol: "drop.fill", titel: "Periode", untertitel: "Hast du heute eine Blutung?")

                VStack(spacing: 0) {
                    Toggle("Blutung", isOn: $istPeriode)
                        .font(.subheadline).padding(16)

                    if istPeriode {
                        Divider().padding(.leading, 16)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Stärke").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                                ForEach([("schmierblutung", "Schmierblutung"), ("leicht", "Leicht"),
                                          ("mittel", "Mittel"), ("stark", "Stark")], id: \.0) { wert, label in
                                    let sel = blutungsfluss == wert
                                    Button { blutungsfluss = wert } label: {
                                        Text(label).font(.caption.bold()).frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(sel ? Color.red : Color(.tertiarySystemGroupedBackground))
                                            .foregroundStyle(sel ? .white : .primary)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .animation(.easeInOut(duration: 0.15), value: sel)
                                    }.buttonStyle(.plain)
                                }
                            }
                        }.padding(16)

                        Divider().padding(.leading, 16)
                        Toggle("Nur halber Tag", isOn: $nurHalberTag)
                            .font(.subheadline).padding(16)
                    }
                }
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                .animation(.easeInOut(duration: 0.2), value: istPeriode)
            }
            .padding(.horizontal).padding(.vertical, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Step 1: Symptome

    private var schritt1: some View {
        ScrollView {
            VStack(spacing: 20) {
                schrittHeader(symbol: "heart.text.square.fill", titel: "Symptome", untertitel: "Wie geht es dir heute?")

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(alleSymptome, id: \.self) { s in
                        let sel = symptome.contains(s)
                        Button {
                            if sel { symptome.remove(s) } else { symptome.insert(s) }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: sel ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(sel ? .pink : .secondary).font(.caption)
                                Text(s).font(.caption).lineLimit(1)
                                Spacer()
                            }
                            .padding(.horizontal, 10).padding(.vertical, 8)
                            .background(
                                sel ? Color.pink.opacity(0.12) : Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 10)
                            )
                        }
                        .buttonStyle(.plain)
                        .animation(.easeInOut(duration: 0.15), value: sel)
                    }
                }

                HStack(spacing: 8) {
                    TextField("Eigenes Symptom", text: $neuesSymptom)
                        .font(.subheadline).padding(14)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                        .submitLabel(.done).onSubmit { symptomHinzufuegen() }
                    Button(action: symptomHinzufuegen) {
                        Image(systemName: "plus.circle.fill").foregroundStyle(.pink).font(.title2)
                    }
                    .disabled(neuesSymptom.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(.horizontal).padding(.vertical, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Step 2: Weitere Daten

    private var schritt2: some View {
        ScrollView {
            VStack(spacing: 20) {
                schrittHeader(symbol: "waveform.path.ecg", titel: "Weitere Daten", untertitel: "Eisprung, Schleim & Temperatur")

                // Ovulationstest
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 4) {
                        Text("Ovulationstest (LH-Test)").font(.caption).foregroundStyle(.secondary)
                        InfoButton(titel: "Ovulationstest (LH-Test)",
                                   text: "Ein LH-Test aus der Apotheke zeigt den Anstieg des luteinisierenden Hormons, der 24–36 Stunden vor dem Eisprung auftritt. Positiv = Eisprung steht bevor.")
                    }.padding(.horizontal, 4)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                        ForEach([("", "Kein Test"), ("positiv", "Positiv"),
                                  ("negativ", "Negativ"), ("unklar", "Unklar")], id: \.0) { wert, label in
                            let sel = ovulationstest == wert
                            Button { ovulationstest = wert } label: {
                                Text(label).font(.caption.bold()).frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(sel ? Color.orange : Color(.secondarySystemGroupedBackground))
                                    .foregroundStyle(sel ? .white : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }.buttonStyle(.plain)
                        }
                    }
                }

                // Zervixschleim
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 4) {
                        Text("Zervixschleim").font(.caption).foregroundStyle(.secondary)
                        InfoButton(titel: "Zervixschleim-Typen",
                                   text: "Trocken: kein Schleim, eher unfruchtbar.\nKlebrig: zäh, trüb.\nCremig: weiß, cremig – Übergang.\nWässrig: klar, fließend – fruchtbar.\nEiweiss: dehnbar wie rohes Ei – höchste Fruchtbarkeit, typisch beim Eisprung.")
                    }.padding(.horizontal, 4)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                        ForEach([("", "Nicht erfasst"), ("trocken", "Trocken"), ("klebrig", "Klebrig"),
                                  ("cremig", "Cremig"), ("wässrig", "Wässrig"), ("Eiweiss", "Eiweiss")], id: \.0) { wert, label in
                            let sel = zervixschleim == wert
                            Button { zervixschleim = wert } label: {
                                Text(label).font(.caption.bold()).frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(sel ? Color.blue : Color(.secondarySystemGroupedBackground))
                                    .foregroundStyle(sel ? .white : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }.buttonStyle(.plain)
                        }
                    }
                }

                // Basaltemperatur
                VStack(spacing: 0) {
                    HStack {
                        HStack(spacing: 4) {
                            Text("Basaltemperatur").font(.subheadline)
                            InfoButton(titel: "Basaltemperatur",
                                       text: "Morgentemperatur direkt nach dem Aufwachen, vor jeder Aktivität. Nach dem Eisprung steigt sie um ca. 0,2–0,5 °C an und bleibt bis zur nächsten Periode erhöht.")
                        }
                        Spacer()
                        HStack(spacing: 4) {
                            TextField("36.4", text: $basaltemperatur)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                            Text("°C").foregroundStyle(.secondary)
                        }
                    }.padding(16)
                }
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))

                // Sexuelle Aktivität
                VStack(alignment: .leading, spacing: 10) {
                    Text("Sexuelle Aktivität").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                        ForEach([("", "Keine Angabe"), ("geschützt", "Geschützt"),
                                  ("ungeschützt", "Ungeschützt")], id: \.0) { wert, label in
                            let sel = sexuelleAktivitaet == wert
                            Button { sexuelleAktivitaet = wert } label: {
                                Text(label).font(.caption.bold()).frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(sel ? Color.pink : Color(.secondarySystemGroupedBackground))
                                    .foregroundStyle(sel ? .white : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }.buttonStyle(.plain)
                        }
                    }
                }

                // Notizen
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notizen").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
                    TextEditor(text: $notizen)
                        .font(.subheadline).frame(minHeight: 80)
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal).padding(.vertical, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Navigation

    private var navigationsLeiste: some View {
        HStack(spacing: 12) {
            if schritt > 0 {
                Button { withAnimation { schritt -= 1 } } label: {
                    Text("Zurück").font(.subheadline.bold()).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
            }
            if !pflichtSchritte.contains(schritt) && schritt < maxSchritt {
                Button { withAnimation { schritt += 1 } } label: {
                    Text("Überspringen").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            if schritt < maxSchritt {
                Button { withAnimation { schritt += 1 } } label: {
                    Text("Weiter ›").font(.subheadline.bold()).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color.pink, in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
            } else {
                Button { speichern() } label: {
                    Label("Speichern", systemImage: "checkmark").font(.subheadline.bold()).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color.pink, in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private func schrittHeader(symbol: String, titel: String, untertitel: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 32)).foregroundStyle(.pink)
            Text(titel).font(.title3.bold())
            Text(untertitel).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.bottom, 4)
    }

    // MARK: - Actions

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
        eintrag.nurHalberTag = istPeriode ? nurHalberTag : false
        eintrag.symptome = symptome.sorted().joined(separator: ", ")
        eintrag.ovulationstest = ovulationstest
        eintrag.zervixschleim = zervixschleim
        eintrag.basaltemperatur = Double(basaltemperatur.replacingOccurrences(of: ",", with: ".")) ?? 0
        eintrag.sexuelleAktivitaet = sexuelleAktivitaet
        eintrag.notizen = notizen
        dismiss()
    }

    private func abbrechen() {
        if let alt = bestehend, istLeer { modelContext.delete(alt) }
        dismiss()
    }

    private func loeschen() {
        if let alt = bestehend { modelContext.delete(alt) }
        dismiss()
    }
}
