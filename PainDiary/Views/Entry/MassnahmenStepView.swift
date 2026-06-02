import SwiftUI

struct MassnahmenStepView: View {
    @Binding var massnahmen: String
    @Binding var stimmung: Int
    @Binding var schlafStunden: Double

    private let massnahmenVorschlaege = [
        "Schmerzmittel", "Wärme", "Kälte", "Ruhe", "Massage",
        "Dehnung", "Sport", "Meditation", "Arzt besucht", "Schlaf"
    ]

    @State private var ausgewaehlt: Set<String> = []

    var body: some View {
        VStack(spacing: 24) {
            Text("Was hast du unternommen?")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 12) {
                Text("Massnahmen")
                    .font(.headline)
                FlowLayout(massnahmenVorschlaege) { m in
                    ChipButton(label: m, ausgewaehlt: ausgewaehlt.contains(m)) {
                        if ausgewaehlt.contains(m) { ausgewaehlt.remove(m) }
                        else { ausgewaehlt.insert(m) }
                        aktualisiereBinding()
                    }
                }
                TextField("Weitere Massnahmen…", text: $massnahmen)
                    .textFieldStyle(.roundedBorder)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 16) {
                Text("Wohlbefinden")
                    .font(.headline)

                HStack {
                    Text("Stimmung")
                    Spacer()
                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { i in
                            Image(systemName: i <= stimmung ? "heart.fill" : "heart")
                                .font(.title2)
                                .foregroundStyle(i <= stimmung ? .red : .secondary.opacity(0.4))
                                .onTapGesture { stimmung = i }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Schlaf letzte Nacht")
                        Spacer()
                        Text(String(format: "%.1f Std.", schlafStunden))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $schlafStunden, in: 0...12, step: 0.5)
                        .tint(.indigo)
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal)
        .onAppear { ladeAuswahlAusBinding() }
    }

    private func aktualisiereBinding() {
        let chips = ausgewaehlt.sorted().joined(separator: ", ")
        if massnahmen.isEmpty || massnahmenVorschlaege.contains(where: { massnahmen.contains($0) }) {
            massnahmen = chips
        }
    }

    private func ladeAuswahlAusBinding() {
        let teile = massnahmen.components(separatedBy: ", ")
        ausgewaehlt = Set(teile.filter { massnahmenVorschlaege.contains($0) })
    }
}
