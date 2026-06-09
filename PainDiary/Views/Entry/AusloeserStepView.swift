import SwiftUI

struct AusloeserStepView: View {
    @Binding var ausloeser: String
    let koerperstelle: String

    @State private var ausgewaehlt: Set<String> = []
    @State private var eigenerText = ""

    private var vorschlaege: [String] {
        SchmerzLexikon.db[koerperstelle]?.ausloeser ?? [
            "Stress", "Bewegung", "Wetter", "Schlafmangel", "Essen",
            "Alkohol", "Bildschirmarbeit", "Kälte", "Unbekannt"
        ]
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("Was könnte die Schmerzen ausgelöst haben?")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 12) {
                Text("Häufige Auslöser (mehrere möglich)")
                    .font(.headline)
                FlowLayout(vorschlaege) { vorschlag in
                    ChipButton(label: vorschlag, ausgewaehlt: ausgewaehlt.contains(vorschlag)) {
                        if ausgewaehlt.contains(vorschlag) { ausgewaehlt.remove(vorschlag) }
                        else { ausgewaehlt.insert(vorschlag) }
                        aktualisiereBinding()
                    }
                }
                HStack(spacing: 8) {
                    TextField("Eigener Auslöser…", text: $eigenerText)
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

            Text("Du kannst auch überspringen, wenn du es nicht weisst.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
        .onAppear { ladeAuswahlAusBinding() }
    }

    private func aktualisiereBinding() {
        ausloeser = ausgewaehlt.sorted().joined(separator: ", ")
    }

    private func ladeAuswahlAusBinding() {
        let teile = ausloeser.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }
        ausgewaehlt = Set(teile.filter { !$0.isEmpty })
    }
}
