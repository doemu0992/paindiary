import SwiftUI
import SwiftData

/// Schlaf-Dashboard im Bento-Aufbau: Qualitäts-Ring (30 Tage), Kacheln, Nacht-Chips, Verlauf als Tageskarten.
struct SchlafView: View {
    @State private var nächte: [SleepNightSummary]
    @State private var vm = SchlafDashboardViewModel()
    @State private var ansicht: ModulAnsicht = .heute
    @State private var zeigeAnalyse = false

    private let tint = Color.indigo
    private let spalten = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    private var u: SchlafUebersicht { vm.uebersicht }

    init(nächte: [SleepNightSummary] = SleepNightSummary.laden()) {
        _nächte = State(initialValue: nächte)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                GlassSegmentPicker(auswahl: $ansicht, optionen: ModulAnsicht.allCases, titel: { $0.rawValue })

                if nächte.isEmpty {
                    leerKarte
                } else {
                    switch ansicht {
                    case .heute:
                        heroKarte
                        bentoRaster
                        zuletztBereich
                    case .verlauf:
                        ChipTageskarten(elemente: nächte, tag: { DayKey($0.date) }, datum: { $0.date }) {
                            nachtChip($0, volleBreite: true)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .auroraScreen(.wellness)
        .navigationTitle("Schlaf")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if !nächte.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button { zeigeAnalyse = true } label: {
                        Label("Analyse", systemImage: "chart.bar.xaxis.ascending")
                    }
                }
            }
        }
        .sheet(isPresented: $zeigeAnalyse) { SchlafAnalyseView(nächte: nächte) }
        .onAppear { vm.aktualisiere(naechte: nächte) }
        .onChange(of: nächte.count) { _, _ in vm.aktualisiere(naechte: nächte) }
    }

    // MARK: - Leer

