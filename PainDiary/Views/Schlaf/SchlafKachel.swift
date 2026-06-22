import SwiftUI
import Charts

struct SchlafKachel: View {
    let nächte: [SleepNightSummary]
    @State private var ausgewaehltTag: Date? = nil
    @State private var versteckTask: Task<Void, Never>? = nil

    private var letzteNacht: SleepNightSummary? { nächte.first }

    private var avgQualitaet7: String {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let gefiltert = nächte.filter { $0.date >= cutoff }
        guard !gefiltert.isEmpty else { return "–" }
        let avg = gefiltert.map(\.qualitaet).reduce(0, +) / Double(gefiltert.count)
        return String(format: "%.0f", avg)
    }

    private var chartDaten: [(datum: Date, wert: Double)] {
        let cal = Calendar.current
        return (0..<14).reversed().map { offset in
            let tag = cal.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            let start = cal.startOfDay(for: tag)
            let match = nächte.first { cal.isDate($0.date, inSameDayAs: start) }
            return (datum: start, wert: match?.qualitaet ?? 0)
        }
    }

    private var hatDaten: Bool { nächte.contains { $0.date >= Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date() } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Schlaf", systemImage: "moon.stars.fill")
                    .font(.headline)
                    .foregroundStyle(.indigo)
                Spacer()
            }

            HStack(spacing: 0) {
                statBox(
                    wert: letzteNacht.map { String(format: "%.0f", $0.qualitaet) } ?? "–",
                    label: "Letzte Nacht",
                    farbe: letzteNacht.map { qualFarbe($0.qualitaet) } ?? .secondary
                )
                Divider().frame(height: 32)
                statBox(
                    wert: avgQualitaet7,
                    label: "Ø 7 Tage",
                    farbe: avgQualitaet7 == "–" ? .secondary : .indigo
                )
                Divider().frame(height: 32)
                statBox(
                    wert: letzteNacht.map { String(format: "%.1f h", $0.dauerStunden) } ?? "–",
                    label: "Dauer",
                    farbe: .secondary
                )
            }

            Chart(chartDaten, id: \.datum) { punkt in
                BarMark(
                    x: .value("Tag", punkt.datum, unit: .day),
                    y: .value("Qualität", hatDaten ? max(punkt.wert, 0) : 50)
                )
                .foregroundStyle(hatDaten
                    ? (punkt.wert > 0 ? Color.indigo.opacity(0.7) : Color.indigo.opacity(0.1))
                    : Color.indigo.opacity(0.07))
                .cornerRadius(3)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: 0...100)
            .frame(height: 44)
            .chartOverlay { proxy in
                GeometryReader { _ in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .onTapGesture { location in balkenTippen(proxy: proxy, location: location) }
                }
            }
            .overlay(alignment: .center) {
                if !hatDaten {
                    Text("Noch keine Schlafdaten")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if let tag = ausgewaehltTag {
                let match = chartDaten.first { Calendar.current.isDate($0.datum, inSameDayAs: tag) }
                HStack(spacing: 6) {
                    Text(tag, format: .dateTime.weekday(.abbreviated).day().month())
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    if let m = match, m.wert > 0 {
                        Text("Qualität: \(String(format: "%.0f", m.wert))")
                            .font(.caption2)
                            .foregroundStyle(qualFarbe(m.wert))
                    } else {
                        Text("Kein Eintrag").font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .transition(.opacity)
            }

            Divider()

            NavigationLink(destination: SchlafView(nächte: nächte)) {
                HStack {
                    Text("Schlaf-Modul öffnen")
                        .font(.caption.bold())
                        .foregroundStyle(.indigo)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2.bold())
                        .foregroundStyle(Color.indigo.opacity(0.6))
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: ausgewaehltTag)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    private func qualFarbe(_ wert: Double) -> Color {
        if wert >= 70 { return .green }
        if wert >= 45 { return .orange }
        return .red
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
