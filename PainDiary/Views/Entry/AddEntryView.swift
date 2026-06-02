import SwiftUI
import SwiftData

struct AddEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var eintrag: PainEntry? = nil

    @State private var schritt = 0
    @State private var koerperstelle = ""
    @State private var schmerzstaerke = 5
    @State private var schmerzart = ""
    @State private var dauerMinuten = 0
    @State private var ausloeser = ""
    @State private var begleiterscheinungen = ""
    @State private var massnahmen = ""
    @State private var stimmung = 3
    @State private var schlafStunden = 7.0
    @State private var notizen = ""

    private let gesamtSchritte = 6

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProgressView(value: Double(schritt + 1), total: Double(gesamtSchritte))
                    .padding(.horizontal)
                    .padding(.top, 8)

                Text("Schritt \(schritt + 1) von \(gesamtSchritte)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                ScrollView {
                    schrittInhalt
                        .padding(.vertical, 24)
                }

                Spacer(minLength: 0)

                HStack(spacing: 16) {
                    if schritt > 0 {
                        Button("Zurück") { withAnimation { schritt -= 1 } }
                            .buttonStyle(.bordered)
                    }
                    Spacer()
                    if schritt < gesamtSchritte - 1 {
                        Button("Weiter") { withAnimation { schritt += 1 } }
                            .buttonStyle(.borderedProminent)
                            .disabled(schritt == 0 && koerperstelle.isEmpty)
                    } else {
                        Button("Speichern") { speichern() }
                            .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .background(.bar)
            }
            .navigationTitle(eintrag == nil ? "Neuer Eintrag" : "Eintrag bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
            .onAppear { ladeVorhandeneWerte() }
        }
    }

    @ViewBuilder
    private var schrittInhalt: some View {
        switch schritt {
        case 0:
            WizardAnatomieKarteView(koerperstelle: $koerperstelle)
        case 1:
            IntensitaetStepView(schmerzstaerke: $schmerzstaerke)
        case 2:
            CharakterStepView(
                schmerzart: $schmerzart,
                dauerMinuten: $dauerMinuten,
                koerperstelle: koerperstelle
            )
        case 3:
            AusloeserStepView(ausloeser: $ausloeser, koerperstelle: koerperstelle)
        case 4:
            BegleitschmerzStepView(begleiterscheinungen: $begleiterscheinungen, koerperstelle: koerperstelle)
        case 5:
            MassnahmenStepView(
                massnahmen: $massnahmen,
                stimmung: $stimmung,
                schlafStunden: $schlafStunden
            )
        default:
            EmptyView()
        }
    }

    private var schrittTitel: String {
        switch schritt {
        case 0: return "Körperstelle"
        case 1: return "Schmerzstärke"
        case 2: return "Schmerzcharakter"
        case 3: return "Auslöser"
        case 4: return "Begleiterscheinungen"
        case 5: return "Massnahmen"
        default: return eintrag == nil ? "Neuer Eintrag" : "Eintrag bearbeiten"
        }
    }

    private func ladeVorhandeneWerte() {
        guard let e = eintrag else { return }
        koerperstelle = e.koerperstelle
        schmerzstaerke = e.schmerzstaerke
        schmerzart = e.schmerzart
        dauerMinuten = e.dauerMinuten
        ausloeser = e.ausloeser
        begleiterscheinungen = e.begleiterscheinungen
        massnahmen = e.massnahmen
        stimmung = e.stimmung
        schlafStunden = e.schlafStunden
        notizen = e.notizen
    }

    private func speichern() {
        if let e = eintrag {
            e.koerperstelle = koerperstelle
            e.schmerzstaerke = schmerzstaerke
            e.schmerzart = schmerzart
            e.dauerMinuten = dauerMinuten
            e.ausloeser = ausloeser
            e.begleiterscheinungen = begleiterscheinungen
            e.massnahmen = massnahmen
            e.stimmung = stimmung
            e.schlafStunden = schlafStunden
            e.notizen = notizen
        } else {
            let neu = PainEntry(
                datum: Date(),
                schmerzstaerke: schmerzstaerke,
                koerperstelle: koerperstelle,
                schmerzart: schmerzart,
                dauerMinuten: dauerMinuten,
                ausloeser: ausloeser,
                begleiterscheinungen: begleiterscheinungen,
                massnahmen: massnahmen,
                notizen: notizen,
                stimmung: stimmung,
                schlafStunden: schlafStunden
            )
            modelContext.insert(neu)
        }
        dismiss()
    }
}
