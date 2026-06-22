import SwiftUI
import Charts

struct SchmerzKachel: View {
    let eintraege: [PainEntry]
    @State private var zeigeForm = false
    @State private var ausgewaehltTag: Date? = nil

    private var schmerzEintraege: [PainEntry] { eintraege.filter { !$0.istHautEintrag && $0.koerperstelle != "Rheuma" } }

    private var avgSchmerz30: String {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let gefiltert = schmerzEintraege.filter { $0.datum >= cutoff }
        guard !gefiltert.isEmpty else { return "–" }
        let avg = Double(gefiltert.map(\.schmerzstaerke).reduce(0, +)) / Double(gefiltert.count)
        return String(format: "%.1f", avg)
    }

    private var schube30: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return schmerzEintraege.filter { $0.istSchub && $0.datum >= cutoff }.count
    }

    private var eintraege7: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return schmerzEintraege.filter { $0.datum >= cutoff }.count
    }

    private var chartDaten: [(datum: Date, wert: Double)] {
        let cal = Calendar.current
        return (0..<14).reversed().map { offset in
            let tag = cal.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            let start = cal.startOfDay(for: tag)
            let end = cal.date(byAdding: .day, value: 1, to: start) ?? start
            let tagesEintraege = schmerzEintraege.filter { $0.datum >= start && $0.datum < end }
            let avg = tagesEintraege.isEmpty ? 0.0
                : Double(tagesEintraege.map(\.schmerzstaerke).reduce(0, +)) / Double(tagesEintraege.count)
            return (datum: start, wert: avg)
        }
    }

    private var hatDaten: Bool {
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        return schmerzEintraege.contains { $0.datum >= cutoff }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Schmerztagebuch", systemImage: "waveform.path.ecg")
                    .font(.headline)
                    .foregroundStyle(.red)
                Spacer()
                Button { zeigeForm = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 0) {
                statBox(
                    wert: avgSchmerz30,
                    label: "Ø Schmerz (30 T.)",
                    farbe: avgSchmerz30 == "–" ? .secondary : .red
                )
                Divider().frame(height: 32)
                statBox(
                    wert: "\(schube30)",
                    label: "Schübe (30 T.)",
                    farbe: schube30 == 0 ? .green : schube30 <= 2 ? .orange : .red
                )
                Divider().frame(height: 32)
                statBox(
                    wert: "\(eintraege7)",
                    label: "Einträge (7 T.)",
                    farbe: .secondary
                )
            }

            Chart(chartDaten, id: \.datum) { punkt in
                BarMark(
                    x: .value("Tag", punkt.datum, unit: .day),
                    y: .value("Schmerz", hatDaten ? punkt.wert : 1.0)
                )
                .foregroundStyle(hatDaten ? staerkeFarbe(punkt.wert) : Color.red.opacity(0.07))
                .cornerRadius(3)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: 0...10)
            .frame(height: 44)
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                            let x = value.location.x - geo[proxy.plotFrame].origin.x
                            guard x >= 0, let date: Date = proxy.value(atX: x) else { return }
                            ausgewaehltTag = Calendar.current.startOfDay(for: date)
                        })
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
                    Text(tag, format: .dateTime.day().month(.abbreviated))
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    if punkt.wert > 0 {
                        Text("Ø \(String(format: "%.1f", punkt.wert))")
                            .font(.caption2)
                            .foregroundStyle(staerkeFarbe(punkt.wert))
                    }
                    Spacer()
                }
            }

            Divider()

            NavigationLink(destination: SchmerzView()) {
                HStack {
                    Text("Schmerz-Modul öffnen")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2.bold())
                        .foregroundStyle(Color.red.opacity(0.6))
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .sheet(isPresented: $zeigeForm) { SchmerzForm() }
    }

    private func staerkeFarbe(_ wert: Double) -> Color {
        guard wert > 0 else { return Color.red.opacity(0.1) }
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
}