    private var leerKarte: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 40))
                .foregroundStyle(tint.opacity(0.6))
            Text("Noch keine Schlafdaten").font(.headline)
            Text("Starte eine Schlafaufzeichnung in SleepBuddy. Die Daten erscheinen hier automatisch nach der nächsten Nacht.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .glassCard(radius: 28, padding: 24)
    }

    // MARK: - Hero

    private var heroKarte: some View {
        VStack(spacing: 12) {
            GlassSectionLabel("Ø Schlafqualität · 30 Tage")

            GlassRing(
                fortschritt: (u.qualitaetSchnitt30 ?? 0) / 100,
                farbe: qualitaetsFarbe(u.qualitaetSchnitt30 ?? 0),
                mitte: String(format: "%.0f", u.qualitaetSchnitt30 ?? 0),
                unterzeile: "von 100",
                platzhalter: u.qualitaetSchnitt30 == nil,
                beschreibung: u.qualitaetSchnitt30.map { "Durchschnittliche Schlafqualität \(Int($0.rounded())) von 100" } ?? "Keine Schlafdaten"
            )

            Text(letzteNachtText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button { zeigeAnalyse = true } label: {
                Label("Schlaf-Analyse öffnen", systemImage: "chart.bar.xaxis.ascending")
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

    private var letzteNachtText: String {
        guard let n = u.letzteNacht else { return "" }
        return "Letzte Nacht: \(String(format: "%.1f", n.dauerStunden)) h · Qualität \(Int(n.qualitaet.rounded()))"
    }

    private func qualitaetsFarbe(_ q: Double) -> Color {
        q >= 70 ? .green : (q >= 45 ? .orange : .red)
    }

    // MARK: - Bento-Raster

    private var bentoRaster: some View {
        LazyVGrid(columns: spalten, spacing: 12) {
            BentoKachel(
                symbol: "bed.double.fill", label: "Ø Schlafdauer", tint: tint,
                wert: u.dauerSchnitt30.map { String(format: "%.1f", $0) } ?? "–",
                einheit: u.dauerSchnitt30 == nil ? nil : "h"
            )
            BentoKachel(
                symbol: "moon.stars.fill", label: "Nächte · 30 Tage", tint: tint,
                wert: "\(u.anzahl30)"
            )
            BentoKachel(
                symbol: "waveform.path", label: "Ø Tiefschlaf", tint: tint,
                wert: u.tiefSchnitt30.map { String(format: "%.0f", $0 * 100) } ?? "–",
                einheit: u.tiefSchnitt30 == nil ? nil : "%"
            )
            BentoKachel(
                symbol: "brain.head.profile", label: "Ø REM-Schlaf", tint: tint,
                wert: u.remSchnitt30.map { String(format: "%.0f", $0 * 100) } ?? "–",
                einheit: u.remSchnitt30 == nil ? nil : "%"
            )
        }
    }

    // MARK: - Zuletzt

    private var zuletztBereich: some View {
        VStack(spacing: 8) {
            ZuletztKopf(titel: "Letzte Nächte") { withAnimation { ansicht = .verlauf } }
            ChipStreifen(elemente: nächte) { nachtChip($0, volleBreite: false) }
        }
    }

    private func nachtChip(_ nacht: SleepNightSummary, volleBreite: Bool) -> some View {
        var untertitel = "\(String(format: "%.1f", nacht.dauerStunden)) h · Tief \(Int(nacht.tiefPct * 100)) % · REM \(Int(nacht.remPct * 100)) %"
        if nacht.schnarchenAnzahl > 0 { untertitel += " · \(nacht.schnarchenAnzahl)× Schnarchen" }
        return GlassEintragChip(
            kennwert: String(format: "%.0f", nacht.qualitaet),
            titel: TagBeschriftung.kurz(DayKey(nacht.date)),
            untertitel: untertitel,
            tint: qualitaetsFarbe(nacht.qualitaet),
            hervorgehoben: nacht.qualitaet < 45,
            volleBreite: volleBreite
        )
        .contextMenu {
            Button(role: .destructive) {
                SleepNightSummary.loeschen(nacht)
                nächte = SleepNightSummary.laden()
                vm.aktualisiere(naechte: nächte)
            } label: { Label("Löschen", systemImage: "trash") }
        }
    }
}

// MARK: - Nacht-Zeile

struct SchlafNachtZeile: View {
    let nacht: SleepNightSummary

    private var qualFarbe: Color {
        if nacht.qualitaet >= 70 { return .green }
        if nacht.qualitaet >= 45 { return .orange }
        return .red
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(qualFarbe.opacity(0.15))
                    .frame(width: 42, height: 42)
                Text(String(format: "%.0f", nacht.qualitaet))
                    .font(.subheadline.bold())
                    .foregroundStyle(qualFarbe)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(nacht.date, style: .date)
                    .font(.subheadline.bold())
                HStack(spacing: 8) {
                    Text(String(format: "%.1f h", nacht.dauerStunden))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    phaseBadge("Tief \(Int(nacht.tiefPct * 100))%", farbe: .indigo)
                    phaseBadge("REM \(Int(nacht.remPct * 100))%", farbe: .purple)
                }
                if nacht.hatGeraeusche {
                    HStack(spacing: 6) {
                        if nacht.schnarchenAnzahl > 0 {
                            geraeuschBadge("\(nacht.schnarchenAnzahl)× Schnarchen", icon: "waveform", farbe: .orange)
                        }
                        if nacht.sprechenAnzahl > 0 {
                            geraeuschBadge("\(nacht.sprechenAnzahl)× Sprechen", icon: "bubble.left.fill", farbe: .blue)
                        }
                        if nacht.geraeuschAnzahl > 0 {
                            geraeuschBadge("\(nacht.geraeuschAnzahl)× Geräusch", icon: "speaker.wave.2.fill", farbe: .secondary)
                        }
                    }
                }
            }

            Spacer()
        }
    }

    private func phaseBadge(_ text: String, farbe: Color) -> some View {
        Text(text)
            .font(.caption2.bold())
            .foregroundStyle(farbe)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(farbe.opacity(0.12), in: Capsule())
    }

    private func geraeuschBadge(_ text: String, icon: String, farbe: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.caption2)
            .foregroundStyle(farbe)
            .labelStyle(.titleAndIcon)
    }
}
