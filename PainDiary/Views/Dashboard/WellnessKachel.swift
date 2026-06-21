import SwiftUI
import SwiftData
import Charts

struct WellnessKachel: View {
    let eintraege: [PainEntry]               // for stimmung/schlaf trend from pain data
    let wellnessEintraege: [WellnessEintrag] // for wasser/historical data
    @State private var zeigeView = false

    // MARK: - Stats

    private var heuteWasser: Int {
        let heute = Calendar.current.startOfDay(for: Date())
        return wellnessEintraege.first(where: { Calendar.current.isDate($0.datum, inSameDayAs: heute) })?.wasserMl ?? 0
    }

    private var avgStimmung7T: Double {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let gefiltert = eintraege.filter { $0.datum >= cutoff && $0.stimmung > 0 }
        guard !gefiltert.isEmpty else { return 0 }
        return Double(gefiltert.map(\.stimmung).reduce(0, +)) / Double(gefiltert.count)
    }

    private var avgSchlaf7T: Double {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let gefiltert = eintraege.filter { $0.datum >= cutoff && $0.schlafStunden > 0 }
        guard !gefiltert.isEmpty else { return 0 }
        return gefiltert.map(\.schlafStunden).reduce(0, +) / Double(gefiltert.count)
    }

    // MARK: - Chart Data (14-day mood, one point per day)

    private var chartDaten: [(datum: Date, stimmung: Double)] {
        let cal = Calendar.current
        return (0..<14).reversed().map { offset in
            let tag = cal.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            let start = cal.startOfDay(for: tag)
            let end = cal.date(byAdding: .day, value: 1, to: start) ?? start
            let tagesEintraege = eintraege.filter { $0.datum >= start && $0.datum < end && $0.stimmung > 0 }
            let avg = tagesEintraege.isEmpty ? 0.0
                : Double(tagesEintraege.map(\.stimmung).reduce(0, +)) / Double(tagesEintraege.count)
            return (datum: start, stimmung: avg)
        }
    }

    private var hatDaten: Bool { chartDaten.contains { $0.stimmung > 0 } }

    private func stimmungFarbe(_ s: Double) -> Color {
        switch s {
        case 0:     return Color.mint.opacity(0.07)
        case ..<2:  return .red.opacity(0.7)
        case ..<3:  return .orange.opacity(0.7)
        case ..<4:  return .yellow.opacity(0.8)
        case ..<5:  return .mint.opacity(0.75)
        default:    return .green.opacity(0.75)
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // 1. Header: Titel + Plus-Button
            HStack {
                Label("Wohlbefinden", systemImage: "heart.text.square.fill")
                    .font(.headline).foregroundStyle(.mint)
                Spacer()
                Button { zeigeView = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3).foregroundStyle(.mint)
                }
                .buttonStyle(.plain)
            }

            // 2. Drei Stat-Boxes
            HStack(spacing: 0) {
                statBox(
                    wert: avgStimmung7T > 0 ? String(format: "%.1f", avgStimmung7T) : "–",
                    label: "Ø Stimmung (7 T.)",
                    farbe: avgStimmung7T > 0 ? .mint : .secondary
                )
                Divider().frame(height: 32)
                statBox(
                    wert: avgSchlaf7T > 0 ? String(format: "%.1fh", avgSchlaf7T) : "–",
                    label: "Ø Schlaf (7 T.)",
                    farbe: avgSchlaf7T >= 7 ? .green : avgSchlaf7T > 0 ? .orange : .secondary
                )
                Divider().frame(height: 32)
                statBox(
                    wert: heuteWasser > 0 ? "\(heuteWasser) ml" : "–",
                    label: "Wasser heute",
                    farbe: heuteWasser > 0 ? .teal : .secondary
                )
            }

            // 3. Mini-Chart 14 Tage (immer anzeigen)
            Chart(chartDaten, id: \.datum) { punkt in
                BarMark(
                    x: .value("Tag", punkt.datum, unit: .day),
                    y: .value("Stimmung", hatDaten ? (punkt.stimmung > 0 ? punkt.stimmung : 0) : 1.0)
                )
                .foregroundStyle(hatDaten ? stimmungFarbe(punkt.stimmung) : Color.mint.opacity(0.07))
                .cornerRadius(3)
            }
            .chartXAxis(.hidden).chartYAxis(.hidden)
            .chartYScale(domain: 0...5)
            .frame(height: 44)
            .overlay(alignment: .center) {
                if !hatDaten {
                    Text("Noch keine Einträge").font(.caption2).foregroundStyle(.secondary)
                }
            }

            Divider()

            // 4. NavigationLink zum Modul
            NavigationLink(destination: WellnessView()) {
                HStack {
                    Text("Wohlbefinden öffnen").font(.caption.bold()).foregroundStyle(.mint)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2.bold()).foregroundStyle(Color.mint.opacity(0.6))
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
        .sheet(isPresented: $zeigeView) {
            NavigationStack { WellnessView() }
        }
    }

    // MARK: - Helpers

    private func statBox(wert: String, label: String, farbe: Color) -> some View {
        VStack(spacing: 3) {
            Text(wert).font(.subheadline.bold()).foregroundStyle(farbe).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 4)
    }
}
