import SwiftUI
import SwiftData

struct AddEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var eintrag: PainEntry? = nil

    @State private var schritt = 0
    @State private var vorwaerts = true
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
    private let gesamtSchritte = 8

    private let schrittNamen = [
        "Ort", "Intensität", "Charakter", "Auslöser",
        "Begleitsymptome", "Massnahmen", "Haut", "Wohlbefinden"
    ]
    // Steps 0 (Ort) and 1 (Intensität) are required; all others are skippable
    private let pflichtSchritte: Set<Int> = [0, 1]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                schrittIndikator
                    .padding(.horizontal)
                    .padding(.top, 10)

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
                    ladeSchlafVomHeutigenTag()
                    ladeLetztenEintrag()
                    Task { healthSchlaf = await health.schlafStundenLetztteNacht() }
                }
            }
        }
    }

    // MARK: - Step indicator

    private var schrittIndikator: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(0..<gesamtSchritte, id: \.self) { i in
                    ZStack {
                        if i < schritt {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 8, height: 8)
                        } else if i == schritt {
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
                            .fill(i < schritt ? Color.accentColor : Color.secondary.opacity(0.2))
                            .frame(maxWidth: .infinity, maxHeight: 1.5)
                            .animation(.easeInOut(duration: 0.3), value: schritt)
                    }
                }
            }

            HStack {
                Text("Schritt \(schritt + 1) von \(gesamtSchritte)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(schrittNamen[schritt])
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
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
        switch schritt {
        case 0:
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
        case 1:
            IntensitaetStepView(
                schmerzstaerke: $schmerzstaerke,
                verlauf: $verlauf,
                letzterEintrag: letzterEintrag
            )
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
            MassnahmenStepView(massnahmen: $massnahmen, datum: datum)
        case 6:
            HautStepView(hautStellen: $hautStellen, hautArt: $hautArt, fotoDateiname: $fotoDateiname)
        case 7:
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
                    .background(
                        (schritt == 0 && koerperstelle.isEmpty) ? Color.secondary.opacity(0.3) : Color.accentColor,
                        in: Capsule()
                    )
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(schritt == 0 && koerperstelle.isEmpty)
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

    // MARK: - Data

    private func ladeLetztenEintrag() {
        var descriptor = FetchDescriptor<PainEntry>(
            sortBy: [SortDescriptor(\.datum, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        letzterEintrag = try? modelContext.fetch(descriptor).first
    }

    private func übernehmeVorlage(_ e: PainEntry) {
        koerperstelle    = e.koerperstelle
        schmerzstaerke   = e.schmerzstaerke
        schmerzart       = e.schmerzart
        dauerMinuten     = e.dauerMinuten
        ausloeser        = e.ausloeser
        begleiterscheinungen = e.begleiterscheinungen
        massnahmen       = e.massnahmen
        hautStellen      = e.hautStellen
        hautArt          = e.hautArt
        vorlageDismissed = true
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
                schmerzstaerke: schmerzstaerke,
                koerperstelle: koerperstelle,
                schmerzart: schmerzart,
                dauerMinuten: dauerMinuten,
                ausloeser: ausloeser,
                begleiterscheinungen: begleiterscheinungen,
                massnahmen: massnahmen,
                notizen: notizen,
                stimmung: stimmung,
                hautStellen: hautStellen,
                hautArt: hautArt,
                fotoDateiname: fotoDateiname,
                verlauf: verlauf,
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
