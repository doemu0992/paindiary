import SwiftUI

struct CharakterStepView: View {
    @Binding var schmerzart: String
    @Binding var dauerMinuten: Int
    let koerperstelle: String

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
                Text("Schmerzart")
                    .font(.headline)
                FlowLayout(vorschlaege) { vorschlag in
                    ChipButton(label: vorschlag, ausgewaehlt: schmerzart == vorschlag) {
                        schmerzart = (schmerzart == vorschlag) ? "" : vorschlag
                    }
                }
                TextField("Oder eigene Beschreibung…", text: $schmerzart)
                    .textFieldStyle(.roundedBorder)
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
                    Text("Kürzer").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("8 Std.").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal)
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
        _FlowLayout(data: data, content: content)
    }
}

private struct _FlowLayout<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let content: (Data.Element) -> Content

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], alignment: .leading, spacing: 8) {
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
            Text(label)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(ausgewaehlt ? Color.accentColor : Color.secondary.opacity(0.15))
                .foregroundStyle(ausgewaehlt ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
