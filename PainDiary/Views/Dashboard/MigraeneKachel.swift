import SwiftUI
import Charts

struct MigraeneKachel: View {
    let anfaelle: [MigraeneEintrag]
    @State private var zeigeForm = false
    @State private var ausgewaehltTag: Date? = nil
    @State private var versteckTask: Task<Void, Never>? = nil

    private var anfaelle30: [MigraeneEintrag] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return anfaelle.filter { $0.datum >= cutoff }
    }

    private var letzterAnfallText: String {
        guard let letzter = anfaelle.first else { return "–" }
        let tage = Calendar.current.dateComponents([.day], from: letzter.datum, to: Date()).day ?? 0
        switch tage {
        case 0:  return "Heute"
        case 1:  return "Gestern"
        default: return "Vor \(tage) T."
        }
    }

    private var chartDaten: [(datum: Date, wert: Double)] {
        let cal = Calendar.current
        return (0..<14).reversed().map { offset in
            let tag = cal.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            let start = cal.startOfDay(for: tag)
            let end = cal.date(byAdding: .day, value: 1, to: start) ?? start
            let tagesAnfaelle = anfaelle.filter { $0.datum >= start && $0.datum < end }
            let avg = tagesAnfaelle.isEmpty ? 0.0
                : Double(tagesAnfaelle.map(\.staerke).reduce(0, +)) / Double(tagesAnfaelle.count)
            return (datum: start, wert: avg)
        }
    }

    private var hatDaten: Bool { !anfaelle30.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Migräne", systemImage: "bolt.horizontal.fill")
                    .font(.headline)
                    .foregroundStyle(.purple)
                Spacer()
                Button { zeigeForm = true } label: {
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
                Divider().frame(height: 32)
                if hatDaten {
                    let avg = Double(anfaelle30.map(\.staerke).reduce(0, +)) / Double(anfaelle30.count)
                    statBox(wert: String(format: "%.1f/10", avg), label: "Ø Stärke", farbe: .orange)
                } else {
                    statBox(wert: "–", label: "Ø Stärke", farbe: .secondary)
                }
            }

            Chart(chartDaten, id: \.datum) { punkt in
                BarMark(
                    x: .value("Tag", punkt.datum, unit: .day),
                    y: .value("Stärke", hatDaten ? punkt.wert : 1.0)
                )
                .foregroundStyle(hatDaten ? (punkt.wert > 0 ? Color.purple.opacity(0.75) : Color.purple.opacity(0.12)) : Color.purple.opacity(0.07))
                .cornerRadius(3)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: 0...10)
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

            if let tag = ausgewaehltTag, let punkt = chartDaten.first(where: { Calendar.current.isDate($0.datum, inSameDayAs: tag) }) {
                HStack(spacing: 6) {
                    Text(tag, format: .dateTime.weekday(.abbreviated).day().month())
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    if punkt.wert > 0 {
                        Text("Ø \(String(format: "%.1f", punkt.wert))")
                            .font(.caption2)
                            .foregroundStyle(staerkeFarbe(punkt.wert))
                    }
                    Spacer()
                }
                .transition(.opacity)
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
                        .foregroundStyle(Color.purple.opacity(0.6))
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: ausgewaehltTag)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .sheet(isPresented: $zeigeForm) { MigraeneAnfallForm() }
    }

    private func staerkeFarbe(_ wert: Double) -> Color {
        guard wert > 0 else { return Color.purple.opacity(0.1) }
        if wert <= 3 { return .green.opacity(0.75) }
        if wert <= 6 { return .orange.opacity(0.75) }
        return .red.opacity(0.85)
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

    private func balkenTippen(proxy: ChartProxy, location: CGPoint) {
        guard let date: Date = proxy.value(atX: location.x, as: Date.self) else { return }
        let snapped = chartDaten.min(by: {
            abs($0.datum.timeIntervalSince(date)) < abs($1.datum.timeIntervalSince(date))
        })?.datum
        guard let snapped else { return }
        withAnimation { ausgewaehltTag = snapped }
        versteckTask?.cancel()
        versteckTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            await MainActor.run { withAnimation { ausgewaehltTag = nil } }
        }
    }
}
