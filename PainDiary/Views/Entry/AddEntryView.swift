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
    @State private var morgensteifigkeit = 0
    @State private var fatigue = 0
    @State private var healthSchlaf: Double? = nil

    // Rheuma
    @State private var istSchub = false
    @State private var gelenkErfassenAktiv = false
    @State private var gelenkStatus = ""

    // Vorlage
    @State private var vorlageAngewendet = false
    @State private var zeigeErfolg = false
    @Query(sort: \PainEntry.datum, order: .reverse) private var alleEintraege: [PainEntry]

    private let wetter = WetterService.shared
    private let health = HealthKitManager.shared

    private var letzterEintrag: PainEntry? { alleEintraege.first }

    private var gesamtSchritte: Int {
        switch eintragTyp {
        case .schmerz: return gelenkErfassenAktiv ? 6 : 5
        case .haut:    return 3
        }
    }

    private var schrittNamen: [String] {
        switch eintragTyp {
        case .schmerz:
            return gelenkErfassenAktiv
                ? ["Ort & Typ", "Intensität", "Gelenke", "Wie & Warum", "Was noch", "Wohlbefinden"]
                : ["Ort & Typ", "Intensität", "Wie & Warum", "Was noch", "Wohlbefinden"]
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
                    if schritt == 0, !vorlageAngewendet, let letzter = letzterEintrag,
                       !letzter.koerperstelle.isEmpty {
                        Button { wendeVorlageAn(letzter) } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.counterclockwise")
                                Text(letzter.koerperstelle)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.accentColor.opacity(0.12))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: 160)
                        .transition(.opacity.combined(with: .scale))
                    }
                    wetterBadge
                }
                .padding(.horizontal)
                .padding(.top, 8)

                Group {
                    if schritt == 0 {
                        schrittInhalt
                            .frame(maxHeight: .infinity)
                            .padding(.vertical, 8)
                    } else {
                        ScrollView {
                            schrittInhalt
                                .padding(.vertical, 24)
                        }
                        .scrollDismissesKeyboard(.interactively)
                    }
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
                    ladeTagesSchlaf()
                    wetter.laden()
                    Task { healthSchlaf = await health.schlafStundenLetztteNacht() }
                }
            }
        }
        .overlay {
            if zeigeErfolg {
                ZStack {
                    Color.black.opacity(0.25).ignoresSafeArea()
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 72, height: 72)
                                .shadow(color: .green.opacity(0.4), radius: 16, y: 4)
                            Image(systemName: "checkmark")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .scaleEffect(zeigeErfolg ? 1 : 0.3)
                        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: zeigeErfolg)
                        Text("Gespeichert")
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                            .opacity(zeigeErfolg ? 1 : 0)
                            .animation(.easeIn.delay(0.1), value: zeigeErfolg)
                    }
                }
                .transition(.opacity)
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
            .background(Color(.secondarySystemBackground), in: Capsule())
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
                    eintragTyp: $eintragTyp
                )
            case 1:
                IntensitaetStepView(
                    schmerzstaerke: $schmerzstaerke,
                    verlauf: $verlauf,
                    istSchub: $istSchub,
                    gelenkErfassenAktiv: $gelenkErfassenAktiv,
                    letzterEintrag: letzterEintrag
                )
            case 2 where gelenkErfassenAktiv:
                GelenkStepView(gelenkStatus: $gelenkStatus)
            default:
                schmerzFolgeSchritt
            }
        case .haut:
            switch schritt {
            case 0:
                OrtTypStepView(
                    koerperstelle: $koerperstelle,
                    eintragTyp: $eintragTyp
                )
            case 1:
                HautArtFotoStepView(hautArt: $hautArt, fotoDateiname: $fotoDateiname)
            case 2:
                WohlbefindenStepView(
                    stimmung: $stimmung,
                    schlafStunden: $schlafStunden,
                    stressLevel: $stressLevel,
                    notizen: $notizen,
                    healthSchlafVorschlag: healthSchlaf
                )
            default:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private var schmerzFolgeSchritt: some View {
        let s = gelenkErfassenAktiv ? schritt - 1 : schritt
        switch s {
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
                notizen: $notizen,
                morgensteifigkeit: $morgensteifigkeit,
                fatigue: $fatigue,
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
                        .background(Color(.secondarySystemBackground), in: Circle())
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

    private func wendeVorlageAn(_ e: PainEntry) {
        withAnimation(.spring(response: 0.25)) {
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
            vorlageAngewendet = true
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
        morgensteifigkeit = e.morgensteifigkeit
        istSchub = e.istSchub
        fatigue = e.fatigue
        gelenkStatus = e.gelenkStatus
        gelenkErfassenAktiv = !e.gelenkStatus.isEmpty
        notizen = e.notizen
        hautArt = e.hautArt
        fotoDateiname = e.fotoDateiname
        verlauf = e.verlauf

        if e.istHautEintrag || (e.schmerzstaerke == 0 && !e.hautStellen.isEmpty) {
            eintragTyp = .haut
            koerperstelle = e.hautStellen
            schritt = 1
        }
    }

    private func ladeTagesSchlaf() {
        let heute = Calendar.current.startOfDay(for: Date())
        guard let morgen = Calendar.current.date(byAdding: .day, value: 1, to: heute) else { return }
        if let heutigerEintrag = alleEintraege.first(where: { $0.datum >= heute && $0.datum < morgen }),
           heutigerEintrag.schlafStunden > 0 {
            schlafStunden = heutigerEintrag.schlafStunden
        }
    }

    private func speichern() {
        let wetterSnap = wetter.aktuell
        if let e = eintrag {
            // Editing existing entry
            e.datum = datum
            e.istHautEintrag = (eintragTyp == .haut)
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
            e.morgensteifigkeit = morgensteifigkeit
            e.istSchub = istSchub
            e.fatigue = fatigue
            e.gelenkStatus = gelenkStatus
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
                morgensteifigkeit: morgensteifigkeit,
                istSchub: istSchub,
                fatigue: fatigue,
                gelenkStatus: gelenkStatus,
                wetterTemperatur: wetterSnap?.temperatur,
                wetterCode: wetterSnap?.code,
                wetterWind: wetterSnap?.windgeschwindigkeit,
                hautStellen: hautStellenWert,
                hautArt: hautArt,
                fotoDateiname: fotoDateiname,
                verlauf: verlauf
            )
            neu.istHautEintrag = (eintragTyp == .haut)
            modelContext.insert(neu)
        }
#if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
#endif
        zeigeErfolg = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { dismiss() }
    }
}

// MARK: - OrtTypStepView

private struct OrtTypStepView: View {
    @Binding var koerperstelle: String
    @Binding var eintragTyp: EintragTyp

    @StateObject private var scanService = BodyScanService.shared
    @State private var scanSetupAnzeigen = false

    private var ausgewaehlt: Set<String> {
        Set(koerperstelle.components(separatedBy: ", ").filter { !$0.isEmpty })
    }

    var body: some View {
        VStack(spacing: 12) {
            // Type selector
            Picker("Typ", selection: $eintragTyp) {
                Text("Schmerzen").tag(EintragTyp.schmerz)
                Text("Hautveränderung").tag(EintragTyp.haut)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            // Body map card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(eintragTyp == .schmerz ? "Wo hast du Schmerzen?" : "Betroffene Hautstellen")
                        .font(.headline)
                    Spacer()
                    Button { scanSetupAnzeigen = true } label: {
                        Label(scanService.hatScan ? "Neu scannen" : "Körper scannen",
                              systemImage: scanService.hatScan ? "arrow.triangle.2.circlepath" : "camera.viewfinder")
                            .font(.caption)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color.accentColor.opacity(0.12))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                KoerperPickerView(
                    auswahl: $koerperstelle,
                    tintColor: eintragTyp == .schmerz ? .systemRed : .systemOrange,
                    subRegionenMap: eintragTyp == .schmerz ? nil : SubRegionen.hautMap
                )
                .frame(maxHeight: .infinity)
                .layoutPriority(1)

                // Selected chips
                if ausgewaehlt.isEmpty {
                    Text("Tippe auf eine Körperstelle").font(.subheadline).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center).frame(height: 30)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(ausgewaehlt.sorted(), id: \.self) { r in
                                Button {
                                    var s = ausgewaehlt; s.remove(r)
                                    koerperstelle = s.sorted().joined(separator: ", ")
                                } label: {
                                    HStack(spacing: 3) {
                                        Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                                        Text(r).font(.caption)
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(eintragTyp == .schmerz ? Color.red.opacity(0.12) : Color.orange.opacity(0.12))
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
                    .font(.caption2).foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
            .frame(maxHeight: .infinity)
            .layoutPriority(1)
        }
        .sheet(isPresented: $scanSetupAnzeigen) { BodyScanSetupView() }
    }
}

