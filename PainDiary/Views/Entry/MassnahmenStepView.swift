import SwiftUI
import SwiftData

struct MassnahmenStepView: View {
    @Binding var massnahmen: String
    var datum: Date = .now

    @Query private var alleEinnahmen: [EinnahmeLog]

    private let massnahmenVorschlaege = [
        "Schmerzmittel", "Wärme", "Kälte", "Ruhe", "Massage",
        "Dehnung", "Sport", "Meditation", "Arzt besucht", "Schlaf"
    ]

    @State private var ausgewaehlt: Set<String> = []
    @State private var eigenerText = ""

    private var eingenommeneHeute: [EinnahmeLog] {
        let cal = Calendar.current
        return alleEinnahmen.filter {
            $0.eingenommen && cal.isDate($0.datum, inSameDayAs: datum)
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("Was hast du unternommen?")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            // Read-only info: Dauermedikamente are tracked separately in adherence analysis
            if !eingenommeneHeute.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Heute eingenommen:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(eingenommeneHeute.map { medLabel($0) }.joined(separator: ", "))
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Massnahmen (mehrere möglich)")
                    .font(.headline)
                FlowLayout(massnahmenVorschlaege) { m in
                    ChipButton(label: m, ausgewaehlt: ausgewaehlt.contains(m)) {
                        if ausgewaehlt.contains(m) { ausgewaehlt.remove(m) }
                        else { ausgewaehlt.insert(m) }
                        aktualisiereBinding()
                    }
                }
                HStack(spacing: 8) {
                    TextField("Weitere Massnahme…", text: $eigenerText)
                        .textFieldStyle(.roundedBorder)
                    if !eigenerText.isEmpty {
                        Button {
                            ausgewaehlt.insert(eigenerText)
                            eigenerText = ""
                            aktualisiereBinding()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))

            Text("Optional – du kannst diesen Schritt überspringen.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
        .onAppear {
            let teile = massnahmen.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }
            ausgewaehlt = Set(teile.filter { !$0.isEmpty })
        }
    }

    private func medLabel(_ log: EinnahmeLog) -> String {
        log.dosierung.isEmpty ? log.medikamentName : "\(log.medikamentName) \(log.dosierung)"
    }

    private func aktualisiereBinding() {
        massnahmen = ausgewaehlt.sorted().joined(separator: ", ")
    }
}
