import SwiftUI
import Charts

struct MigraeneKachel: View {
    let anfaelle: [MigraeneEintrag]
    @State private var zeigeForm = false

    private var anfaelle30: [MigraeneEintrag] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return anfaelle.filter { $0.datum >= cutoff }
    }

    private var letzterAnfallText: String {
        guard let letzter = anfaelle.first else { return "Noch keiner" }
        let tage = Calendar.current.dateComponents([.day], from: letzter.datum, to: Date()).day ?? 0
        switch tage {
        case 0:  return "Heute"
        case 1:  return "Gestern"
        default: return "Vor \(tage) Tagen"
        }
    }

    private var chartDaten: [(datum: Date, anzahl: Int)] {
        let cal = Calendar.current
        return (0..<14).reversed().map { offset in
            let tag = cal.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            let start = cal.startOfDay(for: tag)
            let end = cal.date(byAdding: .day, value: 1, to: start) ?? start
            let n = anfaelle.filter { $0.datum >= start && $0.datum < end }.count
            return (datum: start, anzahl: n)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Migräne", systemImage: "bolt.horizontal.fill")
                    .font(.headline)
                    .foregroundStyle(.purple)
                Spacer()
                Button {
                    zeigeForm = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.purple)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 0) {
                statBox(
                    wert: "\(anfaelle30.count)",
                    label: "Anfälle (30 T.)",
                    farbe: anfaelle30.count == 0 ? .green : anfaelle30.count <= 4 ? .orange : .red
                )
                Divider().frame(height: 32)
                statBox(wert: letzterAnfallText, label: "Letzter Anfall", farbe: .secondary)
                if !anfaelle30.isEmpty {
                    let avg = Double(anfaelle30.map(\.staerke).reduce(0, +)) / Double(anfaelle30.count)
                    Divider().frame(height: 32)
                    statBox(wert: String(format: "%.1f/10", avg), label: "Ø Stärke", farbe: .orange)
                }
            }

            if anfaelle.count > 0 {
                Chart(chartDaten, id: \.datum) { punkt in
                    BarMark(
                        x: .value("Tag", punkt.datum, unit: .day),
                        y: .value("Anfälle", punkt.anzahl)
                    )
                    .foregroundStyle(Color.purple.opacity(punkt.anzahl > 0 ? 0.75 : 0.1))
                    .cornerRadius(3)
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 44)
            }

            Divider()

            NavigationLink(destination: MigraeneView()) {
                HStack {
                    Text("Alle Anfälle anzeigen")
                        .font(.caption.bold())
                        .foregroundStyle(.purple)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2.bold())
                        .foregroundStyle(.purple.opacity(0.6))
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .sheet(isPresented: $zeigeForm) { MigraeneAnfallForm() }
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
