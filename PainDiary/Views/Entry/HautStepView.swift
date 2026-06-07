import SwiftUI

struct HautStepView: View {
    @Binding var hautStellen: String
    @Binding var hautArt: String

    private let artVorschlaege = [
        "Ausschlag", "Schuppenflechte", "Ekzem", "Rötung", "Schwellung",
        "Hämatom", "Wunde", "Juckreiz", "Trockene Haut", "Verbrennung", "Bläschen"
    ]

    @State private var artAusgewaehlt: Set<String> = []
    @State private var eigenerText = ""

    private var stellenSet: Set<String> {
        Set(hautStellen.components(separatedBy: ", ").filter { !$0.isEmpty })
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("Hautveränderungen?")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 10) {
                Text("Betroffene Stellen")
                    .font(.headline)

                KoerperPickerView(auswahl: $hautStellen, tintColor: .systemOrange, frameHeight: 300)

                if !stellenSet.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(stellenSet.sorted(), id: \.self) { s in
                                Button {
                                    var set = stellenSet
                                    set.remove(s)
                                    hautStellen = set.sorted().joined(separator: ", ")
                                } label: {
                                    HStack(spacing: 3) {
                                        Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                                        Text(s).font(.caption)
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(Color.orange.opacity(0.15))
                                    .foregroundStyle(.orange)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 30)
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 12) {
                Text("Art der Veränderung")
                    .font(.headline)
                FlowLayout(artVorschlaege) { art in
                    ChipButton(label: art, ausgewaehlt: artAusgewaehlt.contains(art)) {
                        if artAusgewaehlt.contains(art) { artAusgewaehlt.remove(art) }
                        else { artAusgewaehlt.insert(art) }
                        hautArt = artAusgewaehlt.sorted().joined(separator: ", ")
                    }
                }
                HStack(spacing: 8) {
                    TextField("Weitere Art…", text: $eigenerText)
                        .textFieldStyle(.roundedBorder)
                    if !eigenerText.isEmpty {
                        Button {
                            let t = eigenerText.trimmingCharacters(in: .whitespaces)
                            artAusgewaehlt.insert(t)
                            eigenerText = ""
                            hautArt = artAusgewaehlt.sorted().joined(separator: ", ")
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
        .onAppear {
            artAusgewaehlt = Set(hautArt.components(separatedBy: ", ").filter { !$0.isEmpty })
        }
    }
}
