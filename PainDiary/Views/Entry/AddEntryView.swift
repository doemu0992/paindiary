import SwiftUI
import SwiftData

private enum EintragTyp { case schmerz, haut }

struct AddEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var eintrag: PainEntry? = nil

    @State private var schritt = 0
    @State private var vorwaerts = true
    @State private var eintragTyp: EintragTyp = .schmerz
    @State private var datum = Date()
    @State private var koerperstelle = ""
    @State private var schmerzstaerke = 5
    @State private var schmerzart = ""
    @State private var dauerMinuten = 0
    @State private var ausloeser = ""
    @State private var begleiterscheinungen = ""
    @State private var massnahmen = ""
    @State private var hautStellen = ""
    @State private var hautArt = ""
    @State private var fotoDateiname = ""
    @State private var verlauf = ""
    @State private var letzterEintrag: PainEntry? = nil
    @State private var vorlageDismissed = false
    @State private var stimmung = 3
    @State private var stressLevel = 3
    @State private var schlafStunden = 7.0
    @State private var notizen = ""
    @State private var healthSchlaf: Double? = nil

    private let wetter = WetterService.shared
    private let health = HealthKitManager.shared

    // Step 0 = type selector (no dots); steps 1…N = content.
    // Schmerz: 8 content steps; Haut: 1 content step.
    private var gesamtSchritte: Int { eintragTyp == .haut ? 1 : 8 }

    private let schrittNamenSchmerz = [
        "Ort", "Intensität", "Charakter", "Auslöser",
        "Begleitsymptome", "Massnahmen", "Haut", "Wohlbefinden"
    ]
    // Schmerz steps that cannot be skipped (new indices: 1=Ort, 2=Intensität)
    private let pflichtSchritte: Set<Int> = [1, 2]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if schritt > 0 {
                    schrittIndikator
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                }

                ScrollView {
                    schrittInhalt
                        .padding(.vertical, 24)
                }
                .id(schritt)
                .transition(.asymmetric(
                    insertion: .move(edge: vorwaerts ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: vorwaerts ? .leading : .trailing).combined(with: .opacity)
                ))

                if schritt > 0 {
                    navigationsLeiste
                }
            }
            .navigationTitle(navTitel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                if schritt > 0 {
                    ToolbarItem(placement: .topBarTrailing) {
                        DatePicker("", selection: $datum,
                                   displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                    }
                }
            }
            .onAppear {
                ladeVorhandeneWerte()
                if eintrag == nil {
                    wetter.laden()
                    ladeSchlafVomHeutigenTag()
                    ladeLetztenEintrag()
                    Task { healthSchlaf = await health.schlafStundenLetztteNacht() }
                }
            }
        }
    }

    private var navTitel: String {
        guard eintrag == nil else { return "Eintrag bearbeiten" }
        if schritt == 0 { return "Neuer Eintrag" }
        if eintragTyp == .haut { return "Hautveränderung" }
        let idx = schritt - 1
        return idx < schrittNamenSchmerz.count ? schrittNamenSchmerz[idx] : ""
    }

    // MARK: - Step indicator (dots only, no text row)

    private var schrittIndikator: some View {
        HStack(spacing: 0) {
            ForEach(0..<gesamtSchritte, id: \.self) { i in
                let dotStep = i + 1
                ZStack {
                    if dotStep < schritt {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 8, height: 8)
                    } else if dotStep == schritt {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 14, height: 14)
                            .shadow(color: Color.accentColor.opacity(0.5), radius: 4)
                    } else {
                        Circle()
                            .fill(Color.secondary.opacity(0.25))
                            .frame(width: 8, height: 8)
                    }
                }
                .frame(width: 14, height: 14)
                .animation(.spring(response: 0.3), value: schritt)

                if i < gesamtSchritte - 1 {
                    Rectangle()
                        .fill(dotStep < schritt ? Color.accentColor : Color.secondary.opacity(0.2))
                        .frame(maxWidth: .infinity, maxHeight: 1.5)
                        .animation(.easeInOut(duration: 0.3), value: schritt)
                }
            }
        }
    }

    // MARK: - Step content

    @ViewBuilder
    private var schrittInhalt: some View {
        switch schritt {
        case 0:
            EintragTypStepView { typ in
                eintragTyp = typ
                vorwaerts = true
                withAnimation(.easeInOut(duration: 0.25)) { schritt = 1 }
            }

        case 1 where eintragTyp == .haut:
            HautStepView(
                hautStellen: $hautStellen,
                hautArt: $hautArt,
                fotoDateiname: $fotoDateiname
            )

        case 1:
            VStack(spacing: 0) {
                if !vorlageDismissed, let letzter = letzterEintrag {
                    VorlageBannerView(eintrag: letzter) {
                        übernehmeVorlage(letzter)
                    } onDismiss: {
                        vorlageDismissed = true
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                WizardAnatomieKarteView(koerperstelle: $koerperstelle)
            }

        case 2:
            IntensitaetStepView(
                schmerzstaerke: $schmerzstaerke,
                verlauf: $verlauf,
                letzterEintrag: letzterEintrag
            )
        case 3:
            CharakterStepView(
                schmerzart: $schmerzart,
                dauerMinuten: $dauerMinuten,
                koerperstelle: koerperstelle
            )
        case 4:
            AusloeserStepView(ausloeser: $ausloeser, koerperstelle: koerperstelle)
        case 5:
            BegleitschmerzStepView(
                begleiterscheinungen: $begleiterscheinungen,
                koerperstelle: koerperstelle
            )
        case 6:
            MassnahmenStepView(massnahmen: $massnahmen, datum: datum)
        case 7:
            HautStepView(
                hautStellen: $hautStellen,
                hautArt: $hautArt,
                fotoDateiname: $fotoDateiname
            )
        case 8:
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

    // MARK: - Navigation bar

    private var navigationsLeiste: some View {
        HStack(spacing: 12) {
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

            Spacer()

            let isLast = schritt == gesamtSchritte
            let canSkip = eintragTyp == .schmerz
                && !pflichtSchritte.contains(schritt)
                && !isLast

            if canSkip {
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

            if isLast {
                Button { speichern() } label: {
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
            } else {
                let disabled = schritt == 1 && eintragTyp == .schmerz && koerperstelle.isEmpty
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
                    .background(disabled ? Color.secondary.opacity(0.3) : Color.accentColor,
                                in: Capsule())
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(disabled)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }

    // MARK: - Data

    private func ladeLetztenEintrag() {
        var descriptor = FetchDescriptor<PainEntry>(
            sortBy: [SortDescriptor(\.datum, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        letzterEintrag = try? modelContext.fetch(descriptor).first
    }

    private func übernehmeVorlage(_ e: PainEntry) {
        koerperstelle        = e.koerperstelle
        schmerzstaerke       = e.schmerzstaerke
        schmerzart           = e.schmerzart
        dauerMinuten         = e.dauerMinuten
        ausloeser            = e.ausloeser
        begleiterscheinungen = e.begleiterscheinungen
        massnahmen           = e.massnahmen
        hautStellen          = e.hautStellen
        hautArt              = e.hautArt
        vorlageDismissed     = true
    }

    private func ladeSchlafVomHeutigenTag() {
        let cal = Calendar.current
        let heute = cal.startOfDay(for: Date())
        let morgen = cal.date(byAdding: .day, value: 1, to: heute)!
        let descriptor = FetchDescriptor<PainEntry>(
            predicate: #Predicate { $0.datum >= heute && $0.datum < morgen && $0.schlafStunden > 0 },
            sortBy: [SortDescriptor(\.datum)]
        )
        if let eintraege = try? modelContext.fetch(descriptor), let erster = eintraege.first {
            schlafStunden = erster.schlafStunden
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
        hautStellen = e.hautStellen
        hautArt = e.hautArt
        fotoDateiname = e.fotoDateiname
        verlauf = e.verlauf
        stimmung = e.stimmung
        stressLevel = e.stressLevel
        schlafStunden = e.schlafStunden
        notizen = e.notizen
        eintragTyp = (e.schmerzstaerke == 0 && !e.hautStellen.isEmpty) ? .haut : .schmerz
        schritt = 1
    }

    private func speichern() {
        let wetterSnap = wetter.aktuell
        if let e = eintrag {
            e.datum = datum
            e.koerperstelle = koerperstelle
            e.schmerzstaerke = schmerzstaerke
            e.schmerzart = schmerzart
            e.dauerMinuten = dauerMinuten
            e.ausloeser = ausloeser
            e.begleiterscheinungen = begleiterscheinungen
            e.massnahmen = massnahmen
            e.hautStellen = hautStellen
            e.hautArt = hautArt
            e.fotoDateiname = fotoDateiname
            e.verlauf = verlauf
            e.stimmung = stimmung
            e.schlafStunden = schlafStunden
            e.stressLevel = stressLevel
            e.notizen = notizen
        } else {
            let neu = PainEntry(
                datum: datum,
                schmerzstaerke: eintragTyp == .haut ? 0 : schmerzstaerke,
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
                wetterWind: wetterSnap?.windgeschwindigkeit,
                hautStellen: hautStellen,
                hautArt: hautArt,
                fotoDateiname: fotoDateiname,
                verlauf: verlauf
            )
            modelContext.insert(neu)
        }
        dismiss()
    }
}

// MARK: - Type selector step

private struct EintragTypStepView: View {
    let onAuswahl: (EintragTyp) -> Void

    var body: some View {
        VStack(spacing: 28) {
            Text("Was möchtest du erfassen?")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            VStack(spacing: 14) {
                TypKarteView(
                    symbol: "waveform.path.ecg",
                    farbe: .accentColor,
                    titel: "Schmerzen erfassen",
                    beschreibung: "Intensität, Auslöser, Massnahmen & mehr",
                    action: { onAuswahl(.schmerz) }
                )
                TypKarteView(
                    symbol: "bandage",
                    farbe: .orange,
                    titel: "Hautveränderung",
                    beschreibung: "Ausschlag, Rötung, Foto & betroffener Bereich",
                    action: { onAuswahl(.haut) }
                )
            }
        }
        .padding(.horizontal)
    }
}

private struct TypKarteView: View {
    let symbol: String
    let farbe: Color
    let titel: String
    let beschreibung: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(farbe.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: symbol)
                        .font(.title2)
                        .foregroundStyle(farbe)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(titel)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(beschreibung)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
            .padding(18)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Vorlage banner

private struct VorlageBannerView: View {
    let eintrag: PainEntry
    let onUebernehmen: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 1) {
                Text("Wie zuletzt?")
                    .font(.caption.bold())
                Text(zusammenfassung)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button("Übernehmen", action: onUebernehmen)
                .font(.caption.bold())
                .foregroundStyle(Color.accentColor)

            Button { onDismiss() } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.accentColor.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
    }

    private var zusammenfassung: String {
        var teile: [String] = []
        if !eintrag.koerperstelle.isEmpty {
            teile.append(eintrag.koerperstelle.components(separatedBy: ", ").prefix(2).joined(separator: ", "))
        }
        teile.append("Stärke \(eintrag.schmerzstaerke)")
        return teile.joined(separator: " · ")
    }
}
