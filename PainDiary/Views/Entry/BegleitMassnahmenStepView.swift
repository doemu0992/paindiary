import SwiftUI
import SwiftData

struct BegleitMassnahmenStepView: View {
    @Binding var begleiterscheinungen: String
    @Binding var massnahmen: String
    let koerperstelle: String
    var datum: Date = .now

    @Query private var alleEinnahmen: [EinnahmeLog]

    @State private var begleitAusgewaehlt: Set<String> = []
    @State private var begleitFreitext = ""
    @State private var massnahmenAusgewaehlt: Set<String> = []
    @State private var massnahmenFreitext = ""

    private var begleitVorschlaege: [String] {
        SchmerzLexikon.db[koerperstelle]?.symptome ?? [
            "Übelkeit", "Schwindel", "Müdigkeit", "Schlafstörungen",
            "Appetitlosigkeit", "Stimmungsschwankungen", "Konzentrationsprobleme"
        ]
    }

    private let massnahmenVorschlaege = [
        "Schmerzmittel", "Wärme", "Kälte", "Ruhe", "Massage",
        "Dehnung", "Sport", "Meditation", "Arzt besucht", "Schlaf"
    ]

    private var eingenommeneHeute: [EinnahmeLog] {
        let cal = Calendar.current
        return alleEinnahmen.filter {
            $0.eingenommen && cal.isDate($0.datum, inSameDayAs: datum)
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            stepHeader

            VStack(alignment: .leading, spacing: 12) {
                Text("Begleiterscheinungen")
                    .font(.headline)
                FlowLayout(begleitVorschlaege) { v in
                    ChipButton(label: v, ausgewaehlt: begleitAusgewaehlt.contains(v)) {
                        if begleitAusgewaehlt.contains(v) { begleitAusgewaehlt.remove(v) }
                        else { begleitAusgewaehlt.insert(v) }
                        aktualisiereBegleit()
                    }
                }
                HStack(spacing: 8) {
                    TextField("Eigene Angaben…", text: $begleitFreitext)
                        .textFieldStyle(.roundedBorder)
                    if !begleitFreitext.isEmpty {
                        Button {
                            begleitAusgewaehlt.insert(begleitFreitext.trimmingCharacters(in: .whitespaces))
                            begleitFreitext = ""
                            aktualisiereBegleit()
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
                Text("Massnahmen")
                    .font(.headline)
                if !eingenommeneHeute.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Heute eingenommen:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(eingenommeneHeute.map { medLabel($0) }.joined(separator: ", "))
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
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
            Image(systemName: "list.clipboard")
                .font(.system(size: 38))
                .foregroundStyle(.purple)
                .padding(14)
                .background(Color.purple.opacity(0.1), in: Circle())
            Text("Was noch?")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private func medLabel(_ log: EinnahmeLog) -> String {
        log.dosierung.isEmpty ? log.medikamentName : "\(log.medikamentName) \(log.dosierung)"
    }

    private func aktualisiereBegleit() {
        begleiterscheinungen = begleitAusgewaehlt.sorted().joined(separator: ", ")
    }

    private func aktualisiereMassnahmen() {
        massnahmen = massnahmenAusgewaehlt.sorted().joined(separator: ", ")
    }

    private func ladeBindings() {
        let begleitTeile = begleiterscheinungen.components(separatedBy: ", ").filter { !$0.isEmpty }
        begleitAusgewaehlt = Set(begleitTeile.filter { begleitVorschlaege.contains($0) })
        let custom = begleitTeile.filter { !begleitVorschlaege.contains($0) }
        begleitFreitext = custom.joined(separator: ", ")
        massnahmenAusgewaehlt = Set(massnahmen.components(separatedBy: ", ").filter { !$0.isEmpty })
    }
}
