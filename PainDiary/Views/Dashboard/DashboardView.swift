import SwiftUI
import SwiftData
import Charts

/// „Einblicke" (Segment im Verlauf-Tab) als Bento-Dashboard: Hero „Letzte 7 Tage", Kennzahl-Kacheln,
/// Modul-Carousel, Analyse. Rechenlogik liegt in `VerlaufDashboardViewModel` / Domain.
struct DashboardView: View {
    var segment: Binding<VerlaufSegment>? = nil
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

    @AppStorage("migraeneModulAktiv") private var migraeneAktiv = false
    @AppStorage("rheumaModulAktiv")   private var rheumaAktiv = false
    @AppStorage("hautModulAktiv")     private var hautAktiv = false
    @AppStorage("diabetesModulAktiv") private var diabetesAktiv = false
    @AppStorage("zyklusModulAktiv")   private var zyklusAktiv = false
    @AppStorage("wellnessModulAktiv") private var wellnessAktiv = false

    @Environment(\.scenePhase) private var scenePhase
    @State private var vm = VerlaufDashboardViewModel()
    @State private var konfig: EinblickeKonfiguration = EinblickeKonfigurationSpeicher.laden()
    @State private var kachelKonfig: [KachelKonfiguration] = .laden()
    @State private var anpassenAnzeigen = false
    @State private var analyseAuswahl: AnalyseAuswahl = .wetter
    @State private var zeigeGesamtAnalyse = false

    @State private var exportURL: URL? = nil
    @State private var pdfVorschauAnzeigen = false
    @State private var exportOptionsAnzeigen = false
    @State private var exportOptionen = ExportOptionen()
    @State private var istAmExportieren = false

    private let spalten = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private enum AnalyseAuswahl: String, CaseIterable {
        case wetter = "Wetter", stress = "Stress", schlaf = "Schlaf"
    }

    private var schmerzEintraege: [PainEntry] { eintraege.filter { $0.eintragsArt == .schmerz } }
    private var u: VerlaufUebersicht { vm.verlauf }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let segment {
                    VerlaufSegmentPicker(auswahl: segment)
                    ArztZusammenfassungKarte()
                }

