import SwiftUI

struct BegleitschmerzStepView: View {
    @Binding var begleiterscheinungen: String
    let koerperstelle: String

    @State private var ausgewaehlt: Set<String> = []
    @State private var freitext = ""
    @State private var eigeneChips: [String] = []

    private static let chipKey = "chipEigeneBegleiterscheinungen"

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
                if !eigeneChips.isEmpty {
                    FlowLayout(eigeneChips) { chip in
                        ChipButton(label: chip, ausgewaehlt: ausgewaehlt.contains(chip), farbe: .indigo) {
                            if ausgewaehlt.contains(chip) { ausgewaehlt.remove(chip) }
                            else { ausgewaehlt.insert(chip) }
                            aktualisiereBinding()
                        }
                    }
                }
                HStack(spacing: 8) {
                    TextField("Eigene Angaben…", text: $freitext)
                        .textFieldStyle(.roundedBorder)
                    if !freitext.isEmpty {
                        Button {
                            let wert = freitext.trimmingCharacters(in: .whitespaces)
                            ausgewaehlt.insert(wert)
                            ChipSpeicher.hinzufuegen(wert, schluessel: Self.chipKey)
                            eigeneChips = ChipSpeicher.laden(schluessel: Self.chipKey)
                            freitext = ""
                            aktualisiereBinding()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.indigo)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))

            Text("Optional – du kannst diesen Schritt überspringen.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
        .onAppear {
            eigeneChips = ChipSpeicher.laden(schluessel: Self.chipKey)
            ladeAuswahlAusBinding()
        }
    }

    private func aktualisiereBinding() {
        begleiterscheinungen = ausgewaehlt.sorted().joined(separator: ", ")
    }

    private func ladeAuswahlAusBinding() {
        let teile = begleiterscheinungen
            .components(separatedBy: ", ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        ausgewaehlt = Set(teile.filter { vorschlaege.contains($0) || eigeneChips.contains($0) })
    }
}
