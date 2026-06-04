import SwiftUI
import SwiftData

struct AddEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var eintrag: PainEntry? = nil

    @State private var schritt = 0
    @State private var datum = Date()
    @State private var koerperstelle = ""
    @State private var schmerzstaerke = 5
    @State private var schmerzart = ""
    @State private var dauerMinuten = 0
    @State private var ausloeser = ""
    @State private var begleiterscheinungen = ""
    @State private var massnahmen = ""
    @State private var stimmung = 3
    @State private var stressLevel = 3
    @State private var schlafStunden = 7.0
    @State private var notizen = ""
    @State private var healthSchlaf: Double? = nil

    private let wetter = WetterService.shared
    private let health = HealthKitManager.shared
    private let gesamtSchritte = 6

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProgressView(value: Double(schritt + 1), total: Double(gesamtSchritte))
                    .padding(.horizontal)
                    .padding(.top, 8)

                HStack {
                    DatePicker("", selection: $datum, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .font(.caption)
                    Spacer()
                    wetterBadge
                }
                .padding(.horizontal)
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
            .onAppear {
                ladeVorhandeneWerte()
                if eintrag == nil {
                    wetter.laden()
                    Task { healthSchlaf = await health.schlafStundenLetztteNacht() }
                }
            }
        }
    }

    @ViewBuilder
    private var wetterBadge: some View {
        if wetter.isLoading {
            ProgressView().scaleEffect(0.7)
        } else if let w = wetter.aktuell {
            HStack(spacing: 4) {
                Image(systemName: w.symbol)
                    .foregroundStyle(.yellow)
                Text(String(format: "%.0f°C", w.temperatur))
                    .font(.caption.bold())
                if !w.luftdruckText.isEmpty {
                    Text(w.luftdruckText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.regularMaterial, in: Capsule())
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
                schlafStunden: $schlafStunden,
                stressLevel: $stressLevel,
                healthSchlafVorschlag: healthSchlaf
            )
        default:
            EmptyView()
        }
    }

    private func ladeVorhandeneWerte() {
        guard let e = eintrag else { return }
        datum = e.datum
        koerperstelle = e.koerperstelle
        schmerzstaerke = e.schmerzstaerke
        schmerzart = e.schmerzart
        dauerMinuten = e.dauerMinuten
        ausloeser = e.ausloeser
        begleiterscheinungen = e.begleiterscheinungen
        massnahmen = e.massnahmen
        stimmung = e.stimmung
        stressLevel = e.stressLevel
        schlafStunden = e.schlafStunden
        notizen = e.notizen
    }

    private func speichern() {
        let wetterSnap = wetter.aktuell
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
            e.stressLevel = stressLevel
            e.notizen = notizen
        } else {
            let neu = PainEntry(
                datum: datum,
                schmerzstaerke: schmerzstaerke,
                koerperstelle: koerperstelle,
                schmerzart: schmerzart,
                dauerMinuten: dauerMinuten,
                ausloeser: ausloeser,
                begleiterscheinungen: begleiterscheinungen,
                massnahmen: massnahmen,
                notizen: notizen,
                stimmung: stimmung,
                schlafStunden: schlafStunden,
                stressLevel: stressLevel,
                wetterTemperatur: wetterSnap?.temperatur,
                wetterCode: wetterSnap?.code,
                wetterWind: wetterSnap?.windgeschwindigkeit
            )
            modelContext.insert(neu)
        }
        dismiss()
    }
}
