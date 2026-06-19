import SwiftUI
import SwiftData
import Charts

struct ZyklusKachel: View {
    let eintraege: [ZyklusEintrag]
    @State private var zeigeForm = false

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

    private var chartDaten: [(datum: Date, istPeriode: Bool, hatEintrag: Bool)] {
        let cal = Calendar.current
        return (0..<14).reversed().map { offset in
            let tag = cal.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            let start = cal.startOfDay(for: tag)
            let end = cal.date(byAdding: .day, value: 1, to: start) ?? start
            let eintrag = eintraege.first { $0.datum >= start && $0.datum < end }
            return (datum: start, istPeriode: eintrag?.istPeriode == true, hatEintrag: eintrag != nil)
        }
    }

    private var hatDaten: Bool { !eintraege.isEmpty }

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

            Chart(chartDaten, id: \.datum) { punkt in
                BarMark(
                    x: .value("Tag", punkt.datum, unit: .day),
                    y: .value("Eintrag", hatDaten ? 1.0 : 1.0)
                )
                .foregroundStyle(
                    hatDaten
                        ? (punkt.istPeriode
                            ? Color.red.opacity(0.75)
                            : punkt.hatEintrag
                                ? Color.pink.opacity(0.4)
                                : Color.pink.opacity(0.1))
                        : Color.pink.opacity(0.07)
                )
                .cornerRadius(3)
            }
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
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .sheet(isPresented: $zeigeForm) {
            ZyklusEintragSheet(datum: Calendar.current.startOfDay(for: Date()), bestehend: nil)
        }
    }

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
}
