import SwiftUI
import SwiftData
import Charts

private enum SchmerzAnsicht: String, CaseIterable {
    case heute = "Heute"
    case verlauf = "Verlauf"
}

/// Schmerztagebuch als Bento-Dashboard (Aufbau wie das Zyklus-Modul): Hero-Ring, 2-spaltiges Kachel-Raster,
/// Körperkarte und Eintrags-Chips. Rechenlogik liegt in `SchmerzUebersicht` / `SchmerzDashboardViewModel`.
struct SchmerzView: View {
    @Query(sort: \PainEntry.datum, order: .reverse) private var eintraege: [PainEntry]
    @Query private var einnahmenHeute: [EinnahmeLog]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var scanService = BodyScanService.shared

    @State private var vm = SchmerzDashboardViewModel()
    @State private var ansicht: SchmerzAnsicht = .heute
    @State private var zeigeForm = false
    @State private var zeigeAnalyse = false

    private let tint = Color.red
    private let spalten = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    init() {
        let start = Calendar.current.startOfDay(for: Date())
        _einnahmenHeute = Query(filter: #Predicate<EinnahmeLog> { $0.datum >= start && $0.eingenommen })
    }

    private var schmerzEintraege: [PainEntry] { eintraege.filter { $0.eintragsArt == .schmerz } }
    private var u: SchmerzUebersicht { vm.uebersicht }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                GlassSegmentPicker(auswahl: $ansicht, optionen: SchmerzAnsicht.allCases, titel: { $0.rawValue })

                switch ansicht {
                case .heute:
                    heroKarte
                    bentoRaster
                    koerperKarte
                    zuletztBereich
                case .verlauf:
                    verlaufBereich
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .auroraScreen(.schmerz)
        .navigationTitle("Schmerztagebuch")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { zeigeForm = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Schmerz erfassen")
            }
        }
        .sheet(isPresented: $zeigeForm) { AddEntryView() }
        .sheet(isPresented: $zeigeAnalyse) { SchmerzAnalyseView() }
        .onAppear { vm.aktualisiere(eintraege: eintraege) }
        .onChange(of: eintraege) { _, neu in vm.aktualisiere(eintraege: neu) }
        .onChange(of: scenePhase) { _, phase in if phase == .active { vm.aktualisiere(eintraege: eintraege) } }
    }

    // MARK: - Hero

