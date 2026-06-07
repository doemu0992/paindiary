import SwiftUI
import SwiftData

enum EintragTyp { case schmerz, haut }

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

    // Schmerz: steps 0–5 (6 total); Haut: steps 0–2 (3 total)
    private var gesamtSchritte: Int { eintragTyp == .haut ? 2 : 5 }

    private var progress: CGFloat {
        CGFloat(schritt) / CGFloat(gesamtSchritte)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressBar
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)

                AnimierterSchrittInhalt(schritt: schritt, vorwaerts: vorwaerts) {
                    schrittInhalt
                        .padding(.vertical, 24)
                }

                navigationsLeiste
            }
            .navigationTitle(navTitel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    DatePicker("", selection: $datum,
                               displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
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

    // MARK: - Progress bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.15))
                    .frame(height: 3)
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: max(geo.size.width * progress, 0), height: 3)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: schritt)
            }
        }
        .frame(height: 3)
    }

    // MARK: - Navigation title

    private var navTitel: String {
        guard eintrag == nil else { return "Eintrag bearbeiten" }
        switch (schritt, eintragTyp) {
        case (0, _):         return "Neuer Eintrag"
        case (1, .schmerz):  return "Intensität"
        case (2, .schmerz):  return "Charakter & Auslöser"
        case (3, .schmerz):  return "Symptome & Massnahmen"
        case (4, .schmerz):  return "Haut (optional)"
        case (5, .schmerz):  return "Wohlbefinden"
        case (1, .haut):     return "Art & Foto"
        case (2, .haut):     return "Wohlbefinden"
        default:             return ""
        }
    }

    // MARK: - Step content

    @ViewBuilder
    private var schrittInhalt: some View {
        switch schritt {
        case 0:
            OrtTypStepView(
                koerperstelle: $koerperstelle,
                eintragTyp: $eintragTyp,
                letzterEintrag: letzterEintrag,
                vorlageDismissed: vorlageDismissed,
                onVorlageTapped: { übernehmeVorlage($0) },
                onVorlageDismissed: { vorlageDismissed = true }
            )

        case 1 where eintragTyp == .haut:
            HautArtFotoStepView(hautArt: $hautArt, fotoDateiname: $fotoDateiname)

        case 2 where eintragTyp == .haut:
            WohlbefindenStepView(
                stimmung: $stimmung,
                schlafStunden: $schlafStunden,
                stressLevel: $stressLevel,
                healthSchlafVorschlag: healthSchlaf
            )

        case 1:
            IntensitaetStepView(
                schmerzstaerke: $schmerzstaerke,
                verlauf: $verlauf,
                letzterEintrag: letzterEintrag
            )

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
            HautStepView(
                hautStellen: $hautStellen,
                hautArt: $hautArt,
                fotoDateiname: $fotoDateiname
            )

        case 5:
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

            let isLast = schritt == gesamtSchritte
            let canSkip = !isLast && schritt > 0 && skipErlaubt

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
                let disabled = schritt == 0 && eintragTyp == .schmerz && koerperstelle.isEmpty
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

    private var skipErlaubt: Bool {
        switch (schritt, eintragTyp) {
        case (2, .schmerz): return true  // Charakter & Auslöser optional
        case (3, .schmerz): return true  // Symptome & Massnahmen optional
        case (4, .schmerz): return true  // Haut optional
        case (2, .haut):    return true  // Wohlbefinden optional
        default:            return false
        }
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
        datum                = e.datum
        schmerzstaerke       = e.schmerzstaerke
        schmerzart           = e.schmerzart
        dauerMinuten         = e.dauerMinuten
        ausloeser            = e.ausloeser
        begleiterscheinungen = e.begleiterscheinungen
        massnahmen           = e.massnahmen
        hautArt              = e.hautArt
        fotoDateiname        = e.fotoDateiname
        verlauf              = e.verlauf
        stimmung             = e.stimmung
        stressLevel          = e.stressLevel
        schlafStunden        = e.schlafStunden
        notizen              = e.notizen
        eintragTyp = (e.schmerzstaerke == 0 && !e.hautStellen.isEmpty) ? .haut : .schmerz
        if eintragTyp == .haut {
            koerperstelle = e.hautStellen   // skin locations shown in body map
            hautStellen   = ""
        } else {
            koerperstelle = e.koerperstelle
            hautStellen   = e.hautStellen
        }
        schritt = 1
    }

    private func speichern() {
        let wetterSnap = wetter.aktuell
        if let e = eintrag {
            e.datum                = datum
            e.koerperstelle        = eintragTyp == .haut ? "" : koerperstelle
            e.schmerzstaerke       = eintragTyp == .haut ? 0 : schmerzstaerke
            e.schmerzart           = schmerzart
            e.dauerMinuten         = dauerMinuten
            e.ausloeser            = ausloeser
            e.begleiterscheinungen = begleiterscheinungen
            e.massnahmen           = massnahmen
            e.hautStellen          = eintragTyp == .haut ? koerperstelle : hautStellen
            e.hautArt              = hautArt
            e.fotoDateiname        = fotoDateiname
            e.verlauf              = verlauf
            e.stimmung             = stimmung
            e.schlafStunden        = schlafStunden
            e.stressLevel          = stressLevel
            e.notizen              = notizen
        } else {
            let neu = PainEntry(
                datum:                datum,
                schmerzstaerke:       eintragTyp == .haut ? 0 : schmerzstaerke,
                koerperstelle:        eintragTyp == .haut ? "" : koerperstelle,
                schmerzart:           schmerzart,
                dauerMinuten:         dauerMinuten,
                ausloeser:            ausloeser,
                begleiterscheinungen: begleiterscheinungen,
                massnahmen:           massnahmen,
                notizen:              notizen,
                stimmung:             stimmung,
                schlafStunden:        schlafStunden,
                stressLevel:          stressLevel,
                wetterTemperatur:     wetterSnap?.temperatur,
                wetterCode:           wetterSnap?.code,
                wetterWind:           wetterSnap?.windgeschwindigkeit,
                hautStellen:          eintragTyp == .haut ? koerperstelle : hautStellen,
                hautArt:              hautArt,
                fotoDateiname:        fotoDateiname,
                verlauf:              verlauf
            )
            modelContext.insert(neu)
        }
        dismiss()
    }
}

// MARK: - Animated step transition wrapper

private struct AnimierterSchrittInhalt<Content: View>: View {
    let schritt: Int
    let vorwaerts: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            content()
        }
        .id(schritt)
        .transition(.asymmetric(
            insertion: .move(edge: vorwaerts ? .trailing : .leading).combined(with: .opacity),
            removal:   .move(edge: vorwaerts ? .leading  : .trailing).combined(with: .opacity)
        ))
    }
}

