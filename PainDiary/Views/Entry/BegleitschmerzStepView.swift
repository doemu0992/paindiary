import SwiftUI

struct BegleitschmerzStepView: View {
    @Binding var begleiterscheinungen: String
    let koerperstelle: String

    @State private var ausgewaehlt: Set<String> = []
    @State private var freitext = ""

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
                Text("Begleiterscheinungen (mehrere möglich)")
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
                HStack(spacing: 8) {
                    TextField("Eigene Angaben…", text: $freitext)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: freitext) { _, _ in aktualisiereBinding() }
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
        .onAppear { ladeAuswahlAusBinding() }
    }

    private func aktualisiereBinding() {
        var teile = ausgewaehlt.sorted()
        let trimmed = freitext.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { teile.append(trimmed) }
        begleiterscheinungen = teile.joined(separator: ", ")
    }

    private func ladeAuswahlAusBinding() {
        let teile = begleiterscheinungen
            .components(separatedBy: ", ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        ausgewaehlt = Set(teile.filter { vorschlaege.contains($0) })
        let custom = teile.filter { !vorschlaege.contains($0) }
        freitext = custom.joined(separator: ", ")
    }
}
