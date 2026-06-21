import SwiftUI
import Charts

struct DiabetesKachel: View {
    let messungen: [BlutzuckerEintrag]
    @State private var zeigeForm = false
    @State private var ausgewaehltTag: Date? = nil
    @State private var versteckTask: Task<Void, Never>? = nil

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
        let cal = Calendar.current
        return (0..<14).reversed().map { offset in
            let tag = cal.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            let start = cal.startOfDay(for: tag)
            let end = cal.date(byAdding: .day, value: 1, to: start) ?? start
            let tagesMessungen = messungen.filter { $0.datum >= start && $0.datum < end }
            let avg = tagesMessungen.isEmpty ? 0.0
                : tagesMessungen.map(\.wert).reduce(0.0, +) / Double(tagesMessungen.count)
            return (datum: start, wert: avg)
        }
    }

    private var hatDaten: Bool { chartDaten.contains { $0.wert > 0 } }

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

            Chart(chartDaten, id: \.datum) { punkt in
                BarMark(
                    x: .value("Tag", punkt.datum, unit: .day),
                    y: .value("mmol/L", hatDaten ? punkt.wert : 1.0)
                )
                .foregroundStyle(
                    hatDaten && punkt.wert > 0
                        ? wertFarbe(punkt.wert).opacity(0.75)
                        : Color.blue.opacity(hatDaten ? 0.12 : 0.07)
                )
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
                    Text("Noch keine Einträge").font(.caption2).foregroundStyle(.secondary)
                }
            }

            if let tag = ausgewaehltTag,
               let punkt = chartDaten.first(where: { Calendar.current.isDate($0.datum, inSameDayAs: tag) }) {
                HStack(spacing: 6) {
                    Text(tag, format: .dateTime.weekday(.abbreviated).day().month())
                        .font(.caption2.bold()).foregroundStyle(.secondary)
                    if punkt.wert > 0 {
                        Text(String(format: "Ø %.1f mmol/L", punkt.wert))
                            .font(.caption2)
                            .foregroundStyle(wertFarbe(punkt.wert))
                    } else {
                        Text("Keine Messung").font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .transition(.opacity)
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
        .animation(.easeInOut(duration: 0.2), value: ausgewaehltTag)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
        .sheet(isPresented: $zeigeForm) { BlutzuckerForm() }
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
