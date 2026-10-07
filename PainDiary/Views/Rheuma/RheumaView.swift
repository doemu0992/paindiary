import SwiftUI
import SwiftData

/// Rheuma-Dashboard im Bento-Aufbau: Schmerz-Ring (Ø 30 Tage), Kacheln zu Scores/Therapie, Eintrags-Chips.
struct RheumaView: View {
    @Query(sort: \PainEntry.datum, order: .reverse) private var eintraege: [PainEntry]
    @Query(sort: \HAQEintrag.datum, order: .reverse) private var haqEintraege: [HAQEintrag]
    @Query(sort: \FACITEintrag.datum, order: .reverse) private var facitEintraege: [FACITEintrag]
    @Query(sort: \BiologikaInjektion.datum, order: .reverse) private var injektionen: [BiologikaInjektion]
    @Query(sort: \Remissionsphase.beginn, order: .reverse) private var remissionsphasen: [Remissionsphase]
    @Environment(\.scenePhase) private var scenePhase

    @State private var vm = RheumaDashboardViewModel()
    @State private var ansicht: ModulAnsicht = .heute
    @State private var zeigeForm = false
    @State private var zeigeAnalyse = false

    private let tint = Color.teal
    private let spalten = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var rheumaEintraege: [PainEntry] { eintraege.filter { $0.eintragsArt == .rheuma } }
    private var u: RheumaUebersicht { vm.uebersicht }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                GlassSegmentPicker(auswahl: $ansicht, optionen: ModulAnsicht.allCases, titel: { $0.rawValue })

                switch ansicht {
                case .heute:
                    heroKarte
                    bentoRaster
                    GlassLinkZeile(symbol: "pills.fill", titel: "Kortison-Tagebuch", tint: tint) { KortisonView() }
                    GlassLinkZeile(symbol: "doc.text.fill", titel: "Arztbrief erstellen", tint: tint) { ArztbriefView() }
                    zuletztBereich
                case .verlauf:
                    EintragTageskarten(eintraege: rheumaEintraege, tint: tint, leerText: "Noch keine Rheuma-Einträge", inhalt: chipInhalt)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .auroraScreen(.rheuma)
        .navigationTitle("Rheuma & Gelenke")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { zeigeForm = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Rheuma-Eintrag erfassen")
            }
        }
        .sheet(isPresented: $zeigeForm) { RheumaSchnellForm() }
        .sheet(isPresented: $zeigeAnalyse) { RheumaAnalyseView() }
        .onAppear { vm.aktualisiere(eintraege: eintraege) }
        .onChange(of: eintraege) { _, neu in vm.aktualisiere(eintraege: neu) }
        .onChange(of: scenePhase) { _, phase in if phase == .active { vm.aktualisiere(eintraege: eintraege) } }
    }

    // MARK: - Hero

    private var heroKarte: some View {
        VStack(spacing: 12) {
            GlassSectionLabel("Ø Schmerz · 30 Tage")

            SchmerzGauge(
                wert: u.schnitt30 ?? 0,
                groesse: 196,
                zahlGroesse: 64,
                nachkomma: true,
                platzhalter: u.schnitt30 == nil
            )

            if let schnitt = u.schnitt30 {
                Text(SchmerzSkala.wort(Int(schnitt.rounded())))
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.4), lineWidth: 1))
            }

            Text(u.anzahl30 == 0 ? "Noch keine Einträge in 30 Tagen" : "\(u.anzahl30) Einträge in 30 Tagen")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button { zeigeForm = true } label: {
                Label("Rheuma-Eintrag erfassen", systemImage: "plus")
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

    // MARK: - Bento-Raster

    private var bentoRaster: some View {
        LazyVGrid(columns: spalten, spacing: 12) {
            BentoKachel(symbol: "bolt.fill", label: "Schübe · 30 Tage", tint: tint, leuchtet: u.schuebe30 > 0,
                        wert: "\(u.schuebe30)")

            BentoKachel(symbol: "sunrise.fill", label: "Ø Morgensteifigkeit", tint: tint,
                        leuchtet: (u.steifigkeitSchnitt30 ?? 0) > 30,
                        wert: u.steifigkeitSchnitt30.map { String(format: "%.0f", $0) } ?? "–",
                        einheit: u.steifigkeitSchnitt30 == nil ? nil : "Min")

            NavigationLink(destination: HAQView()) {
                BentoKachel(symbol: "chart.line.uptrend.xyaxis", label: "HAQ & DAS28", tint: tint,
                            wert: haqEintraege.first.map { String(format: "%.2f", $0.haqScore) } ?? "–")
            }
            .buttonStyle(.plain)

            NavigationLink(destination: FACITView()) {
                BentoKachel(symbol: "battery.25percent",
                            label: facitEintraege.first.map { "FACIT · \($0.erschoepfungsgradText)" } ?? "FACIT-Erschöpfung",
                            tint: tint,
                            wert: facitEintraege.first.map { "\($0.facitScore)" } ?? "–")
            }
            .buttonStyle(.plain)

            NavigationLink(destination: RemissionsView()) {
                BentoKachel(symbol: "checkmark.seal.fill", label: "Remissionsphasen", tint: tint,
                            wert: remissionsphasen.first(where: { $0.istAktiv })?.dauerText ?? "–", klein: true)
            }
            .buttonStyle(.plain)

            NavigationLink(destination: BiologikaView()) {
                BentoKachel(symbol: "syringe.fill", label: biologikaLabel, tint: tint,
                            wert: naechsteDosis.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "–", klein: true)
            }
            .buttonStyle(.plain)
        }
    }

    private var naechsteDosis: Date? {
        injektionen.compactMap(\.naechsteDosis).filter { $0 > Date() }.min()
    }

    private var biologikaLabel: String {
        naechsteDosis != nil ? "Biologika · nächste Dosis" : (injektionen.first.map { "Biologika · \($0.praeparat)" } ?? "Biologika / Injektionen")
    }

    // MARK: - Zuletzt

    private var zuletztBereich: some View {
        VStack(spacing: 8) {
            ZuletztKopf { withAnimation { ansicht = .verlauf } }

            if rheumaEintraege.isEmpty {
                Text("Tippe auf „Rheuma-Eintrag erfassen“, um deinen ersten Eintrag anzulegen.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .glassCard(radius: 22, padding: 16)
            } else {
                EintragChipStreifen(eintraege: rheumaEintraege, tint: tint, inhalt: chipInhalt)

                Button { zeigeAnalyse = true } label: {
                    Label("Rheuma-Analyse öffnen", systemImage: "chart.bar.xaxis.ascending")
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
        var zusatz = ""
        if eintrag.istSchub { zusatz += " · Schub" }
        if eintrag.morgensteifigkeit > 0 { zusatz += " · \(eintrag.morgensteifigkeit)′" }
        return EintragChipInhalt(
            zahl: eintrag.schmerzstaerke,
            titel: "Rheuma",
            untertitel: TagBeschriftung.tagUndZeit(eintrag) + zusatz,
            hervorgehoben: eintrag.istSchub
        )
    }
}
