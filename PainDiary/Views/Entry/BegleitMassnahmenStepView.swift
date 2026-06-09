import SwiftUI
import SwiftData

struct BegleitMassnahmenStepView: View {
    @Binding var begleiterscheinungen: String
    @Binding var massnahmen: String
    let koerperstelle: String
    let datum: Date

    @Query private var alleEinnahmen: [EinnahmeLog]

    @State private var begleitAusgewaehlt: Set<String> = []
    @State private var begleitFreitext = ""
    @State private var massnahmenAusgewaehlt: Set<String> = []
    @State private var massnahmenFreitext = ""

    private let massnahmenVorschlaege = [
        "Schmerzmittel", "Wärme", "Kälte", "Ruhe", "Massage",
        "Dehnung", "Sport", "Meditation", "Arzt besucht", "Schlaf"
    ]

    private var begleitVorschlaege: [String] {
        SchmerzLexikon.db[koerperstelle]?.symptome ?? [
            "Übelkeit", "Schwindel", "Müdigkeit", "Schlafstörungen",
            "Appetitlosigkeit", "Stimmungsschwankungen", "Konzentrationsprobleme"
        ]
    }

    private var eingenommeneHeute: [EinnahmeLog] {
        let start = Calendar.current.startOfDay(for: datum)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        return alleEinnahmen.filter { $0.datum >= start && $0.datum < end && $0.eingenommen }
    }

    var body: some View {
        VStack(spacing: 24) {
            // Step header
            VStack(spacing: 6) {
                Image(systemName: "list.clipboard")
                    .font(.system(size: 32))
                    .foregroundStyle(.purple)
                Text("Was noch?")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
            }

            // Card 1: Begleitsymptome
            VStack(alignment: .leading, spacing: 12) {
                Text("Begleiterscheinungen (mehrere möglich)")
                    .font(.headline)
                FlowLayout(begleitVorschlaege) { vorschlag in
                    ChipButton(label: vorschlag, ausgewaehlt: begleitAusgewaehlt.contains(vorschlag)) {
                        if begleitAusgewaehlt.contains(vorschlag) { begleitAusgewaehlt.remove(vorschlag) }
                        else { begleitAusgewaehlt.insert(vorschlag) }
                        aktualisiereBegleiter()
                    }
                }
                HStack(spacing: 8) {
                    TextField("Eigene Angaben…", text: $begleitFreitext)
                        .textFieldStyle(.roundedBorder)
                    if !begleitFreitext.isEmpty {
                        Button {
                            begleitAusgewaehlt.insert(begleitFreitext.trimmingCharacters(in: .whitespaces))
                            begleitFreitext = ""
                            aktualisiereBegleiter()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.accentColor)
                                .font(.title2)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))

            // Card 2: Massnahmen
            VStack(alignment: .leading, spacing: 12) {
                Text("Massnahmen (mehrere möglich)")
                    .font(.headline)

                if !eingenommeneHeute.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "pills.fill")
                            .foregroundStyle(.purple)
                        Text(eingenommeneHeute.map { medLabel($0) }.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }

                FlowLayout(massnahmenVorschlaege) { m in
                    ChipButton(label: m, ausgewaehlt: massnahmenAusgewaehlt.contains(m)) {
                        if massnahmenAusgewaehlt.contains(m) { massnahmenAusgewaehlt.remove(m) }
                        else { massnahmenAusgewaehlt.insert(m) }
                        aktualisiereMassnahmen()
                    }
                }
                HStack(spacing: 8) {
                    TextField("Weitere Massnahme…", text: $massnahmenFreitext)
                        .textFieldStyle(.roundedBorder)
                    if !massnahmenFreitext.isEmpty {
                        Button {
                            massnahmenAusgewaehlt.insert(massnahmenFreitext.trimmingCharacters(in: .whitespaces))
                            massnahmenFreitext = ""
                            aktualisiereMassnahmen()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.accentColor)
                                .font(.title2)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal)
        .onAppear { ladeWerte() }
    }

    private func aktualisiereBegleiter() {
        var teile = begleitAusgewaehlt.sorted()
        let trimmed = begleitFreitext.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { teile.append(trimmed) }
        begleiterscheinungen = teile.joined(separator: ", ")
    }

    private func aktualisiereMassnahmen() {
        var teile = massnahmenAusgewaehlt.sorted()
        let trimmed = massnahmenFreitext.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { teile.append(trimmed) }
        massnahmen = teile.joined(separator: ", ")
    }

    private func ladeWerte() {
        let begleitTeile = begleiterscheinungen
            .components(separatedBy: ", ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        begleitAusgewaehlt = Set(begleitTeile.filter { begleitVorschlaege.contains($0) })
        let customBegleit = begleitTeile.filter { !begleitVorschlaege.contains($0) }
        begleitFreitext = customBegleit.joined(separator: ", ")

        let massnahmenTeile = massnahmen
            .components(separatedBy: ", ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        massnahmenAusgewaehlt = Set(massnahmenTeile.filter { massnahmenVorschlaege.contains($0) })
    }

    private func medLabel(_ log: EinnahmeLog) -> String {
        log.dosierung.isEmpty ? log.medikamentName : "\(log.medikamentName) \(log.dosierung)"
    }
}
