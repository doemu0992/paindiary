import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Query(sort: \PainEntry.datum, order: .reverse) private var eintraege: [PainEntry]
    @Query private var profile: [Benutzerprofil]
    @Query private var medikamente: [Dauermedikation]
    @Query(sort: \MIDASBewertung.datum, order: .reverse) private var midasBewertungen: [MIDASBewertung]
    @Query(sort: \ZyklusEintrag.datum, order: .reverse) private var zyklusEintraege: [ZyklusEintrag]
    @Query(sort: \EinnahmeLog.datum, order: .reverse) private var einnahmeLogs: [EinnahmeLog]
    @Query(sort: \HAQEintrag.datum, order: .reverse) private var haqEintraege: [HAQEintrag]
    @Query(sort: \Laborwert.datum, order: .reverse) private var laborwerte: [Laborwert]
    @Query(sort: \MigraeneEintrag.datum, order: .reverse) private var migraeneAnfaelle: [MigraeneEintrag]
    @Query(sort: \BlutzuckerEintrag.datum, order: .reverse) private var blutzuckerMessungen: [BlutzuckerEintrag]
    @Query(sort: \WellnessEintrag.datum, order: .reverse) private var wellnessEintraege: [WellnessEintrag]
    @Query(sort: \Diagnose.bezeichnung) private var alleDiagnosen: [Diagnose]
    @State private var viewModel = DashboardViewModel()
    @State private var exportURL: URL? = nil
    @State private var pdfVorschauAnzeigen = false
    @State private var exportOptionsAnzeigen = false
    @State private var exportOptionen = ExportOptionen()
    @State private var istAmExportieren = false
    @State private var tagesstart = Calendar.current.startOfDay(for: Date())
    @State private var kachelKonfig: [KachelKonfiguration] = .laden()
    @State private var anpassenAnzeigen = false
    @State private var zeigeGesamtAnalyse = false
    @State private var medAusgewaehltTag: Date? = nil
    @State private var medVersteckTask: Task<Void, Never>? = nil
    @Environment(\.scenePhase) private var scenePhase
    @State private var schlafNächte: [SleepNightSummary] = SleepNightSummary.laden()

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                begrüssungsHeader

                ForEach(sichtbareKacheln, id: \.id) { kachel in
                    kachelView(kachel)
                }
            }
            .padding()
        }
        .navigationTitle("Übersicht")
        .navigationBarTitleDisplayMode(.large)
        .onChange(of: eintraege)    { _, neu in viewModel.eintraege = neu }
        .onChange(of: scenePhase)   { _, phase in if phase == .active { tagesstart = Calendar.current.startOfDay(for: Date()); schlafNächte = SleepNightSummary.laden() } }
        .onChange(of: kachelKonfig) { _, neu in neu.speichern() }
        .onAppear { viewModel.eintraege = eintraege }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { anpassenAnzeigen = true } label: {
                    Label("Anpassen", systemImage: "slider.horizontal.3")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Group {
                    if istAmExportieren {
                        ProgressView().progressViewStyle(.circular)
                    } else {
                        Button { exportOptionsAnzeigen = true } label: {
                            Label("Exportieren", systemImage: "square.and.arrow.up")
                        }
                        .disabled(eintraege.isEmpty)
                    }
                }
            }
        }
        .sheet(isPresented: $anpassenAnzeigen) {
            DashboardAnpassenView(kacheln: $kachelKonfig)
        }
#if os(iOS)
        .sheet(isPresented: $exportOptionsAnzeigen) {
            ExportOptionsSheet(
                optionen: $exportOptionen,
                hatZyklusDaten: !zyklusEintraege.isEmpty,
                hatRheumaDaten: !haqEintraege.isEmpty || !laborwerte.isEmpty,
                hatMigraeneDaten: !migraeneAnfaelle.isEmpty
            ) {
                exportOptionsAnzeigen = false
                exportierePDF()
            }
        }
        .sheet(isPresented: $pdfVorschauAnzeigen) {
            if let url = exportURL { PDFPreviewView(url: url) }
        }
