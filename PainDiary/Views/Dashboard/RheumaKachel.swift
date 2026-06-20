import SwiftUI
import Charts

struct RheumaKachel: View {
    let eintraege: [PainEntry]
    let haqEintraege: [HAQEintrag]
    @State private var zeigeForm = false
    @State private var ausgewaehltTag: Date? = nil
    @State private var versteckTask: Task<Void, Never>? = nil

    private var rheumaEintraege: [PainEntry] { eintraege.filter { $0.koerperstelle == "Rheuma" } }

    private var schube30: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return rheumaEintraege.filter { $0.istSchub && $0.datum >= cutoff }.count
    }

    private var letzterSchubText: String {
        guard let letzter = rheumaEintraege.first(where: { $0.istSchub }) else { return "–" }
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
            let tagesEintraege = rheumaEintraege.filter { $0.datum >= start && $0.datum < end }
            let avg = tagesEintraege.isEmpty ? 0.0
                : Double(tagesEintraege.map(\.schmerzstaerke).reduce(0, +)) / Double(tagesEintraege.count)
            return (datum: start, wert: avg)
        }
    }

    private var hatDaten: Bool { rheumaEintraege.contains { $0.datum >= Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date() } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Rheuma & Gelenke", systemImage: "figure.arms.open")
                    .font(.headline)
                    .foregroundStyle(.teal)
                Spacer()
                Button { zeigeForm = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.teal)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 0) {
                statBox(
                    wert: "\(schube30)",
                    label: "Schübe (30 T.)",
                    farbe: schube30 == 0 ? .green : schube30 <= 2 ? .orange : .red
                )
                Divider().frame(height: 32)
                statBox(wert: letzterSchubText, label: "Letzter Schub", farbe: .secondary)
                Divider().frame(height: 32)
                if let letzterHAQ = haqEintraege.first {
                    statBox(
                        wert: String(format: "%.2f", letzterHAQ.haqScore),
                        label: "HAQ-Score",
                        farbe: letzterHAQ.haqScore < 0.5 ? .green : letzterHAQ.haqScore < 1.5 ? .orange : .red
                    )
                } else {
                    statBox(wert: "–", label: "HAQ-Score", farbe: .secondary)
                }
            }

            Chart(chartDaten, id: \.datum) { punkt in
                BarMark(
                    x: .value("Tag", punkt.datum, unit: .day),
                    y: .value("Schmerz", hatDaten ? punkt.wert : 1.0)
                )
                .foregroundStyle(hatDaten ? (punkt.wert > 0 ? Color.teal.opacity(0.75) : Color.teal.opacity(0.12)) : Color.teal.opacity(0.07))
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

            NavigationLink(destination: RheumaView()) {
                HStack {
                    Text("Rheuma-Modul öffnen")
                        .font(.caption.bold())
                        .foregroundStyle(.teal)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2.bold())
                        .foregroundStyle(Color.teal.opacity(0.6))
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: ausgewaehltTag)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .sheet(isPresented: $zeigeForm) { RheumaSchnellForm() }
    }

    private func staerkeFarbe(_ wert: Double) -> Color {
        guard wert > 0 else { return Color.teal.opacity(0.1) }
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
