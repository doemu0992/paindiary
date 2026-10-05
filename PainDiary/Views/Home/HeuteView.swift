import SwiftUI
import SwiftData
import Charts

/// „Heute" – ruhiger Einstieg: Hero-Gauge, eine Hauptaktion, drei Chips, Modul-Grid.
struct HeuteView: View {
    @Query(sort: \PainEntry.datum, order: .reverse) private var eintraege: [PainEntry]
    @Query private var profile: [Benutzerprofil]
    @Query(sort: \WellnessEintrag.datum, order: .reverse) private var wellnessEintraege: [WellnessEintrag]
    @Query(sort: \MigraeneEintrag.datum, order: .reverse) private var migraeneAnfaelle: [MigraeneEintrag]
    @Query(sort: \BlutzuckerEintrag.datum, order: .reverse) private var blutzucker: [BlutzuckerEintrag]
    @AppStorage("migraeneModulAktiv") private var migraeneAktiv = false
    @AppStorage("rheumaModulAktiv")   private var rheumaAktiv   = false
    @AppStorage("diabetesModulAktiv") private var diabetesAktiv = false
    @AppStorage("hautModulAktiv")     private var hautAktiv     = false
    @AppStorage("zyklusModulAktiv")   private var zyklusAktiv   = false
    @AppStorage("wellnessModulAktiv") private var wellnessAktiv = false
    @Environment(\.scenePhase) private var scenePhase

    @State private var viewModel = DashboardViewModel()
    @State private var zeigeSchnellerfassung = false
    @State private var zeigeAnalyse = false

    private let kal = Calendar.current

    // MARK: - Daten

    private var schmerzEintraege: [PainEntry] {
        eintraege.filter { !$0.istHautEintrag && $0.eintragsArt != .rheuma }
    }
    private var heuteEintraege: [PainEntry] {
        schmerzEintraege.filter { kal.isDateInToday($0.datum) }
    }
    private var heuteSchnitt: Double? {
        guard !heuteEintraege.isEmpty else { return nil }
        return Double(heuteEintraege.map(\.schmerzstaerke).reduce(0, +)) / Double(heuteEintraege.count)
    }
    private var heuteWellness: WellnessEintrag? {
        wellnessEintraege.first { kal.isDateInToday($0.datum) }
    }

    /// Tagesdurchschnitt der letzten 7 Tage (nur Tage mit Einträgen)
    private var wocheDaten: [(datum: Date, wert: Double)] {
        let heute = kal.startOfDay(for: Date())
        return (0..<7).reversed().compactMap { offset -> (datum: Date, wert: Double)? in
            guard let tag = kal.date(byAdding: .day, value: -offset, to: heute) else { return nil }
            let items = schmerzEintraege.filter { kal.isDate($0.datum, inSameDayAs: tag) }
            guard !items.isEmpty else { return nil }
            return (tag, Double(items.map(\.schmerzstaerke).reduce(0, +)) / Double(items.count))
        }
    }

    private var trendText: String? {
        guard let vor = viewModel.vorwochenschmerz, viewModel.wochenschmerz > 0 else { return nil }
        let diff = viewModel.wochenschmerz - vor
        if abs(diff) < 0.05 { return "= wie letzte Woche" }
        return "\(diff < 0 ? "↓" : "↑") \(String(format: "%.1f", abs(diff))) zur Vorwoche"
    }

    private var gruss: String {
        let stunde = kal.component(.hour, from: Date())
        let basis = stunde < 12 ? "Guten Morgen" : stunde < 18 ? "Guten Tag" : "Guten Abend"
        let vorname = profile.first?.vorname.trimmingCharacters(in: .whitespaces) ?? ""
        return vorname.isEmpty ? basis : "\(basis), \(vorname)"
    }

    private var datumText: String {
        let df = DateFormatter()
        df.dateFormat = "EEEE, d. MMMM"
        df.locale = Locale(identifier: "de_CH")
        return df.string(from: Date())
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text(datumText)
                    .font(.footnote).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)

