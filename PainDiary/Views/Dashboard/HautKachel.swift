import SwiftUI
import Charts

struct HautKachel: View {
    let eintraege: [PainEntry]
    @State private var zeigeForm = false

    private var dieseWoche: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return eintraege.filter { $0.datum >= cutoff }.count
    }

    private var haeufigsteArt: String {
        let alle = eintraege.flatMap { $0.hautArt.components(separatedBy: ", ").filter { !$0.isEmpty } }
        return Dictionary(grouping: alle, by: { $0 })
            .max(by: { $0.value.count < $1.value.count })?.key ?? "–"
    }

    private var chartDaten: [(datum: Date, anzahl: Int)] {
        let cal = Calendar.current
        return (0..<14).reversed().map { offset in
            let tag = cal.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            let start = cal.startOfDay(for: tag)
            let end = cal.date(byAdding: .day, value: 1, to: start) ?? start
            let count = eintraege.filter { $0.datum >= start && $0.datum < end }.count
            return (datum: start, anzahl: count)
        }
    }

    private var hatDaten: Bool {
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        return eintraege.contains { $0.datum >= cutoff }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Hautveränderungen", systemImage: "bandage.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Spacer()
                Button { zeigeForm = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 0) {
                statBox(wert: "\(dieseWoche)", label: "Diese Woche", farbe: dieseWoche == 0 ? .secondary : .orange)
                Divider().frame(height: 32)
                statBox(wert: "\(eintraege.count)", label: "Gesamt", farbe: .secondary)
                Divider().frame(height: 32)
                statBox(wert: haeufigsteArt, label: "Häufigste Art", farbe: .orange)
            }

            Chart(chartDaten, id: \.datum) { punkt in
                BarMark(
                    x: .value("Tag", punkt.datum, unit: .day),
                    y: .value("Einträge", hatDaten ? Double(punkt.anzahl) : 1.0)
                )
                .foregroundStyle(hatDaten
                    ? Color.orange.opacity(punkt.anzahl > 0 ? 0.75 : 0.1)
                    : Color.orange.opacity(0.07))
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

            NavigationLink(destination: HautView()) {
                HStack {
                    Text("Haut-Modul öffnen")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2.bold())
                        .foregroundStyle(Color.orange.opacity(0.6))
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .sheet(isPresented: $zeigeForm) { HautForm() }
    }

    private func statBox(wert: String, label: String, farbe: Color) -> some View {
        VStack(spacing: 3) {
            Text(wert)
                .font(.subheadline.bold())
                .foregroundStyle(farbe)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}
