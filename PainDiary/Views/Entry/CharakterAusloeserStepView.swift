import SwiftUI

struct CharakterAusloeserStepView: View {
    @Binding var schmerzart: String
    @Binding var dauerMinuten: Int
    @Binding var ausloeser: String
    let koerperstelle: String

    @State private var charakterAusgewaehlt: Set<String> = []
    @State private var charakterFreitext = ""
    @State private var ausloeserAusgewaehlt: Set<String> = []
    @State private var ausloeserFreitext = ""

    private var charakterVorschlaege: [String] {
        SchmerzLexikon.db[koerperstelle]?.charakter ?? [
            "Stechend", "Ziehend", "Dumpf", "Brennend", "Krampfartig", "Pulsierend", "Drückend"
        ]
    }

    private var ausloeserVorschlaege: [String] {
        SchmerzLexikon.db[koerperstelle]?.ausloeser ?? [
            "Stress", "Bewegung", "Wetter", "Schlafmangel",
            "Essen", "Alkohol", "Bildschirmarbeit", "Kälte", "Unbekannt"
        ]
    }

    var body: some View {
        VStack(spacing: 24) {
            stepHeader

            VStack(alignment: .leading, spacing: 12) {
                Text("Schmerzart")
                    .font(.headline)
                FlowLayout(charakterVorschlaege) { v in
                    ChipButton(label: v, ausgewaehlt: charakterAusgewaehlt.contains(v)) {
                        if charakterAusgewaehlt.contains(v) { charakterAusgewaehlt.remove(v) }
                        else { charakterAusgewaehlt.insert(v) }
                        aktualisiereSchmerzart()
                    }
                }
                HStack(spacing: 8) {
                    TextField("Eigene Beschreibung…", text: $charakterFreitext)
                        .textFieldStyle(.roundedBorder)
                    if !charakterFreitext.isEmpty {
                        Button {
                            charakterAusgewaehlt.insert(charakterFreitext.trimmingCharacters(in: .whitespaces))
                            charakterFreitext = ""
                            aktualisiereSchmerzart()
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
                        .font(.subheadline.bold())
                        .foregroundStyle(.blue)
                }
                Slider(value: Binding(
                    get: { Double(dauerMinuten) },
                    set: { dauerMinuten = Int($0) }
                ), in: 0...480, step: 15)
                .tint(.blue)
                HStack {
                    Text("Keine Angabe").font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text("8 Std.").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 12) {
                Text("Auslöser")
                    .font(.headline)
                FlowLayout(ausloeserVorschlaege) { v in
                    ChipButton(label: v, ausgewaehlt: ausloeserAusgewaehlt.contains(v)) {
                        if ausloeserAusgewaehlt.contains(v) { ausloeserAusgewaehlt.remove(v) }
                        else { ausloeserAusgewaehlt.insert(v) }
                        aktualisiereAusloeser()
                    }
                }
                HStack(spacing: 8) {
                    TextField("Eigener Auslöser…", text: $ausloeserFreitext)
                        .textFieldStyle(.roundedBorder)
                    if !ausloeserFreitext.isEmpty {
                        Button {
                            ausloeserAusgewaehlt.insert(ausloeserFreitext.trimmingCharacters(in: .whitespaces))
                            ausloeserFreitext = ""
                            aktualisiereAusloeser()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal)
        .onAppear { ladeBindings() }
    }

    private var stepHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 38))
                .foregroundStyle(.blue)
                .padding(14)
                .background(Color.blue.opacity(0.1), in: Circle())
            Text("Wie und warum?")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private func aktualisiereSchmerzart() {
        schmerzart = charakterAusgewaehlt.sorted().joined(separator: ", ")
    }

    private func aktualisiereAusloeser() {
        ausloeser = ausloeserAusgewaehlt.sorted().joined(separator: ", ")
    }

    private func ladeBindings() {
        charakterAusgewaehlt = Set(schmerzart.components(separatedBy: ", ").filter { !$0.isEmpty })
        ausloeserAusgewaehlt = Set(ausloeser.components(separatedBy: ", ").filter { !$0.isEmpty })
    }

    private func formatierteDauer(_ min: Int) -> String {
        if min == 0 { return "Keine Angabe" }
        let h = min / 60; let m = min % 60
        if h == 0 { return "\(m) Min." }
        if m == 0 { return "\(h) Std." }
        return "\(h) Std. \(m) Min."
    }
}