    private var heroKarte: some View {
        VStack(spacing: 12) {
            GlassSectionLabel("Heute")

            SchmerzGauge(
                wert: u.heuteSchnitt ?? 0,
                groesse: 196,
                zahlGroesse: 64,
                nachkomma: true,
                platzhalter: u.heuteSchnitt == nil
            )

            if let schnitt = u.heuteSchnitt {
                Text(SchmerzSkala.wort(Int(schnitt.rounded())))
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.4), lineWidth: 1))
            }

            Text(heroUntertitel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                if let trend = u.trendText { GlassPille(text: trend, tint: tint) }
                if let woche = u.wochenSchnitt { GlassPille(text: "Ø 7 T \(String(format: "%.1f", woche))") }
            }

            Button { zeigeForm = true } label: {
                Label("Schmerz erfassen", systemImage: "plus")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .glassTintButton(tint, radius: 22)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .glassCard(radius: 28, padding: 20)
    }

    private var heroUntertitel: String {
        guard u.heuteAnzahl > 0 else { return "Heute noch nichts erfasst" }
        let anzahl = u.heuteAnzahl == 1 ? "1 Eintrag heute" : "\(u.heuteAnzahl) Einträge heute"
        guard let letzter = u.letzterEintrag else { return anzahl }
        return "\(anzahl) · zuletzt \(letzter.formatted(date: .omitted, time: .shortened))"
    }

    // MARK: - Bento-Raster

    private var bentoRaster: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: spalten, spacing: 12) {
                BentoKachel(symbol: "chart.line.uptrend.xyaxis", label: "7-Tage-Verlauf", tint: tint, leuchtet: true) {
                    sparkline
                }
                .onTapGesture { zeigeAnalyse = true }

                BentoKachel(
                    symbol: "checkmark.circle",
                    label: u.letzterEintrag.map { "Einträge · zuletzt \($0.formatted(date: .omitted, time: .shortened))" } ?? "Einträge",
                    tint: tint, wert: "\(u.heuteAnzahl)", einheit: "heute"
                )

                BentoKachel(
                    symbol: "flame.fill", label: "Stärkster Schmerz · 7 Tage",
                    tint: tint, leuchtet: (u.staerkster7Tage ?? 0) >= 7,
                    wert: u.staerkster7Tage.map(String.init) ?? "–",
                    einheit: u.staerkster7Tage.map(SchmerzSkala.wort)
                )

                BentoKachel(
                    symbol: "bolt.fill", label: letzterSchubLabel,
                    tint: tint, wert: u.letzterSchub.map { "\($0.staerke)" } ?? "–"
                )

                BentoKachel(
                    symbol: "mappin.and.ellipse",
                    label: u.haeufigsterOrt.map { "Häufigster Ort · \($0.anzahl)× in 30 Tagen" } ?? "Häufigster Ort",
                    tint: tint, wert: u.haeufigsterOrt?.name ?? "–", klein: true
                )

                BentoKachel(
                    symbol: "pills.fill", label: "Medikamente genommen",
                    tint: tint, wert: "\(einnahmenHeute.count)", einheit: "heute"
                )
            }

            if let hinweis = u.schubHinweis {
                schubHinweisKarte(hinweis)
            }
        }
    }

    private var letzterSchubLabel: String {
        guard let schub = u.letzterSchub else { return "Letzter Schub" }
        switch schub.vorTagen {
        case 0:  return "Letzter Schub · heute"
        case 1:  return "Letzter Schub · gestern"
        default: return "Letzter Schub · vor \(schub.vorTagen) Tagen"
        }
    }

    private var sparkline: some View {
        let werte = Array(u.verlauf7.enumerated())
        return Chart(werte, id: \.offset) { index, wert in
            AreaMark(x: .value("Tag", index), y: .value("Ø", wert))
                .foregroundStyle(LinearGradient(colors: [tint.opacity(0.45), tint.opacity(0)], startPoint: .top, endPoint: .bottom))
                .interpolationMethod(.catmullRom)
            LineMark(x: .value("Tag", index), y: .value("Ø", wert))
                .foregroundStyle(tint)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .interpolationMethod(.catmullRom)
            if index == werte.count - 1 {
                PointMark(x: .value("Tag", index), y: .value("Ø", wert))
                    .foregroundStyle(Color.white)
                    .symbolSize(50)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...10)
        .frame(height: 48)
        .overlay {
            if werte.isEmpty { Text("Noch keine Einträge").font(.caption2).foregroundStyle(.secondary) }
        }
        .accessibilityLabel("Verlauf der letzten 7 Tage")
    }

    private func schubHinweisKarte(_ hinweis: SchubHinweis) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Schubhinweis").font(.subheadline.bold())
                Text("Ø \(String(format: "%.1f", hinweis.aktuellerMittelwert)) statt üblich \(String(format: "%.1f", hinweis.baselineMittelwert)). Besprich es bei Bedarf mit deiner Ärztin oder deinem Arzt.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .glassCard(radius: 22, tint: .orange, padding: 14)
    }

    // MARK: - Körperkarte

    private var koerperKarte: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 10) {
                GlassSectionLabel("Körperkarte · 30 Tage")
                Text(u.haeufigsterOrt.map { "Meist: \($0.name)" } ?? "Noch keine Körperstellen")
                    .font(.title3.bold())
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(u.topOrte, id: \.name) { ort in
                    HStack(spacing: 8) {
                        Circle().fill(tint).frame(width: 10, height: 10).shadow(color: tint.opacity(0.8), radius: 5)
                        Text("\(ort.name) · \(ort.anzahl)×").font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Text("Tippen für die Analyse").font(.caption).foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            KoerperHeatmapView(
                intensitaeten: u.ortIntensitaeten,
                tintColor: .systemRed,
                proportionen: scanService.proportionen
            )
            .frame(width: 150, height: 220)
        }
        .glassCard(radius: 24, padding: 16)
        .onTapGesture { zeigeAnalyse = true }
    }

    // MARK: - Zuletzt (Chips)

    private var zuletztBereich: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Zuletzt").font(.title3.bold())
                Spacer()
                Button("Alle ansehen") { withAnimation { ansicht = .verlauf } }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)

            if schmerzEintraege.isEmpty {
                Text("Tippe auf „Schmerz erfassen“, um deinen ersten Eintrag anzulegen.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .glassCard(radius: 22, padding: 16)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(schmerzEintraege.prefix(8)) { eintrag in
                            eintragLink(eintrag, volleBreite: false)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
                .padding(.horizontal, -16)

                Button { zeigeAnalyse = true } label: {
                    Label("Schmerz-Analyse öffnen", systemImage: "chart.bar.xaxis.ascending")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .glassTintButton(tint, radius: 20)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Verlauf (Tageskarten)

    private var gruppiert: [(tag: DayKey, items: [PainEntry])] {
        Dictionary(grouping: schmerzEintraege, by: \.tag)
            .sorted { $0.key > $1.key }
            .map { (tag: $0.key, items: $0.value.sorted { $0.datum > $1.datum }) }
    }

    private var verlaufBereich: some View {
        LazyVStack(spacing: 12) {
            if schmerzEintraege.isEmpty {
                Text("Noch keine Einträge")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .glassCard(radius: 22, padding: 20)
            }
            ForEach(gruppiert, id: \.tag) { gruppe in
                VStack(alignment: .leading, spacing: 10) {
                    Text(tagLabel(gruppe.tag)).font(.headline)
                    ForEach(gruppe.items) { eintrag in
                        eintragLink(eintrag, volleBreite: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard(radius: 24, padding: 16)
            }
        }
    }

    // MARK: - Hilfen

    private func eintragLink(_ eintrag: PainEntry, volleBreite: Bool) -> some View {
        NavigationLink(destination: PainEntryDetailView(eintrag: eintrag)) {
            GlassEintragChip(
                zahl: eintrag.schmerzstaerke,
                titel: eintragTitel(eintrag),
                untertitel: eintragUntertitel(eintrag),
                tint: tint,
                hervorgehoben: eintrag.schmerzstaerke >= 7,
                volleBreite: volleBreite
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                EintragLoeschService(context: modelContext).loesche(eintrag)
            } label: { Label("Löschen", systemImage: "trash") }
        }
    }

    private func eintragTitel(_ eintrag: PainEntry) -> String {
        let orte = eintrag.koerperstellenListe
        return orte.isEmpty ? "Schmerz" : orte.joined(separator: ", ")
    }

    private func eintragUntertitel(_ eintrag: PainEntry) -> String {
        let zeit = eintrag.datum.formatted(date: .omitted, time: .shortened)
        let tag = tagKurz(eintrag.tag)
        let art = eintrag.schmerzart.isEmpty ? "" : " · \(eintrag.schmerzart)"
        return "\(tag) \(zeit)\(art)"
    }

    private func tagKurz(_ tag: DayKey) -> String {
        let heute = DayKey.heute()
        if tag == heute { return "Heute" }
        if tag.tage(bis: heute) == 1 { return "Gestern" }
        return tag.beginn().formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    private func tagLabel(_ tag: DayKey) -> String {
        let heute = DayKey.heute()
        if tag == heute { return "Heute" }
        if tag.tage(bis: heute) == 1 { return "Gestern" }
        return tag.beginn().formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}
