import SwiftUI

struct RheumaKachel: View {
    let eintraege: [PainEntry]
    let haqEintraege: [HAQEintrag]

    private var schube30: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return eintraege.filter { $0.istSchub && $0.datum >= cutoff }.count
    }

    private var letzterSchubText: String {
        guard let letzter = eintraege.first(where: { $0.istSchub }) else { return "Keiner" }
        let tage = Calendar.current.dateComponents([.day], from: letzter.datum, to: Date()).day ?? 0
        switch tage {
        case 0:  return "Heute"
        case 1:  return "Gestern"
        default: return "Vor \(tage) Tagen"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Rheuma & Gelenke", systemImage: "figure.arms.open")
                    .font(.headline)
                    .foregroundStyle(.purple)
                Spacer()
            }

            HStack(spacing: 0) {
                statBox(
                    wert: "\(schube30)",
                    label: "Schübe (30 T.)",
                    farbe: schube30 == 0 ? .green : schube30 <= 2 ? .orange : .red
                )
                Divider().frame(height: 32)
                statBox(
                    wert: letzterSchubText,
                    label: "Letzter Schub",
                    farbe: .secondary
                )
                if let letzterHAQ = haqEintraege.first {
                    Divider().frame(height: 32)
                    statBox(
                        wert: String(format: "%.2f", letzterHAQ.haqScore),
                        label: "HAQ-Score",
                        farbe: letzterHAQ.haqScore < 0.5 ? .green : letzterHAQ.haqScore < 1.5 ? .orange : .red
                    )
                }
            }

            Divider()

            NavigationLink(destination: RheumaView()) {
                HStack {
                    Text("Rheuma-Modul öffnen")
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
