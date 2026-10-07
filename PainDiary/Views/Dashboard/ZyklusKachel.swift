import SwiftUI
import SwiftData
import Charts

struct ZyklusKachel: View {
    let eintraege: [ZyklusEintrag]
    @State private var zeigeForm = false
    @State private var ausgewaehltDatum: Date? = nil
    @State private var versteckTask: Task<Void, Never>? = nil
    @AppStorage("zyklusPrognosenPausiert") private var pausiert = false

    // Cache-Treffer im Rechner: mehrfacher Zugriff pro Render kostet nur den Fingerabdruck.
    private var analyse: ZyklusAnalyse {
        ZyklusRechner.analyse(eintraege: eintraege)
    }

    private var zyklusTagText: String {
        guard let t = analyse.aktuellerZyklustag else { return "–" }
        return "Tag \(t)"
    }

    private var naechstePeriodeText: String {
        if pausiert { return "–" }
        if case .ueberfaellig = analyse.status { return "Überfällig" }
        guard let np = analyse.naechstePeriodeStart else { return "–" }
        let diff = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: np).day ?? 0
        return diff <= 0 ? "Heute" : "in \(diff)d"
    }

    private var zykluslaengeText: String {
        guard analyse.gueltigeZyklen > 0 else { return "–" }
        // Gleicher Wert wie in der Zyklus-Hauptseite (Median aller gültigen Zyklen)
        return "\(Int(analyse.medianZykluslaenge.rounded())) T."
    }

    // MARK: - Chart

    private struct ChartPunkt: Identifiable {
        let datum: Date
        let blutungsfluss: String
        let istPeriode: Bool
        let istOvulation: Bool
        let istFruchtbar: Bool
        let istVorhergesagt: Bool
        let hatEintrag: Bool
        var id: Date { datum }
    }

    private var chartDaten: [ChartPunkt] {
        let cal = Calendar.current
        let heute = cal.startOfDay(for: Date())
        let a = analyse

        let vorhergesagteTage = analyse.vorhergesagtePeriodeTageSet
        let prognosenAn = !pausiert

        // -7 to +6 = 14 days (past week + today + next 6 days)
        return (-7..<7).map { offset in
            let tag = cal.date(byAdding: .day, value: offset, to: heute) ?? heute
            let start = cal.startOfDay(for: tag)
            let end = cal.date(byAdding: .day, value: 1, to: start) ?? start
            let eintrag = eintraege.first { $0.datum >= start && $0.datum < end }

            return ChartPunkt(
                datum: start,
                blutungsfluss: eintrag?.blutungsfluss ?? "",
                istPeriode: eintrag?.hatBlutung == true,
                istOvulation: prognosenAn && a.ovulationsTageSet.contains(start),
                istFruchtbar: prognosenAn && a.fruchtbareTageSet.contains(start),
                istVorhergesagt: prognosenAn && vorhergesagteTage.contains(start) && eintrag?.hatBlutung != true,
                hatEintrag: eintrag != nil
            )
        }
    }

    private func balkenFarbe(_ p: ChartPunkt) -> Color {
        guard hatDaten else { return Color.pink.opacity(0.07) }
        if p.istPeriode {
            switch p.blutungsfluss {
            case "schmierblutung": return Color.red.opacity(0.25)
            case "leicht":         return Color.red.opacity(0.5)
            case "stark":          return Color.red
            default:               return Color.red.opacity(0.75) // mittel
            }
        }
        if p.istOvulation  { return Color.orange.opacity(0.85) }
        if p.istFruchtbar  { return Color.teal.opacity(0.55) }
        if p.istVorhergesagt { return Color.red.opacity(0.2) }
        if p.hatEintrag    { return Color.pink.opacity(0.4) }
        return Color.pink.opacity(0.1)
    }

    private var hatDaten: Bool { !eintraege.isEmpty }

    private func statusText(_ p: ChartPunkt) -> String {
        if p.istPeriode {
            let fluss = Blutungsfluss(roh: p.blutungsfluss)
            return fluss == .keine ? "Periode" : "Periode · \(fluss.titel)"
        }
        if p.istOvulation { return "Eisprung" }
        if p.istFruchtbar { return "Fruchtbar" }
        if p.istVorhergesagt { return "Periode erwartet" }
        return p.hatEintrag ? "Eintrag vorhanden" : "Kein Eintrag"
    }

    private func statusFarbe(_ p: ChartPunkt) -> Color {
        if p.istPeriode || p.istVorhergesagt { return ZyklusFarbe.periode }
        if p.istOvulation { return .orange }
        if p.istFruchtbar { return ZyklusFarbe.fruchtbar }
        return .secondary
    }

    private var ausgewaehltPunkt: ChartPunkt? {
        guard let sel = ausgewaehltDatum else { return nil }
        return chartDaten.first { $0.datum == sel }
    }

    private func balkenTippen(proxy: ChartProxy, location: CGPoint) {
        guard let date: Date = proxy.value(atX: location.x, as: Date.self) else { return }
        let snapped = chartDaten.min(by: {
            abs($0.datum.timeIntervalSince(date)) < abs($1.datum.timeIntervalSince(date))
        })?.datum
        guard let snapped else { return }
        withAnimation { ausgewaehltDatum = snapped }
        versteckTask?.cancel()
        versteckTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            await MainActor.run { withAnimation { ausgewaehltDatum = nil } }
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Zyklus", systemImage: "drop.fill")
                    .font(.headline)
                    .foregroundStyle(.pink)
                Spacer()
                Button { zeigeForm = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.pink)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 0) {
                statBox(wert: zyklusTagText, label: "Zyklustag", farbe: .pink)
                Divider().frame(height: 32)
                statBox(wert: naechstePeriodeText, label: "Nächste Periode", farbe: .red)
                Divider().frame(height: 32)
                statBox(wert: zykluslaengeText, label: "Ø Zyklus", farbe: .secondary)
            }

            Chart(chartDaten) { punkt in
                BarMark(
                    x: .value("Tag", punkt.datum, unit: .day),
                    y: .value("Eintrag", 1.0)
                )
                .foregroundStyle(balkenFarbe(punkt))
                .cornerRadius(3)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 44)
            .chartOverlay { proxy in
                GeometryReader { _ in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .onTapGesture { location in balkenTippen(proxy: proxy, location: location) }
                }
            }
            .overlay(alignment: .center) {
                if !hatDaten {
                    Text("Noch keine Einträge")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if let punkt = ausgewaehltPunkt {
                HStack(spacing: 6) {
                    Text(punkt.datum, format: .dateTime.weekday(.abbreviated).day().month())
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    Text(statusText(punkt))
                        .font(.caption2)
                        .foregroundStyle(statusFarbe(punkt))
                    Spacer()
                }
                .transition(.opacity)
            }

            // Legende
            if hatDaten {
                HStack(spacing: 10) {
                    legendePunkt(farbe: .red, text: "Periode")
                    legendePunkt(farbe: .orange, text: "Eisprung")
                    legendePunkt(farbe: .teal, text: "Fruchtbar")
                    legendePunkt(farbe: Color.red.opacity(0.3), text: "Vorhersage")
                    Spacer()
                }
            }

            Divider()

            NavigationLink(destination: ZyklusView()) {
                HStack {
                    Text("Zyklus öffnen")
                        .font(.caption.bold())
                        .foregroundStyle(.pink)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2.bold())
                        .foregroundStyle(Color.pink.opacity(0.6))
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: ausgewaehltDatum)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
        .sheet(isPresented: $zeigeForm) {
            // Bestehenden Tageseintrag übergeben — sonst entsteht ein Duplikat für heute.
            ZyklusEintragSheet(
                datum: Calendar.current.startOfDay(for: Date()),
                bestehend: eintraege.first { Calendar.current.isDateInToday($0.datum) }
            )
        }
    }

    // MARK: - Helpers

    private func statBox(wert: String, label: String, farbe: Color) -> some View {
        VStack(spacing: 3) {
            Text(wert)
                .font(.subheadline.bold())
                .foregroundStyle(farbe)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private func legendePunkt(farbe: Color, text: String) -> some View {
        HStack(spacing: 3) {
            Circle().fill(farbe).frame(width: 6, height: 6)
            Text(text).font(.caption2).foregroundStyle(.secondary)
        }
    }
}
