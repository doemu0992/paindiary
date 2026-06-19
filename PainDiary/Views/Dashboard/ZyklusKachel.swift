import SwiftUI
import SwiftData
import Charts

struct ZyklusKachel: View {
    let eintraege: [ZyklusEintrag]
    @State private var zeigeForm = false
    @State private var ausgewaehltDatum: Date? = nil

    private var analyse: ZyklusAnalyse {
        ZyklusRechner.analyse(eintraege: eintraege)
    }

    private var zyklusTagText: String {
        guard let t = analyse.aktuellerZyklustag else { return "–" }
        return "Tag \(t)"
    }

    private var naechstePeriodeText: String {
        guard let np = analyse.naechstePeriodeStart else { return "–" }
        let diff = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: np).day ?? 0
        return diff <= 0 ? "Heute" : "in \(diff)d"
    }

    private var zykluslaengeText: String {
        guard !analyse.zyklusStarts.isEmpty else { return "–" }
        return String(format: "%.0f T.", analyse.adaptierteZykluslaenge)
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

        // Predict future period days from next period start + duration
        var vorhergesagteTage: Set<Date> = []
        if let np = a.naechstePeriodeStart {
            let dauer = max(Int(round(a.adaptiertePeriodendauer)), 1)
            for i in 0..<dauer {
                if let t = cal.date(byAdding: .day, value: i, to: np) {
                    vorhergesagteTage.insert(cal.startOfDay(for: t))
                }
            }
        }

        // -7 to +6 = 14 days (past week + today + next 6 days)
        return (-7..<7).map { offset in
            let tag = cal.date(byAdding: .day, value: offset, to: heute) ?? heute
            let start = cal.startOfDay(for: tag)
            let end = cal.date(byAdding: .day, value: 1, to: start) ?? start
            let eintrag = eintraege.first { $0.datum >= start && $0.datum < end }

            return ChartPunkt(
                datum: start,
                blutungsfluss: eintrag?.blutungsfluss ?? "",
                istPeriode: eintrag?.istPeriode == true,
                istOvulation: a.ovulationsTageSet.contains(start),
                istFruchtbar: a.fruchtbareTageSet.contains(start),
                istVorhergesagt: vorhergesagteTage.contains(start) && eintrag?.istPeriode != true,
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

    private var ausgewaehltPunkt: ChartPunkt? {
        guard let sel = ausgewaehltDatum else { return nil }
        return chartDaten.min(by: { abs($0.datum.timeIntervalSince(sel)) < abs($1.datum.timeIntervalSince(sel)) })
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
            .chartXSelection(value: $ausgewaehltDatum)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 44)
            .overlay(alignment: .center) {
                if !hatDaten {
                    Text("Noch keine Einträge")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if let punkt = ausgewaehltPunkt {
                Text(punkt.datum, format: .dateTime.weekday(.abbreviated).day().month())
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
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
        .sheet(isPresented: $zeigeForm) {
            ZyklusEintragSheet(datum: Calendar.current.startOfDay(for: Date()), bestehend: nil)
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
