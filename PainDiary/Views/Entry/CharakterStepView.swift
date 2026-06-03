import SwiftUI

struct CharakterStepView: View {
    @Binding var schmerzart: String
    @Binding var dauerMinuten: Int
    let koerperstelle: String

    @State private var ausgewaehlt: Set<String> = []
    @State private var eigenerText = ""

    private var vorschlaege: [String] {
        SchmerzLexikon.db[koerperstelle]?.charakter ?? [
            "Stechend", "Ziehend", "Dumpf", "Brennend", "Krampfartig", "Pulsierend", "Drückend"
        ]
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("Wie fühlen sich die Schmerzen an?")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 12) {
                Text("Schmerzart (mehrere möglich)")
                    .font(.headline)
                FlowLayout(vorschlaege) { vorschlag in
                    ChipButton(label: vorschlag, ausgewaehlt: ausgewaehlt.contains(vorschlag)) {
                        if ausgewaehlt.contains(vorschlag) { ausgewaehlt.remove(vorschlag) }
                        else { ausgewaehlt.insert(vorschlag) }
                        aktualisiereBinding()
                    }
                }
                HStack(spacing: 8) {
                    TextField("Eigene Beschreibung…", text: $eigenerText)
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

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Dauer")
                        .font(.headline)
                    Spacer()
                    Text(formatierteDauer(dauerMinuten))
                        .foregroundStyle(.secondary)
                }
                Slider(value: Binding(
                    get: { Double(dauerMinuten) },
                    set: { dauerMinuten = Int($0) }
                ), in: 0...480, step: 15)
                .tint(.blue)
                HStack {
                    Text("Keine Angabe").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("8 Std.").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal)
        .onAppear { ladeAuswahlAusBinding() }
    }

    private func aktualisiereBinding() {
        schmerzart = ausgewaehlt.sorted().joined(separator: ", ")
    }

    private func ladeAuswahlAusBinding() {
        let teile = schmerzart.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }
        ausgewaehlt = Set(teile.filter { !$0.isEmpty })
    }

    private func formatierteDauer(_ min: Int) -> String {
        if min == 0 { return "Keine Angabe" }
        let h = min / 60; let m = min % 60
        if h == 0 { return "\(m) Min." }
        if m == 0 { return "\(h) Std." }
        return "\(h) Std. \(m) Min."
    }
}

struct FlowLayout<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let content: (Data.Element) -> Content

    init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.content = content
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], alignment: .leading, spacing: 8) {
            ForEach(Array(data), id: \.self) { item in
                content(item)
            }
        }
    }
}

struct ChipButton: View {
    let label: String
    let ausgewaehlt: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if ausgewaehlt {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                }
                Text(label)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(ausgewaehlt ? Color.accentColor : Color.secondary.opacity(0.15))
            .foregroundStyle(ausgewaehlt ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: ausgewaehlt)
    }
}
