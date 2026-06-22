import SwiftUI
import SwiftData
import Charts

struct WellnessKachel: View {
    let eintraege: [PainEntry]
    let wellnessEintraege: [WellnessEintrag]
    @State private var zeigeView = false
    @State private var ausgewaehltTag: Date? = nil
    @State private var versteckTask: Task<Void, Never>? = nil

    // MARK: - Stats (PainEntry + WellnessEintrag merged)

    private var heuteWasser: Int {
        let heute = Calendar.current.startOfDay(for: Date())
        return wellnessEintraege.first(where: { Calendar.current.isDate($0.datum, inSameDayAs: heute) })?.wasserMl ?? 0
    }

    private var avgStimmung7T: Double {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let cal = Calendar.current
        var tageValues: [Double] = []
        for offset in 0..<7 {
            guard let tag = cal.date(byAdding: .day, value: -offset, to: cal.startOfDay(for: Date())) else { continue }
            let painEntries = eintraege.filter { $0.datum >= cutoff && cal.isDate($0.datum, inSameDayAs: tag) && $0.stimmung > 0 }
            if !painEntries.isEmpty {
                tageValues.append(Double(painEntries.map(\.stimmung).reduce(0, +)) / Double(painEntries.count))
            } else if let w = wellnessEintraege.first(where: { cal.isDate($0.datum, inSameDayAs: tag) }), w.stimmung > 0 {
                tageValues.append(Double(w.stimmung))
            }
        }
        return tageValues.isEmpty ? 0 : tageValues.reduce(0, +) / Double(tageValues.count)
    }

    private var avgSchlaf7T: Double {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let cal = Calendar.current
        var tageValues: [Double] = []
        for offset in 0..<7 {
            guard let tag = cal.date(byAdding: .day, value: -offset, to: cal.startOfDay(for: Date())) else { continue }
            let painEntries = eintraege.filter { $0.datum >= cutoff && cal.isDate($0.datum, inSameDayAs: tag) && $0.schlafStunden > 0 }
            if !painEntries.isEmpty {
                tageValues.append(painEntries.map(\.schlafStunden).reduce(0, +) / Double(painEntries.count))
            } else if let w = wellnessEintraege.first(where: { cal.isDate($0.datum, inSameDayAs: tag) }), w.schlafStunden > 0 {
                tageValues.append(w.schlafStunden)
            }
        }
        return tageValues.isEmpty ? 0 : tageValues.reduce(0, +) / Double(tageValues.count)
    }

    // MARK: - Chart Data (14-day mood, merges PainEntry + WellnessEintrag)

    private var chartDaten: [(datum: Date, stimmung: Double)] {
        let cal = Calendar.current
        return (0..<14).reversed().map { offset in
            let tag = cal.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            let start = cal.startOfDay(for: tag)
            let end = cal.date(byAdding: .day, value: 1, to: start) ?? start
            let painTages = eintraege.filter { $0.datum >= start && $0.datum < end && $0.stimmung > 0 }
            if !painTages.isEmpty {
                let avg = Double(painTages.map(\.stimmung).reduce(0, +)) / Double(painTages.count)
                return (datum: start, stimmung: avg)
            }
            if let w = wellnessEintraege.first(where: { cal.isDate($0.datum, inSameDayAs: start) }), w.stimmung > 0 {
                return (datum: start, stimmung: Double(w.stimmung))
            }
            return (datum: start, stimmung: 0)
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

    private func stimmungLabel(_ s: Double) -> String {
        switch s {
        case ..<2:  return "Schlecht"
        case ..<3:  return "Mäßig"
        case ..<4:  return "Okay"
        case ..<5:  return "Gut"
        default:    return "Sehr gut"
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

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
                    if punkt.stimmung > 0 {
                        Text("Stimmung \(String(format: "%.1f", punkt.stimmung)) – \(stimmungLabel(punkt.stimmung))")
                            .font(.caption2)
                            .foregroundStyle(stimmungFarbe(punkt.stimmung))
                    } else {
                        Text("Kein Eintrag").font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .transition(.opacity)
            }

            Divider()

            NavigationLink(destination: WellnessView()) {
                HStack {
                    Text("Wohlbefinden öffnen").font(.caption.bold()).foregroundStyle(.mint)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2.bold()).foregroundStyle(Color.mint.opacity(0.6))
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: ausgewaehltTag)
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
