import SwiftUI
import Charts

struct RheumaKachel: View {
    let eintraege: [PainEntry]
    let haqEintraege: [HAQEintrag]
    @State private var zeigeForm = false

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
            let hatEintrag = rheumaEintraege.contains { $0.datum >= start && $0.datum < end }
            return (datum: start, wert: hatEintrag ? 1.0 : 0.0)
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
                .foregroundStyle(hatDaten
                    ? Color.teal.opacity(punkt.wert > 0 ? 0.75 : 0.1)
                    : Color.teal.opacity(0.07))
                .cornerRadius(3)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: 0...1)
            .frame(height: 44)
            .overlay(alignment: .center) {
                if !hatDaten {
                    Text("Noch keine Einträge")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
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
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .sheet(isPresented: $zeigeForm) { RheumaSchnellForm() }
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
