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
    @State private var viewModel = DashboardViewModel()
    @State private var exportURL: URL? = nil
    @State private var pdfVorschauAnzeigen = false
    @State private var exportOptionsAnzeigen = false
    @State private var exportOptionen = ExportOptionen()
    @State private var istAmExportieren = false
    @State private var tagesstart = Calendar.current.startOfDay(for: Date())
    @State private var kachelKonfig: [KachelKonfiguration] = .laden()
    @State private var anpassenAnzeigen = false
    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                begrüssungsHeader

                ForEach(Array(sichtbareKacheln.enumerated()), id: \.element.id) { index, kachel in
                    let prevAbschnitt: String? = index > 0 ? sichtbareKacheln[index - 1].typ.abschnitt : nil
                    if kachel.typ.abschnitt != prevAbschnitt {
                        abschnittTitel(kachel.typ.abschnitt)
                    }
                    kachelView(kachel)
                }
            }
            .padding()
        }
        .navigationTitle("Übersicht")
        .onChange(of: eintraege)    { _, neu in viewModel.eintraege = neu }
        .onChange(of: scenePhase)   { _, phase in if phase == .active { tagesstart = Calendar.current.startOfDay(for: Date()) } }
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
                hatZyklusDaten: !zyklusEintraege.isEmpty
            ) {
                exportOptionsAnzeigen = false
                exportierePDF()
            }
        }
        .sheet(isPresented: $pdfVorschauAnzeigen) {
            if let url = exportURL { PDFPreviewView(url: url) }
        }
