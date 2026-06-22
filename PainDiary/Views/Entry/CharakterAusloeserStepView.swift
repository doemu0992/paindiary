import SwiftUI

struct CharakterAusloeserStepView: View {
    @Binding var schmerzart: String
    @Binding var dauerMinuten: Int
    @Binding var ausloeser: String
    let koerperstelle: String

    @State private var charAusgewaehlt: Set<String> = []
    @State private var charFreitext = ""
    @State private var ausloeserAusgewaehlt: Set<String> = []
    @State private var ausloeserFreitext = ""

    @AppStorage("customCharakter") private var customCharakterRaw = ""
    @AppStorage("customAusloeser") private var customAusloeserRaw = ""

    private var customCharakter: [String] {
        customCharakterRaw.split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private var customAusloeser: [String] {
        customAusloeserRaw.split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private var charakterVorschlaege: [String] {
        let basis = SchmerzLexikon.db[koerperstelle]?.charakter ?? [
            "Stechend", "Ziehend", "Dumpf", "Brennend", "Krampfartig", "Pulsierend", "Drückend"
        ]
        return basis + customCharakter.filter { !basis.contains($0) }
    }

    private var ausloeserVorschlaege: [String] {
        let basis = SchmerzLexikon.db[koerperstelle]?.ausloeser ?? [
            "Stress", "Bewegung", "Wetter", "Schlafmangel", "Essen",
            "Alkohol", "Bildschirmarbeit", "Kälte", "Unbekannt"
        ]
        return basis + customAusloeser.filter { !basis.contains($0) }
    }

    var body: some View {
        VStack(spacing: 24) {
            // Step header
            VStack(spacing: 6) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 32))
                    .foregroundStyle(.blue)
                Text("Wie und warum?")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
            }

            // Card 1: Schmerzart
            VStack(alignment: .leading, spacing: 12) {
                Text("Schmerzart (mehrere möglich)")
                    .font(.headline)
                FlowLayout(charakterVorschlaege) { vorschlag in
                    ChipButton(label: vorschlag, ausgewaehlt: charAusgewaehlt.contains(vorschlag)) {
                        if charAusgewaehlt.contains(vorschlag) { charAusgewaehlt.remove(vorschlag) }
                        else { charAusgewaehlt.insert(vorschlag) }
                        aktualisiereSchmerzart()
                    }
                }
                HStack(spacing: 8) {
                    TextField("Eigene Beschreibung…", text: $charFreitext)
                        .textFieldStyle(.roundedBorder)
                    if !charFreitext.isEmpty {
                        Button {
                            let term = charFreitext.trimmingCharacters(in: .whitespaces)
                            guard !term.isEmpty else { return }
                            charAusgewaehlt.insert(term)
                            charFreitext = ""
                            aktualisiereSchmerzart()
                            if !charakterVorschlaege.contains(term) {
                                customCharakterRaw = (customCharakter + [term]).joined(separator: ",")
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.accentColor)
                                .font(.title2)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))

            // Card 2: Dauer
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
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))

            // Card 3: Auslöser
            VStack(alignment: .leading, spacing: 12) {
                Text("Häufige Auslöser (mehrere möglich)")
                    .font(.headline)
                FlowLayout(ausloeserVorschlaege) { vorschlag in
                    ChipButton(label: vorschlag, ausgewaehlt: ausloeserAusgewaehlt.contains(vorschlag)) {
                        if ausloeserAusgewaehlt.contains(vorschlag) { ausloeserAusgewaehlt.remove(vorschlag) }
                        else { ausloeserAusgewaehlt.insert(vorschlag) }
                        aktualisiereAusloeser()
                    }
                }
                HStack(spacing: 8) {
                    TextField("Eigener Auslöser…", text: $ausloeserFreitext)
                        .textFieldStyle(.roundedBorder)
                    if !ausloeserFreitext.isEmpty {
                        Button {
                            let term = ausloeserFreitext.trimmingCharacters(in: .whitespaces)
                            guard !term.isEmpty else { return }
                            ausloeserAusgewaehlt.insert(term)
                            ausloeserFreitext = ""
                            aktualisiereAusloeser()
                            if !ausloeserVorschlaege.contains(term) {
                                customAusloeserRaw = (customAusloeser + [term]).joined(separator: ",")
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.accentColor)
                                .font(.title2)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal)
        .onAppear { ladeWerte() }
    }

    private func aktualisiereSchmerzart() {
        schmerzart = charAusgewaehlt.sorted().joined(separator: ", ")
    }

    private func aktualisiereAusloeser() {
        ausloeser = ausloeserAusgewaehlt.sorted().joined(separator: ", ")
    }

    private func ladeWerte() {
        let charTeile = schmerzart.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }
        charAusgewaehlt = Set(charTeile.filter { !$0.isEmpty })

        let ausloeserTeile = ausloeser.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }
        ausloeserAusgewaehlt = Set(ausloeserTeile.filter { !$0.isEmpty })
    }

    private func formatierteDauer(_ min: Int) -> String {
        if min == 0 { return "Keine Angabe" }
        let h = min / 60; let m = min % 60
        if h == 0 { return "\(m) Min." }
        if m == 0 { return "\(h) Std." }
        return "\(h) Std. \(m) Min."
    }
}
