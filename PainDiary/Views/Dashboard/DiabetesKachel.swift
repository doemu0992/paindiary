import SwiftUI
import Charts

struct DiabetesKachel: View {
    let messungen: [BlutzuckerEintrag]
    @State private var zeigeForm = false

    private var messungen30: [BlutzuckerEintrag] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return messungen.filter { $0.datum >= cutoff }
    }

    private var pctZielbereich: Int {
        guard !messungen30.isEmpty else { return 0 }
        let imZiel = messungen30.filter(\.zielbereich).count
        return Int(Double(imZiel) / Double(messungen30.count) * 100)
    }

    private var chartDaten: [(datum: Date, wert: Double)] {
        messungen.prefix(14).reversed().map { (datum: $0.datum, wert: $0.wert) }
    }

    private var hatDaten: Bool { !messungen30.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Diabetes", systemImage: "drop.fill")
                    .font(.headline)
                    .foregroundStyle(.blue)
                Spacer()
                Button { zeigeForm = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 0) {
                statBox(
                    wert: messungen.first.map { String(format: "%.1f", $0.wert) } ?? "–",
                    label: "Letzte (mmol/L)",
                    farbe: messungen.first.map { wertFarbe($0.wert) } ?? .secondary
                )
                Divider().frame(height: 32)
                statBox(
                    wert: hatDaten ? "\(pctZielbereich)%" : "–",
                    label: "Im Zielbereich",
                    farbe: hatDaten ? (pctZielbereich >= 70 ? .green : .orange) : .secondary
                )
                Divider().frame(height: 32)
                statBox(
                    wert: "\(messungen30.count)",
                    label: "Messungen (30 T.)",
                    farbe: .secondary
                )
            }

            if chartDaten.count > 1 {
                Chart(chartDaten, id: \.datum) { punkt in
                    LineMark(
                        x: .value("Datum", punkt.datum),
                        y: .value("mmol/L", punkt.wert)
                    )
                    .foregroundStyle(Color.blue.opacity(0.8))
                    .interpolationMethod(.catmullRom)
                    PointMark(
                        x: .value("Datum", punkt.datum),
                        y: .value("mmol/L", punkt.wert)
                    )
                    .foregroundStyle(wertFarbe(punkt.wert))
                    .symbolSize(24)
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 44)
            } else {
                placeholderChart
            }

            Divider()

            NavigationLink(destination: DiabetesView()) {
                HStack {
                    Text("Alle Messungen anzeigen")
                        .font(.caption.bold())
                        .foregroundStyle(.blue)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2.bold())
                        .foregroundStyle(Color.blue.opacity(0.6))
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .sheet(isPresented: $zeigeForm) { BlutzuckerForm() }
    }

    private var placeholderChart: some View {
        let daten = (0..<14).map { i -> (datum: Date, wert: Double) in
            let tag = Calendar.current.date(byAdding: .day, value: -i, to: Date()) ?? Date()
            return (datum: tag, wert: 1.0)
        }
        return Chart(daten, id: \.datum) { punkt in
            BarMark(
                x: .value("Tag", punkt.datum, unit: .day),
                y: .value("Wert", punkt.wert)
            )
            .foregroundStyle(Color.blue.opacity(0.07))
            .cornerRadius(3)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 44)
        .overlay(alignment: .center) {
            Text("Noch keine Einträge")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func wertFarbe(_ wert: Double) -> Color {
        switch wert {
        case ..<3.9:    return .red
        case 3.9..<7.8: return .green
        default:        return .orange
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