#endif
        .sheet(isPresented: $zeigeGesamtAnalyse) {
            GesamtAnalyseView()
        }
    }

    // MARK: - Kachel-System

    private var sichtbareKacheln: [KachelKonfiguration] {
        kachelKonfig.filter { kachel in
            guard kachel.sichtbar else { return false }
            switch kachel.typ {
            case .medikamente: return !medikamente.filter(\.aktiv).isEmpty
            default:           return true
            }
        }
    }

    @ViewBuilder
    private func kachelView(_ kachel: KachelKonfiguration) -> some View {
        switch kachel.typ {
        case .schmerzUebersicht:   heuteKarte
        case .schmerzverlauf:      schmerzVerlaufChart
        case .stimmungStress:      stimmungStressKarte
        case .medikamente:         medikamentenKarte
        case .zyklus:              ZyklusKachel(eintraege: Array(zyklusEintraege))
        case .hautveraenderung:    HautKachel(eintraege: Array(eintraege.filter { $0.istHautEintrag }))
        case .schnellLinks:        schnellLinks
        case .wetterSchmerz:       WetterSchmerzKachel(eintraege: Array(eintraege.filter { !$0.istHautEintrag && $0.koerperstelle != "Rheuma" }))
        case .stressSchmerz:       StressSchmerzKachel(eintraege: Array(eintraege.filter { !$0.istHautEintrag && $0.koerperstelle != "Rheuma" }))
        case .schlafSchmerz:       SchlafSchmerzKachel(eintraege: Array(eintraege.filter { !$0.istHautEintrag && $0.koerperstelle != "Rheuma" }))
        case .midasKachel:         MidasKachel(bewertungen: Array(midasBewertungen))
        case .schmerzKachel:       SchmerzKachel(eintraege: Array(eintraege.filter { !$0.istHautEintrag && $0.koerperstelle != "Rheuma" }))
        case .migraeneKachel:      MigraeneKachel(anfaelle: Array(migraeneAnfaelle))
        case .rheumaKachel:        RheumaKachel(eintraege: Array(eintraege.filter { $0.koerperstelle == "Rheuma" }), haqEintraege: Array(haqEintraege))
        case .diabetesKachel:      DiabetesKachel(messungen: Array(blutzuckerMessungen))
        case .wellnessKachel:      WellnessKachel(eintraege: Array(eintraege), wellnessEintraege: Array(wellnessEintraege))
        case .schlafKachel:        SchlafKachel(nächte: schlafNächte)
        case .konfigKorrelation:
            KonfigKorrelationsKachel(
                kachel: kachel,
                eintraege: Array(eintraege),
                einnahmeLogs: Array(einnahmeLogs)
            )
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func miniStat(_ label: String, wert: String, farbe: Color) -> some View {
        VStack(spacing: 3) {
            Text(wert).font(.subheadline.bold()).foregroundStyle(farbe)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var trendVorwoche: Double? {
        var kal = Calendar.current
        kal.firstWeekday = 2  // Montag
        guard let interval = kal.dateInterval(of: .weekOfYear, for: Date()),
              let vorwocheStart = kal.date(byAdding: .weekOfYear, value: -1, to: interval.start) else { return nil }
        let diese = eintraege.filter { $0.datum >= interval.start && $0.datum < interval.end && !$0.istHautEintrag }
        let vorw  = eintraege.filter { $0.datum >= vorwocheStart && $0.datum < interval.start && !$0.istHautEintrag }
        guard !diese.isEmpty && !vorw.isEmpty else { return nil }
        let a = Double(diese.map(\.schmerzstaerke).reduce(0, +)) / Double(diese.count)
        let b = Double(vorw.map(\.schmerzstaerke).reduce(0, +)) / Double(vorw.count)
        return a - b
    }

    @ViewBuilder
    private var trendBadge: some View {
        let t = trendVorwoche
        let sym: String = t.map { $0 > 0.05 ? "arrow.up" : $0 < -0.05 ? "arrow.down" : "minus" } ?? "minus"
        let farbe: Color = t.map { $0 > 0.05 ? Color.red : $0 < -0.05 ? Color.green : Color.secondary } ?? .secondary
        let label = t.map { String(format: "%+.1f", $0) } ?? "–"
        HStack(spacing: 4) {
            Image(systemName: sym).font(.caption.bold())
            Text(label).font(.caption.bold())
        }
        .foregroundStyle(farbe)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(farbe.opacity(0.12), in: Capsule())
    }

    // MARK: - Greeting

    private var begrüssungsHeader: some View {
        let stunde = Calendar.current.component(.hour, from: Date())
        let grussBase = stunde < 12 ? "Guten Morgen" : stunde < 18 ? "Guten Tag" : "Guten Abend"
        let vorname = profile.first?.vorname.trimmingCharacters(in: .whitespaces) ?? ""
        let gruss = vorname.isEmpty ? grussBase : "\(grussBase), \(vorname)"
        let df = DateFormatter(); df.dateFormat = "EEEE, d. MMMM"; df.locale = Locale(identifier: "de_CH")
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(gruss).font(.title2.bold())
                Text(df.string(from: Date())).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Heute-Karte

    private var heuteKarte: some View {
        let avg = viewModel.durchschnittsSchmerz
        let farbe = SchmerzBadge.farbe(fuer: Int(avg.rounded()))
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Ø Schmerzstärke").font(.caption).foregroundStyle(.secondary)
                        InfoButton(
                            titel: "Ø Schmerzstärke",
                            text: "Gesamtdurchschnitt aller Schmerzeinträge. Der Trend-Badge (↑/↓) vergleicht die aktuelle Kalenderwoche (Mo–So) mit der Vorwoche – grün = Verbesserung, rot = Verschlechterung."
                        )
                    }
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text(String(format: "%.1f", avg))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(farbe)
                        Text("/ 10").font(.title3).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    trendBadge
                    Text("vs. Vorwoche").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Divider()
            HStack(spacing: 0) {
                miniStat("Diese Woche", wert: String(format: "%.1f", viewModel.wochenschmerz), farbe: .blue)
                Divider().frame(height: 36)
                miniStat("Einträge", wert: "\(eintraege.filter { !$0.istHautEintrag }.count)", farbe: .indigo)
                Divider().frame(height: 36)
                miniStat("Top Auslöser", wert: viewModel.haeufigsterAusloeser ?? "–", farbe: .orange)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    // MARK: - Medikamente

    private var medAktivePlan: [Dauermedikation] {
        let notif = NotificationManager.shared
        return medikamente.filter { $0.aktiv && $0.frequenz != "Bei Bedarf" && notif.anzahlDosen($0.frequenz) > 0 }
    }

    private var medAdherenz7T: Double {
        let notif = NotificationManager.shared
        let kal = Calendar.current
        var erwartet = 0; var eingenommen = 0
        for offset in 0..<7 {
            guard let tag = kal.date(byAdding: .day, value: -offset, to: tagesstart),
                  let tagEnde = kal.date(byAdding: .day, value: 1, to: tag) else { continue }
            for med in medAktivePlan {
                let n = notif.anzahlDosen(med.frequenz)
                erwartet += n
                let g = einnahmeLogs.filter {
                    $0.medikamentName == med.name && $0.dosierung == med.dosierung &&
                    $0.eingenommen && $0.datum >= tag && $0.datum < tagEnde
                }.count
                eingenommen += min(g, n)
            }
        }
        return erwartet > 0 ? Double(eingenommen) / Double(erwartet) * 100 : 0
    }

    private var medHeuteErwartet: Int {
        let notif = NotificationManager.shared
        return medikamente.filter(\.aktiv).map { notif.anzahlDosen($0.frequenz) }.reduce(0, +)
    }

    private var medHeuteEingenommen: Int {
        let notif = NotificationManager.shared
        let tagesende = Calendar.current.date(byAdding: .day, value: 1, to: tagesstart) ?? tagesstart
        let heuteLogs = einnahmeLogs.filter { $0.datum >= tagesstart && $0.datum < tagesende && $0.eingenommen }
        return medikamente.filter(\.aktiv).map { med in
            let n = notif.anzahlDosen(med.frequenz)
            guard n > 0 else { return 0 }
            return min(n, heuteLogs.filter { $0.medikamentName == med.name && $0.dosierung == med.dosierung }.count)
        }.reduce(0, +)
    }

    private var medChartDaten: [(datum: Date, prozent: Double, hatDaten: Bool)] {
        let notif = NotificationManager.shared
        let kal = Calendar.current
        return (0..<14).compactMap { offset -> (datum: Date, prozent: Double, hatDaten: Bool)? in
            guard let tag = kal.date(byAdding: .day, value: -(13 - offset), to: tagesstart),
                  let tagEnde = kal.date(byAdding: .day, value: 1, to: tag) else { return nil }
            var erw = 0; var ein = 0
            for med in medAktivePlan {
                guard med.startDatum <= tagEnde else { continue }
                let n = notif.anzahlDosen(med.frequenz)
                erw += n
                let g = einnahmeLogs.filter {
                    $0.medikamentName == med.name && $0.dosierung == med.dosierung &&
                    $0.eingenommen && $0.datum >= tag && $0.datum < tagEnde
                }.count
                ein += min(g, n)
            }
            let p = erw > 0 ? Double(ein) / Double(erw) * 100 : 0
            return (datum: tag, prozent: p, hatDaten: erw > 0)
        }
    }

    private var medikamentenKarte: some View {
        let hatDaten = medChartDaten.contains { $0.hatDaten && $0.prozent > 0 }
        let adFarbe: Color = medAdherenz7T >= 80 ? .green : medAdherenz7T >= 50 ? .orange : medAdherenz7T > 0 ? .red : .secondary
        let heuteFarbe: Color = medHeuteErwartet == 0 ? .secondary : medHeuteEingenommen >= medHeuteErwartet ? .green : .blue

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Medikamente", systemImage: "pill.fill")
                    .font(.headline).foregroundStyle(.blue)
                Spacer()
                NavigationLink(destination: MedikamenteView()) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3).foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 0) {
                miniStat("Adherenz", wert: medAdherenz7T > 0 ? String(format: "%.0f%%", medAdherenz7T) : "–", farbe: adFarbe)
                Divider().frame(height: 32)
                miniStat("Heute", wert: medHeuteErwartet > 0 ? "\(medHeuteEingenommen)/\(medHeuteErwartet)" : "–", farbe: heuteFarbe)
                Divider().frame(height: 32)
                miniStat("Aktiv", wert: "\(medikamente.filter(\.aktiv).count)", farbe: .secondary)
            }

            Chart(medChartDaten, id: \.datum) { punkt in
                BarMark(
                    x: .value("Tag", punkt.datum, unit: .day),
                    y: .value("Adherenz", hatDaten ? (punkt.hatDaten ? max(punkt.prozent, 4) : 0) : 1.0)
                )
                .foregroundStyle(
                    hatDaten && punkt.hatDaten
                        ? (punkt.prozent >= 80 ? Color.green.opacity(0.75)
                           : punkt.prozent >= 50 ? Color.orange.opacity(0.75)
                           : Color.red.opacity(0.75))
                        : Color.blue.opacity(0.07)
                )
                .cornerRadius(3)
            }
            .chartXAxis(.hidden).chartYAxis(.hidden)
            .frame(height: 44)
            .chartOverlay { proxy in
                GeometryReader { _ in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .onTapGesture { location in medBalkenTippen(proxy: proxy, location: location) }
                }
            }
            .overlay(alignment: .center) {
                if !hatDaten {
                    Text("Noch keine Einträge").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: medAusgewaehltTag)

            if let tag = medAusgewaehltTag, let punkt = medChartDaten.first(where: { Calendar.current.isDate($0.datum, inSameDayAs: tag) }) {
                HStack(spacing: 6) {
                    Text(tag, format: .dateTime.weekday(.abbreviated).day().month())
                        .font(.caption2.bold()).foregroundStyle(.secondary)
                    if punkt.hatDaten {
                        Text(String(format: "%.0f%%", punkt.prozent))
                            .font(.caption2)
                            .foregroundStyle(punkt.prozent >= 80 ? .green : punkt.prozent >= 50 ? .orange : .red)
                    }
                    Spacer()
                }
                .transition(.opacity)
            }

            Divider()

            NavigationLink(destination: MedikamenteView()) {
                HStack {
                    Text("Medikamente öffnen").font(.caption.bold()).foregroundStyle(.blue)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption2.bold()).foregroundStyle(Color.blue.opacity(0.6))
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    // MARK: - Schmerzverlauf

    private var schmerzVerlaufChart: some View {
        SchmerzVerlaufKarte(
            eintraege: Array(eintraege),
            migraeneAnfaelle: Array(migraeneAnfaelle),
            zeigeStats: true,
            onGesamtAnalyseOeffnen: { zeigeGesamtAnalyse = true }
        )
    }

    // MARK: - Stimmung & Stress

    private var stimmungStressKarte: some View {
        let kal = Calendar.current
        let wStart = kal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let woche = eintraege.filter { $0.datum >= wStart && !$0.istHautEintrag }
        let stimmungW = woche.filter { $0.stimmung > 0 }.map(\.stimmung)
        let avgStimmung = stimmungW.isEmpty ? 0.0 : Double(stimmungW.reduce(0, +)) / Double(stimmungW.count)
        let stressW = woche.filter { $0.stressLevel > 0 }.map(\.stressLevel)
        let avgStress = stressW.isEmpty ? 0.0 : Double(stressW.reduce(0, +)) / Double(stressW.count)
        let schlafW = woche.filter { $0.schlafStunden > 0 }.map(\.schlafStunden)
        let avgSchlaf = schlafW.isEmpty ? 0.0 : schlafW.reduce(0, +) / Double(schlafW.count)
        let schlafFarbe: Color = avgSchlaf >= 7 ? .green : avgSchlaf >= 5 ? .orange : .red

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Stimmung & Stress", systemImage: "heart.text.square.fill")
                    .font(.headline).foregroundStyle(.pink)
                InfoButton(
                    titel: "Stimmung & Stress",
                    text: "Wochen-Ø deiner Stimmung (1 = Schlecht, 5 = Super), deines Stresslevels (1 = Entspannt, 5 = Extrem) und Schlafdauer – aus den Einträgen der letzten 7 Tage."
                )
                Spacer()
            }
            Divider()
            if stimmungW.isEmpty && stressW.isEmpty && schlafW.isEmpty {
                Text("Noch keine Wohlbefindens-Daten diese Woche.")
                    .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 8)
            } else {
                HStack(spacing: 0) {
                    VStack(spacing: 6) {
                        Text(avgStimmung > 0 ? stimmungLabel(Int(avgStimmung.rounded())) : "–")
                            .font(.subheadline.bold())
                            .foregroundStyle(avgStimmung > 0 ? stimmungFarbe(Int(avgStimmung.rounded())) : .secondary)
                        Image(systemName: "heart.fill").font(.caption)
                            .foregroundStyle(avgStimmung > 0 ? stimmungFarbe(Int(avgStimmung.rounded())) : .secondary)
                        Text("Stimmung").font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    Divider().frame(height: 56)
                    VStack(spacing: 6) {
                        Text(avgStress > 0 ? stressLabel(Int(avgStress.rounded())) : "–")
                            .font(.subheadline.bold())
                            .foregroundStyle(avgStress > 0 ? stressFarbe(Int(avgStress.rounded())) : .secondary)
                        HStack(spacing: 3) {
                            ForEach(1...5, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Double(i) <= avgStress ? stressFarbe(Int(avgStress.rounded())) : Color.secondary.opacity(0.2))
                                    .frame(width: 8, height: 12)
                            }
                        }
                        Text("Stress").font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    Divider().frame(height: 56)
                    VStack(spacing: 6) {
                        Text(avgSchlaf > 0 ? String(format: "%.1fh", avgSchlaf) : "–")
                            .font(.subheadline.bold()).foregroundStyle(avgSchlaf > 0 ? schlafFarbe : .secondary)
                        Image(systemName: "moon.zzz.fill").font(.caption)
                            .foregroundStyle(avgSchlaf > 0 ? schlafFarbe : .secondary)
                        Text("Schlaf").font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    // MARK: - Schnelllinks

    private var schnellLinks: some View {
        HStack(spacing: 12) {
            NavigationLink(destination: MIDASView()) {
                HStack {
                    Image(systemName: "brain.head.profile").foregroundStyle(.purple)
                    Text("MIDAS-Score").font(.subheadline).fontWeight(.medium)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            NavigationLink(destination: KorrelationsView()) {
                HStack {
                    Image(systemName: "chart.xyaxis.line").foregroundStyle(.teal)
                    Text("Analysen").font(.subheadline).fontWeight(.medium)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Label helpers

    private func stimmungLabel(_ s: Int) -> String {
        switch s { case 1: "Schlecht"; case 2: "Mässig"; case 3: "Okay"; case 4: "Gut"; default: "Super" }
    }
    private func stimmungFarbe(_ s: Int) -> Color {
        switch s { case 1: .red; case 2: .orange; case 3: .yellow; case 4: .mint; default: .green }
    }
    private func stressLabel(_ s: Int) -> String {
        switch s { case 1: "Entspannt"; case 2: "Leicht"; case 3: "Mässig"; case 4: "Hoch"; default: "Extrem" }
    }
    private func stressFarbe(_ s: Int) -> Color {
        switch s { case 1: .green; case 2: .mint; case 3: .yellow; case 4: .orange; default: .red }
    }

    private func medBalkenTippen(proxy: ChartProxy, location: CGPoint) {
        guard let date: Date = proxy.value(atX: location.x, as: Date.self) else { return }
        let snapped = medChartDaten.min(by: {
            abs($0.datum.timeIntervalSince(date)) < abs($1.datum.timeIntervalSince(date))
        })?.datum
        guard let snapped else { return }
        withAnimation { medAusgewaehltTag = snapped }
        medVersteckTask?.cancel()
        medVersteckTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            await MainActor.run { withAnimation { medAusgewaehltTag = nil } }
        }
    }

    // MARK: - PDF

    private func exportierePDF() {
#if os(iOS)
        istAmExportieren = true
        PDFExportService.shared.erstellePDFAsync(
            eintraege: Array(eintraege),
            medikamente: Array(medikamente),
            einnahmeLogs: Array(einnahmeLogs),
            midasBewertungen: Array(midasBewertungen),
            zyklusEintraege: Array(zyklusEintraege),
            haqEintraege: Array(haqEintraege),
            laborwerte: Array(laborwerte),
            alleDiagnosen: Array(alleDiagnosen),
            migraeneAnfaelle: Array(migraeneAnfaelle),
            profil: profile.first,
            optionen: exportOptionen
        ) { @MainActor url in
            istAmExportieren = false
            if let url { exportURL = url; pdfVorschauAnzeigen = true }
        }
#endif
    }
}

// MARK: - Export Sheet

#if os(iOS)
private struct ExportOptionsSheet: View {
    @Binding var optionen: ExportOptionen
    @Environment(\.dismiss) private var dismiss
    let hatZyklusDaten: Bool
    let hatRheumaDaten: Bool
    let hatMigraeneDaten: Bool
    let onExport: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Zeitraum") {
                    Picker("Zeitraum", selection: $optionen.zeitraum) {
                        ForEach(ExportZeitraum.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.inline).labelsHidden()
                }
                Section("Abschnitte") {
                    Toggle("Zusammenfassung",      isOn: $optionen.mitZusammenfassung)
                    Toggle("Medikamente",          isOn: $optionen.mitMedikamente)
                    Toggle("Medikamenten-Dossier", isOn: $optionen.mitMedikamentDossier)
                    if hatRheumaDaten { Toggle("Rheuma & Gelenke", isOn: $optionen.mitRheuma) }
                    if hatZyklusDaten { Toggle("Zyklus", isOn: $optionen.mitZyklus) }
                    if hatMigraeneDaten { Toggle("Migräne", isOn: $optionen.mitMigraene) }
                    Toggle("Alle Einträge",        isOn: $optionen.mitEintraege)
                }
            }
            .navigationTitle("PDF exportieren")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Exportieren", action: onExport) }
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
            }
        }
        .presentationDetents([.medium])
    }
}
#endif

// MARK: - Supporting Views

