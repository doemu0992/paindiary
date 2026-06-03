import SwiftUI

struct MassnahmenStepView: View {
    @Binding var massnahmen: String
    @Binding var stimmung: Int
    @Binding var schlafStunden: Double
    @Binding var stressLevel: Int
    var healthSchlafVorschlag: Double? = nil

    private let massnahmenVorschlaege = [
        "Schmerzmittel", "Wärme", "Kälte", "Ruhe", "Massage",
        "Dehnung", "Sport", "Meditation", "Arzt besucht", "Schlaf"
    ]

    @State private var ausgewaehlt: Set<String> = []
    @State private var eigenerText = ""

    var body: some View {
        VStack(spacing: 24) {
            Text("Was hast du unternommen?")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

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
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 16) {
                Text("Wohlbefinden")
                    .font(.headline)

                // Stimmung
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

                // Stress
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Stresslevel")
                        Spacer()
                        Text(stressBezeichnung(stressLevel))
                            .font(.subheadline.bold())
                            .foregroundStyle(stressFarbe(stressLevel))
                    }
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(i <= stressLevel ? stressFarbe(stressLevel) : Color.secondary.opacity(0.2))
                                .frame(maxWidth: .infinity)
                                .frame(height: 8)
                                .onTapGesture { stressLevel = i }
                        }
                    }
                    HStack {
                        Text("Entspannt").font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Text("Extrem").font(.caption2).foregroundStyle(.secondary)
                    }
                }

                // Schlaf
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Schlaf letzte Nacht")
                        Spacer()
                        Text(String(format: "%.1f Std.", schlafStunden))
                            .foregroundStyle(.secondary)
                        if let hs = healthSchlafVorschlag {
                            Button {
                                schlafStunden = min(hs, 12)
                            } label: {
                                Label(
                                    String(format: "Health: %.1f Std.", hs),
                                    systemImage: "heart.fill"
                                )
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red.opacity(0.1), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
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

    private func stressBezeichnung(_ level: Int) -> String {
        switch level {
        case 1: return "Entspannt"
        case 2: return "Leicht"
        case 3: return "Mässig"
        case 4: return "Hoch"
        case 5: return "Extrem"
        default: return "Mässig"
        }
    }

    private func stressFarbe(_ level: Int) -> Color {
        switch level {
        case 1: return .green
        case 2: return .mint
        case 3: return .yellow
        case 4: return .orange
        case 5: return .red
        default: return .yellow
        }
    }

    private func aktualisiereBinding() {
        massnahmen = ausgewaehlt.sorted().joined(separator: ", ")
    }

    private func ladeAuswahlAusBinding() {
        let teile = massnahmen.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }
        ausgewaehlt = Set(teile.filter { !$0.isEmpty })
    }
}