#endif
    }

    // MARK: - Kachel-System

    private var sichtbareKacheln: [KachelKonfiguration] {
        kachelKonfig.filter { kachel in
            guard kachel.sichtbar else { return false }
            switch kachel.typ {
            case .medikamente:      return !medikamente.filter(\.aktiv).isEmpty
            case .zyklus:           return profile.first?.zyklusTrackingAktiv == true
            case .hautveraenderung: return !eintraege.filter(\.istHautEintrag).isEmpty
            default:                return true
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
        case .zyklus:              zyklusKarte
        case .hautveraenderung:    hautVeraenderungKarte
        case .schnellLinks:        schnellLinks
        case .wetterSchmerz:       WetterSchmerzKachel(eintraege: Array(eintraege))
        case .stressSchmerz:       StressSchmerzKachel(eintraege: Array(eintraege))
        case .schlafSchmerz:       SchlafSchmerzKachel(eintraege: Array(eintraege))
        case .tageszeitVerteilung: TageszeitKachel(eintraege: Array(eintraege))
        case .koerperstellen:      KoerperstellenKachel(eintraege: Array(eintraege))
        case .schmerzarten:        SchmerzartenKachel(eintraege: Array(eintraege))
        case .stimmungsTrend:      StimmungsTrendKachel(eintraege: Array(eintraege))
        case .midasKachel:         MidasKachel(bewertungen: Array(midasBewertungen))
        case .konfigKorrelation:
            KonfigKorrelationsKachel(
                kachel: kachel,
                eintraege: Array(eintraege),
                einnahmeLogs: Array(einnahmeLogs)
            )
        }
    }

    // MARK: - Helpers

    private func abschnittTitel(_ titel: String) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2).fill(Color.indigo).frame(width: 3, height: 18)
            Text(titel).font(.title3.bold())
            Spacer()
        }
        .padding(.top, 4)
    }

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
        let sym: String = t.map { $0 > 0.2 ? "arrow.up" : $0 < -0.2 ? "arrow.down" : "minus" } ?? "minus"
        let farbe: Color = t.map { $0 > 0.2 ? Color.red : $0 < -0.2 ? Color.green : Color.secondary } ?? .secondary
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
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    // MARK: - Medikamente

    private var medikamentenKarte: some View {
        let aktive = medikamente.filter(\.aktiv)
        let notif = NotificationManager.shared
        let heuteLogs = einnahmeLogs.filter { $0.datum >= tagesstart && $0.eingenommen }

        return NavigationLink(destination: MedikamenteView()) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Medikamente heute", systemImage: "pill.fill")
                        .font(.headline).foregroundStyle(.blue)
                    InfoButton(
                        titel: "Medikamente heute",
                        text: "Deine aktiven Dauermedikamente und deren heutiger Einnahmestatus. Hake Einnahmen im Medikamenten-Tab ab."
                    )
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }
                ForEach(aktive.prefix(3)) { med in
                    let erwartet = notif.anzahlDosen(med.frequenz)
                    let eingenommen = heuteLogs.filter { $0.medikamentName == med.name && $0.dosierung == med.dosierung }.count
                    let fertig = erwartet > 0 ? eingenommen >= erwartet : eingenommen > 0
                    HStack(spacing: 10) {
                        Image(systemName: fertig ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(fertig ? .green : .secondary).font(.body)
                        Text(med.name).font(.subheadline).foregroundStyle(fertig ? .secondary : .primary)
                        if !med.dosierung.isEmpty { Text(med.dosierung).font(.caption).foregroundStyle(.secondary) }
                        Spacer()
                        if erwartet > 1 {
                            Text("\(eingenommen)/\(erwartet)").font(.caption).foregroundStyle(fertig ? .green : .secondary)
                        } else if erwartet == 0 && eingenommen > 0 {
                            Text("\(eingenommen)×").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                if aktive.count > 3 { Text("+ \(aktive.count - 3) weitere").font(.caption).foregroundStyle(.secondary) }
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Zyklus

    private var zyklusKarte: some View {
        let analyse = ZyklusRechner.analyse(eintraege: Array(zyklusEintraege))
        let kal = Calendar.current; let heute = kal.startOfDay(for: Date())
        let tageZylus: String = { if let t = analyse.aktuellerZyklustag { return "Tag \(t)" }; return "–" }()
        let tageZuPeriode: String = {
            guard let np = analyse.naechstePeriodeStart else { return "–" }
            let diff = kal.dateComponents([.day], from: heute, to: np).day ?? 0
            return diff <= 0 ? "Heute" : "in \(diff) Tagen"
        }()
        let fruchtbarFenster: String = {
            let sorted = analyse.fruchtbareTageSet.filter { $0 >= heute }.sorted()
            guard let first = sorted.first else { return "–" }
            var last = first
            for tag in sorted.dropFirst() {
                if (kal.dateComponents([.day], from: last, to: tag).day ?? 99) <= 1 { last = tag } else { break }
            }
            let fmt = DateFormatter(); fmt.dateFormat = "d. MMM"
            return kal.isDate(first, inSameDayAs: last) ? fmt.string(from: first) : "\(fmt.string(from: first)) – \(fmt.string(from: last))"
        }()

        return NavigationLink(destination: ZyklusView()) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Zyklus-Tracker", systemImage: "drop.circle.fill")
                        .font(.headline).foregroundStyle(.pink)
                    InfoButton(
                        titel: "Zyklus-Tracker",
                        text: "Aktueller Zyklustag, voraussichtliche nächste Periode und fruchtbares Fenster basierend auf deinen Einträgen."
                    )
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }
                HStack(spacing: 0) {
                    ZyklusStatSpalte(titel: "Zyklustag",           wert: tageZylus,       farbe: .pink)
                    Divider().frame(height: 36)
                    ZyklusStatSpalte(titel: "Nächste Periode",     wert: tageZuPeriode,   farbe: .red)
                    Divider().frame(height: 36)
                    ZyklusStatSpalte(titel: "Fruchtbares Fenster", wert: fruchtbarFenster, farbe: .teal)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hautveränderungen

    @ViewBuilder
    private var hautVeraenderungKarte: some View {
        let hautEintraege = eintraege.filter { $0.istHautEintrag }
        if !hautEintraege.isEmpty {
            let wStart = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            let dieseWoche = hautEintraege.filter { $0.datum >= wStart }
            let alleArten = hautEintraege.flatMap { $0.hautArt.components(separatedBy: ", ").filter { !$0.isEmpty } }
            let topArt = Dictionary(grouping: alleArten, by: { $0 }).max(by: { $0.value.count < $1.value.count })?.key
            let alleStellen = hautEintraege.flatMap { $0.hautStellen.components(separatedBy: ", ").filter { !$0.isEmpty } }
            let topStellen = Dictionary(grouping: alleStellen, by: { $0 })
                .sorted { $0.value.count > $1.value.count }.prefix(3).map(\.key)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Hautveränderungen", systemImage: "allergens")
                        .font(.headline).foregroundStyle(.orange)
                    InfoButton(
                        titel: "Hautveränderungen",
                        text: "Zusammenfassung deiner Hautveränderungs-Einträge. Häufig betroffene Stellen und Arten helfen Muster und Zusammenhänge zu erkennen."
                    )
                    Spacer()
                }
                Divider()
                HStack(spacing: 0) {
                    miniStat("Diese Woche", wert: "\(dieseWoche.count)",    farbe: .orange)
                    Divider().frame(height: 36)
                    miniStat("Gesamt",      wert: "\(hautEintraege.count)", farbe: .orange)
                    Divider().frame(height: 36)
                    miniStat("Häufigste Art", wert: topArt ?? "–",          farbe: .orange)
                }
                if !topStellen.isEmpty {
                    Divider()
                    Text("Häufig betroffene Stellen").font(.caption).foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(topStellen, id: \.self) { stelle in
                                Text(stelle).font(.caption)
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(Color.orange.opacity(0.12), in: Capsule())
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
        }
    }

    // MARK: - Schmerzverlauf

    private var schmerzVerlaufChart: some View {
        SchmerzVerlaufKarte(eintraege: Array(eintraege))
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
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
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
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
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
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
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
                    if hatZyklusDaten { Toggle("Zyklus", isOn: $optionen.mitZyklus) }
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

private struct ZyklusStatSpalte: View {
    let titel: String; let wert: String; let farbe: Color
    var body: some View {
        VStack(spacing: 4) {
            Text(wert).font(.subheadline.bold()).foregroundStyle(farbe).lineLimit(1).minimumScaleFactor(0.7)
            Text(titel).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
