import SwiftUI

struct AusloeserStepView: View {
    @Binding var ausloeser: String
    let koerperstelle: String

    private var vorschlaege: [String] {
        SchmerzLexikon.db[koerperstelle]?.ausloeser ?? [
            "Stress", "Bewegung", "Wetter", "Schlafmangel", "Essen", "Unbekannt"
        ]
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("Was könnte die Schmerzen ausgelöst haben?")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 12) {
                Text("Häufige Auslöser")
                    .font(.headline)
                FlowLayout(vorschlaege) { vorschlag in
                    ChipButton(label: vorschlag, ausgewaehlt: ausloeser == vorschlag) {
                        ausloeser = (ausloeser == vorschlag) ? "" : vorschlag
                    }
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 8) {
                Text("Eigene Angabe")
                    .font(.headline)
                TextField("z.B. Sport, Stress, Essen…", text: $ausloeser)
                    .textFieldStyle(.roundedBorder)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

            Text("Du kannst auch überspringen, wenn du es nicht weisst.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
    }
}
