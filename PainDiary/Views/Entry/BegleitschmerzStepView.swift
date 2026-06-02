import SwiftUI

struct BegleitschmerzStepView: View {
    @Binding var begleiterscheinungen: String
    let koerperstelle: String

    @State private var ausgewaehlt: Set<String> = []

    private var vorschlaege: [String] {
        SchmerzLexikon.db[koerperstelle]?.symptome ?? [
            "Übelkeit", "Schwindel", "Müdigkeit", "Schlafstörungen",
            "Appetitlosigkeit", "Stimmungsschwankungen", "Konzentrationsprobleme"
        ]
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("Hast du weitere Beschwerden?")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 12) {
                Text("Begleiterscheinungen")
                    .font(.headline)
                FlowLayout(vorschlaege) { vorschlag in
                    ChipButton(label: vorschlag, ausgewaehlt: ausgewaehlt.contains(vorschlag)) {
                        if ausgewaehlt.contains(vorschlag) {
                            ausgewaehlt.remove(vorschlag)
                        } else {
                            ausgewaehlt.insert(vorschlag)
                        }
                        aktualisiereBinding()
                    }
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 8) {
                Text("Weitere Symptome")
                    .font(.headline)
                TextField("Eigene Angaben…", text: $begleiterscheinungen)
                    .textFieldStyle(.roundedBorder)
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
    }

    private func aktualisiereBinding() {
        let chips = ausgewaehlt.sorted().joined(separator: ", ")
        if begleiterscheinungen.isEmpty || vorschlaege.contains(where: { begleiterscheinungen.contains($0) }) {
            begleiterscheinungen = chips
        }
    }

    private func ladeAuswahlAusBinding() {
        let teile = begleiterscheinungen.components(separatedBy: ", ")
        ausgewaehlt = Set(teile.filter { vorschlaege.contains($0) })
    }
}
