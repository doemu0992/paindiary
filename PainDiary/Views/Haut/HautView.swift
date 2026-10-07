import SwiftUI
import SwiftData

/// Haut-Dashboard im Bento-Aufbau (wie Schmerz/Zyklus): Körperkarte als Hero, Kachel-Raster, Eintrags-Chips.
struct HautView: View {
    @Query(
        filter: #Predicate<PainEntry> { $0.istHautEintrag == true },
        sort: \PainEntry.datum, order: .reverse
    ) private var eintraege: [PainEntry]
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var scanService = BodyScanService.shared

    @State private var vm = HautDashboardViewModel()
    @State private var ansicht: ModulAnsicht = .heute
    @State private var zeigeForm = false
    @State private var zeigeAnalyse = false

    private let tint = Color.orange
    private let spalten = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    private var u: HautUebersicht { vm.uebersicht }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                GlassSegmentPicker(auswahl: $ansicht, optionen: ModulAnsicht.allCases, titel: { $0.rawValue })

                switch ansicht {
                case .heute:
                    heroKarte
                    bentoRaster
                    zuletztBereich
                case .verlauf:
                    EintragTageskarten(eintraege: eintraege, tint: tint, leerText: "Noch keine Hauteinträge", inhalt: chipInhalt)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .auroraScreen(.haut)
        .navigationTitle("Hautveränderungen")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { zeigeForm = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Hautveränderung erfassen")
            }
        }
        .sheet(isPresented: $zeigeForm) { HautForm() }
        .sheet(isPresented: $zeigeAnalyse) { HautAnalyseView() }
        .onAppear { vm.aktualisiere(eintraege: eintraege) }
        .onChange(of: eintraege) { _, neu in vm.aktualisiere(eintraege: neu) }
        .onChange(of: scenePhase) { _, phase in if phase == .active { vm.aktualisiere(eintraege: eintraege) } }
    }

    // MARK: - Hero: betroffene Stellen

    private var heroKarte: some View {
        VStack(spacing: 12) {
            GlassSectionLabel("Betroffene Stellen · 30 Tage")

            KoerperHeatmapView(
                intensitaeten: u.stellenIntensitaeten,
                tintColor: .systemOrange,
                proportionen: scanService.proportionen
            )
            .frame(height: 280)

            Text(u.haeufigsteStelle.map { "Meist: \($0)" } ?? "Noch keine Stellen erfasst")
                .font(.title3.bold())
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                ForEach(u.topStellen, id: \.name) { GlassPille(text: "\($0.name) · \($0.anzahl)×", tint: tint) }
            }

            Button { zeigeForm = true } label: {
                Label("Hautveränderung erfassen", systemImage: "plus")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .glassTintButton(tint, radius: 22)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .glassCard(radius: 28, padding: 20)
        .onTapGesture { zeigeAnalyse = true }
    }

    // MARK: - Bento-Raster

    private var bentoRaster: some View {
        LazyVGrid(columns: spalten, spacing: 12) {
            BentoKachel(symbol: "bandage.fill", label: "Einträge · 30 Tage", tint: tint, leuchtet: u.anzahl30 > 0,
                        wert: "\(u.anzahl30)")
            BentoKachel(symbol: "clock", label: "Letzter Eintrag", tint: tint,
                        wert: letzterText, klein: true)
            BentoKachel(symbol: "square.stack.3d.up.fill", label: "Häufigste Art", tint: tint,
                        wert: u.haeufigsteArt ?? "–", klein: true)
            BentoKachel(symbol: "mappin.and.ellipse", label: "Häufigste Stelle", tint: tint,
                        wert: u.haeufigsteStelle ?? "–", klein: true)
        }
    }

    private var letzterText: String {
        guard let tage = u.letzterVorTagen else { return "–" }
        switch tage {
        case 0:  return "Heute"
        case 1:  return "Gestern"
        default: return "vor \(tage) Tagen"
        }
    }

    // MARK: - Zuletzt

    private var zuletztBereich: some View {
        VStack(spacing: 8) {
            ZuletztKopf { withAnimation { ansicht = .verlauf } }

            if eintraege.isEmpty {
                Text("Tippe auf „Hautveränderung erfassen“, um deinen ersten Eintrag anzulegen.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .glassCard(radius: 22, padding: 16)
            } else {
                EintragChipStreifen(eintraege: eintraege, tint: tint, inhalt: chipInhalt)

                Button { zeigeAnalyse = true } label: {
                    Label("Haut-Analyse öffnen", systemImage: "chart.bar.xaxis.ascending")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .glassTintButton(tint, radius: 20)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func chipInhalt(_ eintrag: PainEntry) -> EintragChipInhalt {
        let stellen = ListenFeld.parse(eintrag.hautStellen)
        let arten = ListenFeld.parse(eintrag.hautArt)
        return EintragChipInhalt(
            symbol: "bandage.fill",
            titel: stellen.isEmpty ? "Haut" : stellen.joined(separator: ", "),
            untertitel: TagBeschriftung.tagUndZeit(eintrag) + (arten.first.map { " · \($0)" } ?? "")
        )
    }
}
