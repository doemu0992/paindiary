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

            if !eingenommeneHeute.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Eingenommene Medikamente")
                        .font(.headline)
                    FlowLayout(eingenommeneHeute.map { medLabel($0) }) { label in
                        ChipButton(label: label, ausgewaehlt: ausgewaehlt.contains(label)) {
                            toggleChip(label)
                        }
                    }
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Massnahmen (mehrere möglich)")
                    .font(.headline)
                FlowLayout(massnahmenVorschlaege) { m in
                    ChipButton(label: m, ausgewaehlt: ausgewaehlt.contains(m)) {
                        toggleChip(m)
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
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

            Text("Optional – du kannst diesen Schritt überspringen.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
        .onAppear { ladeAuswahlAusBinding() }
        .onChange(of: eingenommeneHeute.map { $0.medikamentName }, initial: false) {
            vorauswaehlenMedikamente()
        }
    }

    private func medLabel(_ log: EinnahmeLog) -> String {
        log.dosierung.isEmpty ? log.medikamentName : "\(log.medikamentName) \(log.dosierung)"
    }

    private func toggleChip(_ label: String) {
        if ausgewaehlt.contains(label) { ausgewaehlt.remove(label) }
        else { ausgewaehlt.insert(label) }
        aktualisiereBinding()
    }

    private func aktualisiereBinding() {
        massnahmen = ausgewaehlt.sorted().joined(separator: ", ")
    }

    private func ladeAuswahlAusBinding() {
        let teile = massnahmen.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }
        ausgewaehlt = Set(teile.filter { !$0.isEmpty })
        vorauswaehlenMedikamente()
    }

    private func vorauswaehlenMedikamente() {
        for log in eingenommeneHeute {
            ausgewaehlt.insert(medLabel(log))
        }
        aktualisiereBinding()
    }
}