                ForEach(EinblickeGruppe.allCases, id: \.self) { gruppe in
                    gruppeView(gruppe)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .auroraScreen(.statistik)
        .glassBars()
        .navigationTitle(segment == nil ? "Übersicht" : "Verlauf")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { aktualisiere() }
        .onChange(of: eintraege) { _, _ in aktualisiere() }
        .onChange(of: einnahmeLogs) { _, _ in aktualisiere() }
        .onChange(of: medikamente) { _, _ in aktualisiere() }
        .onChange(of: migraeneAnfaelle) { _, _ in aktualisiere() }
        .onChange(of: blutzuckerMessungen) { _, _ in aktualisiere() }
        .onChange(of: zyklusEintraege) { _, _ in aktualisiere() }
        .onChange(of: wellnessEintraege) { _, _ in aktualisiere() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { aktualisiere() } }
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
            EinblickeAnpassenView(konfig: $konfig, kachelKonfig: $kachelKonfig)
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

    private func aktualisiere() {
        vm.aktualisiere(
            eintraege: eintraege, migraene: migraeneAnfaelle, blutzucker: blutzuckerMessungen,
            zyklus: zyklusEintraege, wellness: wellnessEintraege, medikamente: medikamente, logs: einnahmeLogs
        )
    }

    // MARK: - Gruppen

    @ViewBuilder
    private func gruppeView(_ gruppe: EinblickeGruppe) -> some View {
        let bloecke = konfig.sichtbar(in: gruppe)
        switch gruppe {
        case .wochenuebersicht:
            if bloecke.contains(.hero) { heroKarte }
        case .kennzahlen:
            let kacheln = bloecke.filter(kennzahlVorhanden)
            if !kacheln.isEmpty {
                LazyVGrid(columns: spalten, spacing: 12) {
                    ForEach(kacheln, id: \.self) { kennzahlKachel($0) }
                }
            }
        case .module:
            let module = bloecke.filter(modulAktiv)
            if !module.isEmpty { modulCarousel(module) }
        case .analyse:
            analyseBereich(bloecke)
        }
    }

    private func kennzahlVorhanden(_ block: EinblickeBlock) -> Bool {
        switch block {
        case .medikamente, .adherenz: return vm.aktiveMedikamente > 0
        default: return true
        }
    }

    private func modulAktiv(_ block: EinblickeBlock) -> Bool {
        switch block {
        case .modulSchmerz:   return true
        case .modulMigraene:  return migraeneAktiv
        case .modulRheuma:    return rheumaAktiv
        case .modulHaut:      return hautAktiv
        case .modulDiabetes:  return diabetesAktiv
        case .modulZyklus:    return zyklusAktiv
        case .modulWellness:  return wellnessAktiv
        default:              return false
        }
    }

    // MARK: - Hero

    private var heroKarte: some View {
        HStack(spacing: 16) {
            SchmerzGauge(wert: u.schnitt7 ?? 0, groesse: 112, zahlGroesse: 38, nachkomma: true, platzhalter: u.schnitt7 == nil)

            VStack(alignment: .leading, spacing: 8) {
                GlassSectionLabel("Letzte 7 Tage")
                if let trend = u.trendText { GlassPille(text: trend, tint: .red) }
                Text(heroUntertitel).font(.caption).foregroundStyle(.secondary)
                sparkline
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .glassCard(radius: 28, padding: 18)
    }

    private var heroUntertitel: String {
        u.anzahl7 == 0 ? "Noch keine Einträge" : "\(u.anzahl7) \(u.anzahl7 == 1 ? "Eintrag" : "Einträge") · \(u.tage7) \(u.tage7 == 1 ? "Tag" : "Tage")"
    }

    private var sparkline: some View {
        let werte = Array(u.verlauf7.enumerated())
        return Chart(werte, id: \.offset) { index, wert in
            AreaMark(x: .value("Tag", index), y: .value("Ø", wert))
                .foregroundStyle(LinearGradient(colors: [Color.red.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom))
                .interpolationMethod(.catmullRom)
            LineMark(x: .value("Tag", index), y: .value("Ø", wert))
                .foregroundStyle(Color.red)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .interpolationMethod(.catmullRom)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...10)
        .frame(height: 40)
        .accessibilityLabel("Schmerzverlauf der letzten 7 Tage")
    }

    // MARK: - Kennzahlen

    @ViewBuilder
    private func kennzahlKachel(_ block: EinblickeBlock) -> some View {
        switch block {
        case .schuebe:
            BentoKachel(
                symbol: "bolt.fill", label: schubLabel, tint: .red, leuchtet: u.schuebe7 > 0,
                wert: "\(u.schuebe7)", einheit: "in 7 T"
            )
        case .ausloeser:
            BentoKachel(
                symbol: "exclamationmark.triangle.fill",
                label: u.haeufigsterAusloeser == nil ? "Häufigster Auslöser" : "Häufigster Auslöser · \(u.haeufigsterAusloeserAnzahl)×",
                tint: .orange, wert: u.haeufigsterAusloeser ?? "–", klein: true
            )
        case .stimmungStress:
            BentoKachel(
                symbol: "heart.text.square.fill",
                label: u.stressSchnitt7.map { "Stimmung · Stress \(VerlaufUebersicht.stressWort($0))" } ?? "Stimmung · Stress",
                tint: .pink, wert: u.stimmungSchnitt7.map { VerlaufUebersicht.stimmungWort($0) } ?? "–", klein: true
            )
        case .schlaf:
            BentoKachel(
                symbol: "moon.zzz.fill", label: "Schlaf · Ø 7 T", tint: .indigo,
                wert: u.schlafSchnitt7.map { String(format: "%.1f", $0) } ?? "–", einheit: u.schlafSchnitt7 == nil ? nil : "h"
            )
        case .medikamente:
            BentoKachel(
                symbol: "pills.fill", label: "Medikamente heute", tint: .blue,
                wert: vm.medikation.heuteErwartet > 0 ? "\(vm.medikation.heuteEingenommen)/\(vm.medikation.heuteErwartet)" : "–"
            )
        case .adherenz:
            BentoKachel(
                symbol: "checkmark.seal.fill", label: "Adherenz · 7 T", tint: .green,
                wert: vm.medikation.adherenz7T > 0 ? String(format: "%.0f%%", vm.medikation.adherenz7T) : "–"
            )
        default:
            EmptyView()
        }
    }

    private var schubLabel: String {
        guard let tage = u.letzterSchubVorTagen else { return "Schübe" }
        switch tage {
        case 0:  return "Schübe · letzter heute"
        case 1:  return "Schübe · letzter gestern"
        default: return "Schübe · letzter vor \(tage) Tagen"
        }
    }

    // MARK: - Module

    private func modulCarousel(_ module: [EinblickeBlock]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            GlassSectionLabel("Module").padding(.horizontal, 4)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(module, id: \.self) { block in
                        NavigationLink(destination: modulZiel(block)) {
                            let mini = vm.minis[block]
                            ModulMiniKachel(
                                symbol: modulSymbol(block), titel: block.titel,
                                wert: mini?.wert ?? "–", einheit: mini?.einheit,
                                verlauf: mini?.verlauf ?? [], tint: modulFarbe(block)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder
    private func modulZiel(_ block: EinblickeBlock) -> some View {
        switch block {
        case .modulSchmerz:   SchmerzView()
        case .modulMigraene:  MigraeneView()
        case .modulRheuma:    RheumaView()
        case .modulHaut:      HautView()
        case .modulDiabetes:  DiabetesView()
        case .modulZyklus:    ZyklusView()
        default:              WellnessView()
        }
    }

    private func modulSymbol(_ block: EinblickeBlock) -> String {
        switch block {
        case .modulSchmerz:   return "waveform.path.ecg"
        case .modulMigraene:  return "brain.head.profile"
        case .modulRheuma:    return "figure.arms.open"
        case .modulHaut:      return "bandage.fill"
        case .modulDiabetes:  return "drop.fill"
        case .modulZyklus:    return "circle.dotted"
        default:              return "leaf.fill"
        }
    }

    private func modulFarbe(_ block: EinblickeBlock) -> Color {
        switch block {
        case .modulSchmerz:   return .red
        case .modulMigraene:  return .purple
        case .modulRheuma:    return .teal
        case .modulHaut:      return .orange
        case .modulDiabetes:  return .blue
        case .modulZyklus:    return .pink
        default:              return .mint
        }
    }

    // MARK: - Analyse

    @ViewBuilder
    private func analyseBereich(_ bloecke: [EinblickeBlock]) -> some View {
        let korrelationen = kachelKonfig.filter { $0.typ == .konfigKorrelation && $0.sichtbar }
        if !bloecke.isEmpty || !korrelationen.isEmpty {
            GlassSectionLabel("Analyse").padding(.horizontal, 4)
        }
        ForEach(bloecke, id: \.self) { block in
            switch block {
            case .analyse: analyseKarte
            case .midas:   MidasKachel(bewertungen: Array(midasBewertungen))
            default:       EmptyView()
            }
        }
        ForEach(korrelationen) { kachel in
            KonfigKorrelationsKachel(kachel: kachel, eintraege: Array(eintraege), einnahmeLogs: Array(einnahmeLogs))
        }
    }

    private var analyseKarte: some View {
        VStack(spacing: 12) {
            GlassSegmentPicker(auswahl: $analyseAuswahl, optionen: AnalyseAuswahl.allCases, titel: { $0.rawValue })
            switch analyseAuswahl {
            case .wetter: WetterSchmerzKachel(eintraege: schmerzEintraege)
            case .stress: StressSchmerzKachel(eintraege: schmerzEintraege)
            case .schlaf: SchlafSchmerzKachel(eintraege: schmerzEintraege)
            }
            HStack(spacing: 8) {
                NavigationLink(destination: KorrelationsView()) {
                    Label("Details", systemImage: "chart.xyaxis.line")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .glassTintButton(.teal, radius: 20)
                }
                .buttonStyle(.plain)
                Button { zeigeGesamtAnalyse = true } label: {
                    Label("Gesamt", systemImage: "square.stack.3d.up")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .glassTintButton(.indigo, radius: 20)
                }
                .buttonStyle(.plain)
            }
        }
        .glassCard(radius: 24, padding: 14)
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
                .listRowBackground(GlassRowBackground())
                Section("Abschnitte") {
                    Toggle("Zusammenfassung",      isOn: $optionen.mitZusammenfassung)
                    Toggle("Medikamente",          isOn: $optionen.mitMedikamente)
                    Toggle("Medikamenten-Dossier", isOn: $optionen.mitMedikamentDossier)
                    if hatRheumaDaten { Toggle("Rheuma & Gelenke", isOn: $optionen.mitRheuma) }
                    if hatZyklusDaten { Toggle("Zyklus", isOn: $optionen.mitZyklus) }
                    if hatMigraeneDaten { Toggle("Migräne", isOn: $optionen.mitMigraene) }
                    Toggle("Alle Einträge",        isOn: $optionen.mitEintraege)
                }
                .listRowBackground(GlassRowBackground())
            }
            .glassList(.statistik)
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