                heroKarte
                hauptAktion
                heuteChips
                modulGrid
                einblickZeile
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .auroraScreen(schmerzLevel: heuteSchnitt.map { Int($0.rounded()) })
        .navigationTitle(gruss)
        .navigationBarTitleDisplayMode(.large)
        .glassBars()
        .onAppear { viewModel.eintraege = eintraege }
        .onChange(of: eintraege) { _, neu in viewModel.eintraege = neu }
        .sheet(isPresented: $zeigeSchnellerfassung) { QuickCaptureSheet() }
        .sheet(isPresented: $zeigeAnalyse) { GesamtAnalyseView() }
    }

    // MARK: - Hero

    private var heroKarte: some View {
        VStack(spacing: 14) {
            GlassSectionLabel("Heute")

            SchmerzGauge(
                wert: heuteSchnitt ?? 0,
                groesse: 190, zahlGroesse: 84,
                nachkomma: false,
                platzhalter: heuteSchnitt == nil
            )

            VStack(spacing: 4) {
                Text(heuteSchnitt.map { SchmerzSkala.wort(Int($0.rounded())) } ?? "Noch kein Eintrag heute")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(heuteSchnitt == nil ? Color.secondary : SchmerzBadge.farbe(fuer: Int((heuteSchnitt ?? 0).rounded())))
                if let trend = trendText {
                    Text(trend).font(.subheadline).foregroundStyle(.secondary)
                }
            }

            wochenWelle
        }
        .frame(maxWidth: .infinity)
        .glassCard(radius: 28, padding: 20)
    }

    private var wochenWelle: some View {
        Chart(wocheDaten, id: \.datum) { p in
            AreaMark(x: .value("Tag", p.datum, unit: .day), y: .value("Schmerz", p.wert))
                .interpolationMethod(.catmullRom)
                .foregroundStyle(LinearGradient(colors: [Color.accentColor.opacity(0.28), .clear], startPoint: .top, endPoint: .bottom))
            LineMark(x: .value("Tag", p.datum, unit: .day), y: .value("Schmerz", p.wert))
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                .foregroundStyle(Color.accentColor)
        }
        .chartYScale(domain: 0...10)
        .chartXAxis(.hidden).chartYAxis(.hidden)
        .frame(height: 56)
        .overlay {
            if wocheDaten.count < 2 {
                Text("Letzte 7 Tage").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel("Schmerzverlauf der letzten 7 Tage")
    }

    // MARK: - Hauptaktion

    private var hauptAktion: some View {
        Button { zeigeSchnellerfassung = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill").font(.title2)
                Text("Wie geht es dir gerade?")
            }
        }
        .buttonStyle(.glassPrimary(tint: .accentColor, hoehe: 72))
        .accessibilityHint("Öffnet die Schnellerfassung")
    }

    // MARK: - Chips

    private var heuteChips: some View {
        let schlaf = heuteEintraege.first(where: { $0.schlafStunden > 0 })?.schlafStunden ?? heuteWellness?.schlafStunden ?? 0
        let wasser = Double(heuteWellness?.wasserMl ?? 0) / 1000
        let energie = heuteWellness.flatMap { $0.energielevel > 0 ? $0.energielevel : nil }
            ?? heuteEintraege.first(where: { $0.energielevel > 0 })?.energielevel ?? 0
        let energieWorte = ["–", "Erschöpft", "Müde", "Okay", "Gut", "Top"]

        return VStack(alignment: .leading, spacing: 10) {
            GlassSectionLabel("Heute erfasst")
            HStack(spacing: 10) {
                infoChip(symbol: "moon.zzz.fill", farbe: .indigo, wert: schlaf > 0 ? String(format: "%.1f h", schlaf) : "–", label: "Schlaf")
                infoChip(symbol: "drop.fill", farbe: .teal, wert: wasser > 0 ? String(format: "%.1f l", wasser) : "–", label: "Wasser")
                infoChip(symbol: "bolt.fill", farbe: .mint, wert: energieWorte[min(max(energie, 0), 5)], label: "Energie")
            }
        }
    }

    private func infoChip(symbol: String, farbe: Color, wert: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).font(.title3).foregroundStyle(farbe)
            Text(wert).font(.subheadline.bold()).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 72)
        .glassCard(radius: 20, padding: 12)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Module

    private struct ModulInfo: Identifiable {
        let id: String
        let titel: String
        let symbol: String
        let tint: Color
        let wert: String
        let untertitel: String
        let verlauf: [Double]
    }

    /// Tageswerte der letzten 7 Tage (0 = kein Eintrag) für die Mini-Sparkline
    private func tageswerte(_ punkte: [(Date, Double)]) -> [Double] {
        let heute = kal.startOfDay(for: Date())
        return (0..<7).reversed().map { offset in
            guard let tag = kal.date(byAdding: .day, value: -offset, to: heute) else { return 0 }
            let werte = punkte.filter { kal.isDate($0.0, inSameDayAs: tag) }.map(\.1)
            return werte.isEmpty ? 0 : werte.reduce(0, +) / Double(werte.count)
        }
    }

    private var module: [ModulInfo] {
        let grenze30 = kal.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        var liste: [ModulInfo] = []

        let s7 = schmerzEintraege.filter { $0.datum >= (kal.date(byAdding: .day, value: -7, to: Date()) ?? Date()) }
        liste.append(ModulInfo(
            id: "schmerz", titel: "Schmerz", symbol: "waveform.path.ecg", tint: .red,
            wert: "\(s7.count)", untertitel: s7.count == 1 ? "Eintrag (7 T.)" : "Einträge (7 T.)",
            verlauf: tageswerte(schmerzEintraege.map { ($0.datum, Double($0.schmerzstaerke)) })
        ))
        if migraeneAktiv {
            let n = migraeneAnfaelle.filter { $0.datum >= grenze30 }.count
            liste.append(ModulInfo(
                id: "migraene", titel: "Migräne", symbol: "bolt.horizontal.fill", tint: .purple,
                wert: "\(n)", untertitel: n == 1 ? "Anfall (30 T.)" : "Anfälle (30 T.)",
                verlauf: tageswerte(migraeneAnfaelle.map { ($0.datum, Double($0.staerke)) })
            ))
        }
        if rheumaAktiv {
            let rheuma = eintraege.filter { $0.eintragsArt == .rheuma }
            let schuebe = rheuma.filter { $0.istSchub && $0.datum >= grenze30 }.count
            liste.append(ModulInfo(
                id: "rheuma", titel: "Rheuma", symbol: "figure.arms.open", tint: .teal,
                wert: "\(schuebe)", untertitel: schuebe == 1 ? "Schub (30 T.)" : "Schübe (30 T.)",
                verlauf: tageswerte(rheuma.map { ($0.datum, Double($0.schmerzstaerke)) })
            ))
        }
        if hautAktiv {
            let haut = eintraege.filter { $0.istHautEintrag }
            let n = haut.filter { $0.datum >= grenze30 }.count
            liste.append(ModulInfo(
                id: "haut", titel: "Haut", symbol: "bandage.fill", tint: .orange,
                wert: "\(n)", untertitel: "Einträge (30 T.)",
                verlauf: tageswerte(haut.map { ($0.datum, 1.0) })
            ))
        }
        if diabetesAktiv {
            liste.append(ModulInfo(
                id: "diabetes", titel: "Diabetes", symbol: "drop.fill", tint: .blue,
                wert: blutzucker.first.map { String(format: "%.1f", $0.wert) } ?? "–",
                untertitel: "Letzte (mmol/L)",
                verlauf: tageswerte(blutzucker.map { ($0.datum, $0.wert) })
            ))
        }
        if zyklusAktiv {
            liste.append(ModulInfo(
                id: "zyklus", titel: "Zyklus", symbol: "circle.dotted", tint: .pink,
                wert: "›", untertitel: "Öffnen", verlauf: []
            ))
        }
        if wellnessAktiv {
            liste.append(ModulInfo(
                id: "wellness", titel: "Wellness", symbol: "heart.text.square.fill", tint: .mint,
                wert: "›", untertitel: "Öffnen", verlauf: []
            ))
        }
        return liste
    }

    private var modulGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            GlassSectionLabel("Deine Module")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(module) { info in
                    NavigationLink { modulZiel(info.id) } label: { modulKachel(info) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func modulZiel(_ id: String) -> some View {
        switch id {
        case "migraene": MigraeneView()
        case "rheuma":   RheumaView()
        case "haut":     HautView()
        case "diabetes": DiabetesView()
        case "zyklus":   ZyklusView()
        case "wellness": WellnessView()
        default:         SchmerzView()
        }
    }

    private func modulKachel(_ info: ModulInfo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: info.symbol)
                    .font(.headline).foregroundStyle(info.tint)
                    .frame(width: 36, height: 36)
                    .background(info.tint.opacity(0.14), in: Circle())
                    .shadow(color: info.tint.opacity(0.35), radius: 6)
                Spacer()
                Image(systemName: "chevron.right").font(.caption2.bold()).foregroundStyle(.tertiary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(info.titel).font(.subheadline.weight(.semibold))
                Text(info.wert).font(.system(.title2, design: .rounded).bold()).foregroundStyle(info.tint)
                Text(info.untertitel).font(.caption2).foregroundStyle(.secondary)
            }
            miniBalken(info.verlauf, tint: info.tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 22, padding: 16)
        .accessibilityElement(children: .combine)
    }

    private func miniBalken(_ werte: [Double], tint: Color) -> some View {
        let maxWert = max(werte.max() ?? 1, 1)
        return HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(werte.enumerated()), id: \.offset) { _, w in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(tint.opacity(w > 0 ? 0.7 : 0.12))
                    .frame(height: max(4, 22 * CGFloat(w / maxWert)))
            }
        }
        .frame(height: 24, alignment: .bottom)
    }

    // MARK: - Einblick

    private var einblickZeile: some View {
        Button { zeigeAnalyse = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles").font(.title3).foregroundStyle(.indigo)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Einblicke").font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    Text("Muster und Zusammenhänge entdecken").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
            }
            .frame(minHeight: 44)
            .glassCard(radius: 22, padding: 16)
        }
        .buttonStyle(.plain)
    }
}
