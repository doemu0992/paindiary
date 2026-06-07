import SwiftUI
import SwiftData

// MARK: - Entry type

enum EintragTyp {
    case schmerz, haut
}

// MARK: - AddEntryView

struct AddEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var eintrag: PainEntry? = nil

    @State private var schritt = 0
    @State private var vorwaerts = true
    @State private var datum = Date()

    // Shared / location
    @State private var eintragTyp: EintragTyp = .schmerz
    @State private var koerperstelle = ""

    // Schmerz
    @State private var schmerzstaerke = 5
    @State private var schmerzart = ""
    @State private var dauerMinuten = 0
    @State private var ausloeser = ""
    @State private var begleiterscheinungen = ""
    @State private var massnahmen = ""
    @State private var notizen = ""

    // Haut
    @State private var hautStellen = ""
    @State private var hautArt = ""
    @State private var fotoDateiname = ""
    @State private var verlauf = ""

    // Wohlbefinden (shared)
    @State private var stimmung = 3
    @State private var stressLevel = 3
    @State private var schlafStunden = 7.0
    @State private var healthSchlaf: Double? = nil

    // Vorlage
    @State private var vorlageDismissed = false
    @Query(sort: \PainEntry.datum, order: .reverse) private var alleEintraege: [PainEntry]

    private let wetter = WetterService.shared
    private let health = HealthKitManager.shared

    private var letzterEintrag: PainEntry? { alleEintraege.first }

    private var gesamtSchritte: Int {
        switch eintragTyp {
        case .schmerz: return 5  // steps 0-4
        case .haut:    return 3  // steps 0-2
        }
    }

    private var schrittNamen: [String] {
        switch eintragTyp {
        case .schmerz:
            return ["Ort & Typ", "Intensität", "Wie & Warum", "Was noch", "Wohlbefinden"]
        case .haut:
            return ["Ort & Typ", "Hautbild", "Wohlbefinden"]
        }
    }

    // Steps 0 and 1 are required for schmerz; step 0 for haut (step 1 is skippable for haut)
    private var pflichtSchritte: Set<Int> {
        switch eintragTyp {
        case .schmerz: return [0, 1]
        case .haut:    return [0]
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress bar
                progressBar
                    .padding(.horizontal)
                    .padding(.top, 10)

                // Date + weather
                HStack {
                    DatePicker("", selection: $datum, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .font(.caption)
                    Spacer()
                    wetterBadge
                }
                .padding(.horizontal)
                .padding(.top, 8)

                ScrollView {
                    schrittInhalt
                        .padding(.vertical, 24)
                }
                .id(schritt)
                .transition(.asymmetric(
                    insertion: .move(edge: vorwaerts ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: vorwaerts ? .leading : .trailing).combined(with: .opacity)
                ))

                navigationsLeiste
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

    // MARK: - Progress bar

    private var progressBar: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 3)
                    Capsule()
                        .fill(progressTint)
                        .frame(width: geo.size.width * CGFloat(schritt) / CGFloat(gesamtSchritte - 1), height: 3)
                        .animation(.spring(response: 0.4), value: schritt)
                }
            }
            .frame(height: 3)

            HStack {
                Text("Schritt \(schritt + 1) von \(gesamtSchritte)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(schritt < schrittNamen.count ? schrittNamen[schritt] : "")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var progressTint: Color {
        switch eintragTyp {
        case .schmerz: return .accentColor
        case .haut:    return .orange
        }
    }

    // MARK: - Weather badge

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

    // MARK: - Step content

    @ViewBuilder
    private var schrittInhalt: some View {
        switch eintragTyp {
        case .schmerz:
            switch schritt {
            case 0:
                OrtTypStepView(
                    koerperstelle: $koerperstelle,
                    eintragTyp: $eintragTyp,
                    letzterEintrag: letzterEintrag,
                    vorlageDismissed: vorlageDismissed,
                    onVorlageTapped: { wendeVorlageAn() },
                    onVorlageDismissed: { vorlageDismissed = true }
                )
            case 1:
                IntensitaetStepView(schmerzstaerke: $schmerzstaerke)
            case 2:
                CharakterAusloeserStepView(
                    schmerzart: $schmerzart,
                    dauerMinuten: $dauerMinuten,
                    ausloeser: $ausloeser,
                    koerperstelle: koerperstelle
                )
            case 3:
                BegleitMassnahmenStepView(
                    begleiterscheinungen: $begleiterscheinungen,
                    massnahmen: $massnahmen,
                    koerperstelle: koerperstelle,
                    datum: datum
                )
            case 4:
                WohlbefindenStepView(
                    stimmung: $stimmung,
                    schlafStunden: $schlafStunden,
                    stressLevel: $stressLevel,
                    healthSchlafVorschlag: healthSchlaf
                )
            default:
                EmptyView()
            }
        case .haut:
            switch schritt {
            case 0:
                OrtTypStepView(
                    koerperstelle: $koerperstelle,
                    eintragTyp: $eintragTyp,
                    letzterEintrag: letzterEintrag,
                    vorlageDismissed: vorlageDismissed,
                    onVorlageTapped: { wendeVorlageAn() },
                    onVorlageDismissed: { vorlageDismissed = true }
                )
            case 1:
                HautArtFotoStepView(hautArt: $hautArt, fotoDateiname: $fotoDateiname)
            case 2:
                WohlbefindenStepView(
                    stimmung: $stimmung,
                    schlafStunden: $schlafStunden,
                    stressLevel: $stressLevel,
                    healthSchlafVorschlag: healthSchlaf
                )
            default:
                EmptyView()
            }
        }
    }

    // MARK: - Navigation bar

    private var navigationsLeiste: some View {
        HStack(spacing: 12) {
            // Back button
            if schritt > 0 {
                Button {
                    vorwaerts = false
                    withAnimation(.easeInOut(duration: 0.25)) { schritt -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 46, height: 46)
                        .background(.regularMaterial, in: Circle())
                }
                .buttonStyle(.plain)
            } else {
                Spacer().frame(width: 46)
            }

            Spacer()

            // Skip button for optional steps (not last step)
            if !pflichtSchritte.contains(schritt) && schritt < gesamtSchritte - 1 {
                Button {
                    vorwaerts = true
                    withAnimation(.easeInOut(duration: 0.25)) { schritt += 1 }
                } label: {
                    Text("Überspringen")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Forward / Save
            if schritt < gesamtSchritte - 1 {
                Button {
                    vorwaerts = true
                    withAnimation(.easeInOut(duration: 0.25)) { schritt += 1 }
                } label: {
                    HStack(spacing: 6) {
                        Text("Weiter")
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline.bold())
                    .padding(.horizontal, 22)
                    .padding(.vertical, 13)
                    .background(weiterDeaktiviert ? Color.secondary.opacity(0.3) : progressTint,
                                in: Capsule())
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(weiterDeaktiviert)
            } else {
                Button {
                    speichern()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                        Text("Speichern")
                    }
                    .font(.subheadline.bold())
                    .padding(.horizontal, 22)
                    .padding(.vertical, 13)
                    .background(Color.green, in: Capsule())
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private var weiterDeaktiviert: Bool {
        // Step 0 schmerz: requires koerperstelle; step 0 haut: no requirement
        if schritt == 0 && eintragTyp == .schmerz { return koerperstelle.isEmpty }
        return false
    }

    // MARK: - Data

    private func wendeVorlageAn() {
        guard let e = letzterEintrag else { return }
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
        vorlageDismissed = true
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
        hautArt = e.hautArt
        fotoDateiname = e.fotoDateiname
        verlauf = e.verlauf

        // Detect haut entries: schmerzstaerke == 0 and hautStellen not empty
        if e.schmerzstaerke == 0 && !e.hautStellen.isEmpty {
            eintragTyp = .haut
            koerperstelle = e.hautStellen
            schritt = 1
        }
    }

    private func speichern() {
        let wetterSnap = wetter.aktuell
        if let e = eintrag {
            // Editing existing entry
            switch eintragTyp {
            case .schmerz:
                e.koerperstelle = koerperstelle
                e.hautStellen = ""
                e.schmerzstaerke = schmerzstaerke
            case .haut:
                e.koerperstelle = koerperstelle
                e.hautStellen = koerperstelle
                e.schmerzstaerke = 0
            }
            e.schmerzart = schmerzart
            e.dauerMinuten = dauerMinuten
            e.ausloeser = ausloeser
            e.begleiterscheinungen = begleiterscheinungen
            e.massnahmen = massnahmen
            e.stimmung = stimmung
            e.schlafStunden = schlafStunden
            e.stressLevel = stressLevel
            e.notizen = notizen
            e.hautArt = hautArt
            e.fotoDateiname = fotoDateiname
            e.verlauf = verlauf
        } else {
            // New entry
            let (koerperstelleWert, hautStellenWert, schmerzstaerkeWert): (String, String, Int)
            switch eintragTyp {
            case .schmerz:
                koerperstelleWert = koerperstelle
                hautStellenWert = ""
                schmerzstaerkeWert = schmerzstaerke
            case .haut:
                koerperstelleWert = koerperstelle
                hautStellenWert = koerperstelle
                schmerzstaerkeWert = 0
            }

            let neu = PainEntry(
                datum: datum,
                schmerzstaerke: schmerzstaerkeWert,
                koerperstelle: koerperstelleWert,
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
                wetterWind: wetterSnap?.windgeschwindigkeit,
                hautStellen: hautStellenWert,
                hautArt: hautArt,
                fotoDateiname: fotoDateiname,
                verlauf: verlauf
            )
            modelContext.insert(neu)
        }
        dismiss()
    }
}

// MARK: - OrtTypStepView

private struct OrtTypStepView: View {
    @Binding var koerperstelle: String
    @Binding var eintragTyp: EintragTyp
    let letzterEintrag: PainEntry?
    let vorlageDismissed: Bool
    let onVorlageTapped: () -> Void
    let onVorlageDismissed: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Type selector
            Picker("Eintragstyp", selection: $eintragTyp) {
                Text("Schmerzen").tag(EintragTyp.schmerz)
                Text("Haut").tag(EintragTyp.haut)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            // Vorlage banner (only for schmerz)
            if eintragTyp == .schmerz && !vorlageDismissed, let letzter = letzterEintrag {
                VorlageBannerView(
                    eintrag: letzter,
                    onUebernehmen: onVorlageTapped,
                    onDismiss: onVorlageDismissed
                )
                .padding(.horizontal)
            }

            // Body map
            WizardAnatomieKarteView(
                koerperstelle: $koerperstelle,
                tintColor: eintragTyp == .schmerz ? .red : .orange,
                subRegionenMap: eintragTyp == .schmerz ? nil : SubRegionen.hautMap,
                titel: eintragTyp == .schmerz ? "Wo hast du Schmerzen?" : "Betroffene Hautstellen"
            )
        }
    }
}

// MARK: - VorlageBannerView

private struct VorlageBannerView: View {
    let eintrag: PainEntry
    let onUebernehmen: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.accentColor)
                Text("Letzter Eintrag übernehmen?")
                    .font(.subheadline.bold())
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if !eintrag.koerperstelle.isEmpty {
                Text(eintrag.koerperstelle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Button(action: onUebernehmen) {
                Text("Übernehmen")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