// MARK: - Step 0: location + type selector

private struct OrtTypStepView: View {
    @Binding var koerperstelle: String
    @Binding var eintragTyp: EintragTyp
    let letzterEintrag: PainEntry?
    let vorlageDismissed: Bool
    let onVorlageTapped: (PainEntry) -> Void
    let onVorlageDismissed: () -> Void

    @StateObject private var scanService = BodyScanService.shared
    @State private var scanSetupAnzeigen = false

    private var ausgewaehlt: Set<String> {
        Set(koerperstelle.components(separatedBy: ", ").filter { !$0.isEmpty })
    }

    var body: some View {
        VStack(spacing: 16) {
            Picker("Typ", selection: $eintragTyp) {
                Text("Schmerzen").tag(EintragTyp.schmerz)
                Text("Hautveränderung").tag(EintragTyp.haut)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            if eintragTyp == .schmerz, !vorlageDismissed, let letzter = letzterEintrag {
                VorlageBannerView(eintrag: letzter) {
                    onVorlageTapped(letzter)
                } onDismiss: {
                    onVorlageDismissed()
                }
                .padding(.horizontal)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(eintragTyp == .schmerz ? "Wo hast du Schmerzen?" : "Betroffene Hautstellen")
                        .font(.headline)
                    Spacer()
                    Button { scanSetupAnzeigen = true } label: {
                        Label(
                            scanService.hatScan ? "Neu scannen" : "Körper scannen",
                            systemImage: scanService.hatScan ? "arrow.triangle.2.circlepath" : "camera.viewfinder"
                        )
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.accentColor.opacity(0.12))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                KoerperPickerView(
                    auswahl: $koerperstelle,
                    tintColor: eintragTyp == .schmerz ? .systemRed : .systemOrange,
                    frameHeight: 380,
                    subRegionenMap: eintragTyp == .schmerz ? nil : SubRegionen.hautMap
                )

                if ausgewaehlt.isEmpty {
                    Text("Tippe auf eine Körperstelle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .frame(height: 30)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(ausgewaehlt.sorted(), id: \.self) { r in
                                Button {
                                    var s = ausgewaehlt
                                    s.remove(r)
                                    koerperstelle = s.sorted().joined(separator: ", ")
                                } label: {
                                    HStack(spacing: 3) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 9, weight: .bold))
                                        Text(r).font(.caption)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        eintragTyp == .schmerz
                                            ? Color.red.opacity(0.12)
                                            : Color.orange.opacity(0.12)
                                    )
                                    .foregroundStyle(eintragTyp == .schmerz ? .red : .orange)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 30)
                }

                Label("Drehen zum Erkunden", systemImage: "hand.draw")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }
        .sheet(isPresented: $scanSetupAnzeigen) { BodyScanSetupView() }
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
            teile.append(
                eintrag.koerperstelle.components(separatedBy: ", ").prefix(2).joined(separator: ", ")
            )
        }
        teile.append("Stärke \(eintrag.schmerzstaerke)")
        return teile.joined(separator: " · ")
    }
}
