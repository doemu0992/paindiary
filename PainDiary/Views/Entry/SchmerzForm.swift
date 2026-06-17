import SwiftUI
import SwiftData

struct SchmerzForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var eintrag: PainEntry? = nil
    var onGespeichert: (() -> Void)? = nil

    @AppStorage("migraeneModulAktiv") private var migraeneModulAktiv = false
    @StateObject private var scanService = BodyScanService.shared
    @State private var schritt = 0
    @State private var vorwaerts = true
    @State private var datum = Date()
    @State private var koerperstelle = ""
    @State private var scanSetupAnzeigen = false
    @State private var schmerzstaerke = 5
    @State private var dauerStunden = 0
    @State private var dauerMinuten = 0
    @State private var ausgewaehlterCharakter: Set<String> = []
    @State private var charakterFreitext = ""
    @State private var ausgewaehlteAusloeser: Set<String> = []
    @State private var ausloeserFreitext = ""
    @State private var ausgewaehlteBegleit: Set<String> = []
    @State private var begleitFreitext = ""
    @State private var ausgewaehlteMassnahmen: Set<String> = []
    @State private var massnahmenFreitext = ""
    @State private var stimmung = 3
    @State private var stressLevel = 3
    @State private var schlafStunden = 7.0
    @State private var fatigue = 0
    @State private var notizen = ""
    @State private var wetterTemperatur: Double? = nil
    @State private var wetterCode: Int? = nil
    @State private var wetterWind: Double? = nil

    // Vorlage (template from last entry)
    @State private var letzterEintrag: PainEntry? = nil
    @State private var vorlageAngewendet = false

    // Erfolg & Migräne-Vorschlag
    @State private var zeigeErfolg = false
    @State private var istMigraeneEintrag = false
    @State private var zeigeMigraeneForm = false
    @State private var migraeneVorDatum = Date()
    @State private var migraeneVorStaerke = 6
    @State private var migraeneVorBegleit: Set<String> = []

    private let wetter = WetterService.shared
    private let maxSchritt = 4

    private let schrittNamen = ["Körperstelle", "Intensität", "Wie & Warum", "Was noch?", "Wohlbefinden"]
    private let progressTint: Color = .red
    private let pflichtSchritte: Set<Int> = [0, 1]

    private let charakterOptionen = [
        "Dumpf", "Stechend", "Brennend", "Drückend",
        "Pulsierend", "Krampfartig", "Ziehend", "Taubheitsgefühl"
    ]
    private let ausloeserOptionen = [
        "Stress", "Bewegung", "Wetter / Luftdruck", "Schlafmangel",
        "Mahlzeit ausgelassen", "Kälte", "Wärme", "Körperliche Anstrengung",
        "Psychische Belastung", "Unbekannt"
    ]
    private let begleitOptionen = [
        "Übelkeit", "Schwindel", "Müdigkeit", "Taubheit",
        "Kribbeln", "Schwäche", "Lichtempfindlichkeit", "Schwellung"
    ]
    private let massnahmenOptionen = [
        "Medikament", "Wärme", "Kälte", "Ruhe",
        "Bewegung / Dehnen", "Massage", "Schlaf", "Ablenkung"
    ]

    private let stimmungFarben: [Color] = [.red, .orange, .yellow, .green, .teal]
    private let stimmungLabels = ["Schlecht", "Mässig", "Okay", "Gut", "Super"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress bar
                progressBar
                    .padding(.horizontal)
                    .padding(.top, 10)

                // Step content with slide animation
                Group {
                    if schritt == 0 {
                        schrittInhalt
                            .frame(maxHeight: .infinity)
                    } else {
                        schrittInhalt
                    }
                }
                .id(schritt)
                .transition(.asymmetric(
                    insertion: .move(edge: vorwaerts ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: vorwaerts ? .leading : .trailing).combined(with: .opacity)
                ))

                // Custom bottom nav
                navigationsLeiste
            }
            .navigationTitle(eintrag == nil ? "Neuer Schmerzeintrag" : "Schmerz bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
        .onAppear { laden() }
        .sheet(isPresented: $scanSetupAnzeigen) { BodyScanSetupView() }
        .sheet(isPresented: $zeigeMigraeneForm, onDismiss: { dismiss() }) {
            MigraeneAnfallForm(
                vorDatum: migraeneVorDatum,
                vorStaerke: migraeneVorStaerke,
                vorBegleit: migraeneVorBegleit
            )
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

                        if istMigraeneEintrag {
                            VStack(spacing: 10) {
                                Text("Auch als Migräne-Anfall erfassen?")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.9))
                                    .multilineTextAlignment(.center)
                                HStack(spacing: 12) {
                                    Button {
                                        zeigeErfolg = false
                                        zeigeMigraeneForm = true
                                    } label: {
                                        Text("Ja, erfassen")
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 20).padding(.vertical, 9)
                                            .background(Color.purple)
                                            .clipShape(Capsule())
                                    }
                                    Button { dismiss() } label: {
                                        Text("Nein")
                                            .font(.subheadline)
                                            .foregroundStyle(.white.opacity(0.85))
                                            .padding(.horizontal, 20).padding(.vertical, 9)
                                            .background(Color.white.opacity(0.18))
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            .opacity(zeigeErfolg ? 1 : 0)
                            .animation(.easeIn.delay(0.25), value: zeigeErfolg)
                        }
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
                        .frame(
                            width: geo.size.width * (maxSchritt > 0 ? CGFloat(schritt) / CGFloat(maxSchritt) : 0),
                            height: 3
                        )
                        .animation(.spring(response: 0.4), value: schritt)
                }
            }
            .frame(height: 3)

            HStack {
                Text("Schritt \(schritt + 1) von \(maxSchritt + 1)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(schritt < schrittNamen.count ? schrittNamen[schritt] : "")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Step content

    @ViewBuilder
    private var schrittInhalt: some View {
        switch schritt {
        case 0:
            koerperstelleSchritt
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case 1:
            ScrollView {
                intensitaetSchritt
                    .padding(.vertical, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
        case 2:
            ScrollView {
                wieWarumSchritt
                    .padding(.vertical, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
        case 3:
            ScrollView {
                wasNochSchritt
                    .padding(.vertical, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
        default:
            ScrollView {
                wohlbefindenSchritt
                    .padding(.vertical, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
        }
    }

    // MARK: - Schritt 0: Körperstelle (Vollbild)

    private var koerperstelleSchritt: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Wo tut es weh?")
                    .font(.subheadline.bold())
                Spacer()
                if !vorlageAngewendet, let letzter = letzterEintrag, !letzter.koerperstelle.isEmpty {
                    Button {
                        wendeVorlageAn(letzter)
                    } label: {
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
                    .frame(maxWidth: 140)
                    .transition(.opacity.combined(with: .scale))
                }
                Button {
                    scanSetupAnzeigen = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.stand")
                        Text("Proportionen")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            KoerperPickerView(auswahl: $koerperstelle, tintColor: .systemRed)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            let ausgewaehlt = Set(koerperstelle.components(separatedBy: ", ").filter { !$0.isEmpty })
            if ausgewaehlt.isEmpty {
                Text("Tippe auf das Modell um eine Stelle auszuwählen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 12)
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
                                .background(Color.red.opacity(0.15))
                                .clipShape(Capsule())
                                .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Schritt 1: Intensität

    private var intensitaetSchritt: some View {
        VStack(spacing: 16) {
            karte {
                VStack(alignment: .leading, spacing: 10) {
                    DatePicker("Datum & Uhrzeit", selection: $datum, displayedComponents: [.date, .hourAndMinute])
                    if let snap = wetterAnzeige {
                        Divider()
                        HStack(spacing: 6) {
                            Image(systemName: snap.symbol)
                                .foregroundStyle(.yellow)
                            Text(String(format: "%.0f°C", snap.temperatur))
                                .font(.caption.bold())
                            if !snap.luftdruckText.isEmpty {
                                Text(snap.luftdruckText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
            }
            .padding(.top, 8)

            VStack(spacing: 6) {
                Image(systemName: "waveform.path.ecg")
                    .font(.largeTitle)
                    .foregroundStyle(.red)
                Text("Wie stark?")
                    .font(.title2.bold())
            }

            karte {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Schmerzstärke").font(.headline)
                    HStack {
                        Text("Stärke: \(schmerzstaerke) / 10")
                        Spacer()
                        Text(staerkeLabel)
                            .font(.caption.bold())
                            .foregroundStyle(staerkeFarbe)
                    }
                    Slider(
                        value: Binding(get: { Double(schmerzstaerke) }, set: { schmerzstaerke = Int($0) }),
                        in: 0...10, step: 1
                    ).tint(staerkeFarbe)
                }
            }

            karte {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Dauer").font(.headline)
                    HStack {
                        Stepper("\(dauerStunden) Std.", value: $dauerStunden, in: 0...72)
                        Stepper("\(dauerMinuten) Min.", value: $dauerMinuten, in: 0...59, step: 15)
                    }
                    .font(.subheadline)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    // MARK: - Schritt 2: Wie & Warum

    private var wieWarumSchritt: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Image(systemName: "waveform.path.ecg")
                    .font(.largeTitle)
                    .foregroundStyle(.blue)
                Text("Wie und warum?")
                    .font(.title2.bold())
            }
            .padding(.top, 8)

            chipKarte(
                titel: "Schmerzart (mehrere möglich)",
                optionen: charakterOptionen,
                ausgewaehlt: $ausgewaehlterCharakter,
                farbe: .indigo,
                freitext: $charakterFreitext,
                platzhalter: "Eigene Beschreibung…"
            )

            chipKarte(
                titel: "Häufige Auslöser (mehrere möglich)",
                optionen: ausloeserOptionen,
                ausgewaehlt: $ausgewaehlteAusloeser,
                farbe: .orange,
                freitext: $ausloeserFreitext,
                platzhalter: "Eigene Auslöser…"
            )
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    // MARK: - Schritt 3: Was noch?

    private var wasNochSchritt: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Image(systemName: "list.clipboard.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.purple)
                Text("Was noch?")
                    .font(.title2.bold())
            }
            .padding(.top, 8)

            chipKarte(
                titel: "Begleiterscheinungen (mehrere möglich)",
                optionen: begleitOptionen,
                ausgewaehlt: $ausgewaehlteBegleit,
                farbe: .red,
                freitext: $begleitFreitext,
                platzhalter: "Eigene Angaben…"
            )

            chipKarte(
                titel: "Massnahmen (mehrere möglich)",
                optionen: massnahmenOptionen,
                ausgewaehlt: $ausgewaehlteMassnahmen,
                farbe: .green,
                freitext: $massnahmenFreitext,
                platzhalter: "Eigene Massnahmen…"
            )
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    // MARK: - Schritt 4: Wohlbefinden

    private var wohlbefindenSchritt: some View {
        VStack(spacing: 16) {
            Text("Wie geht es dir?")
                .font(.title2.bold())
                .padding(.top, 8)

            karte {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Stimmung").font(.headline)
                    HStack(spacing: 0) {
                        ForEach(0..<5) { i in
                            let wert = i + 1
                            Button { stimmung = wert } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: stimmung >= wert ? "heart.fill" : "heart")
                                        .font(.system(size: 30))
                                        .foregroundStyle(stimmung >= wert ? stimmungFarben[i] : Color.secondary)
                                    Text(stimmungLabels[i])
                                        .font(.system(size: 11))
                                        .foregroundStyle(stimmung >= wert ? .primary : .secondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            karte {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Stresslevel").font(.headline)
                        Spacer()
                        Text(stressLabel)
                            .font(.subheadline.bold())
                            .foregroundStyle(stressFarbe)
                    }
                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { n in
                            Button { stressLevel = n } label: {
                                Text("\(n)")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(stressLevel >= n ? stressFarbe : Color(.tertiarySystemBackground))
                                    .foregroundStyle(stressLevel >= n ? .white : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    HStack {
                        Text("Entspannt").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("Extrem").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            karte {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Schlaf letzte Nacht").font(.headline)
                        Spacer()
                        Text(String(format: "%.1f Std.", schlafStunden))
                            .font(.subheadline.bold())
                            .foregroundStyle(.blue)
                    }
                    Slider(value: $schlafStunden, in: 0...12, step: 0.5).tint(.blue)
                    HStack {
                        Text("0 Std.").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("12 Std.").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            karte {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Erschöpfung / Fatigue").font(.headline)
                        Spacer()
                        Text(fatigue == 0 ? "Nicht erfasst" : "\(fatigue) / 10")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: Binding(get: { Double(fatigue) }, set: { fatigue = Int($0) }),
                        in: 0...10, step: 1
                    ).tint(fatigueFarbe)
                    HStack {
                        Text("Keine").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("Extrem").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            karte {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notizen").font(.headline)
                    TextEditor(text: $notizen)
                        .frame(minHeight: 80)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
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
                        .background(Color(.secondarySystemBackground), in: Circle())
                }
                .buttonStyle(.plain)
            } else {
                Spacer().frame(width: 46)
            }

            Spacer()

            if !pflichtSchritte.contains(schritt) && schritt < maxSchritt {
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

            if schritt < maxSchritt {
                Button {
                    vorwaerts = true
                    withAnimation(.easeInOut(duration: 0.25)) { schritt += 1 }
                } label: {
                    Text("Weiter ›")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 22)
                        .padding(.vertical, 13)
                        .background(progressTint, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    speichern()
                } label: {
                    Text("✓ Speichern")
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

    // MARK: - Card helpers

    @ViewBuilder
    private func karte<C: View>(@ViewBuilder content: () -> C) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func chipKarte(
        titel: String,
        optionen: [String],
        ausgewaehlt: Binding<Set<String>>,
        farbe: Color,
        freitext: Binding<String>? = nil,
        platzhalter: String? = nil
    ) -> some View {
        karte {
            VStack(alignment: .leading, spacing: 12) {
                Text(titel).font(.headline)
                FlowLayout(optionen) { opt in
                    ChipButton(
                        label: opt,
                        ausgewaehlt: ausgewaehlt.wrappedValue.contains(opt),
                        farbe: farbe
                    ) {
                        var s = ausgewaehlt.wrappedValue
                        if s.contains(opt) { s.remove(opt) } else { s.insert(opt) }
                        ausgewaehlt.wrappedValue = s
                    }
                }
                if let ft = freitext, let ph = platzhalter {
                    TextField(ph, text: ft)
                        .textFieldStyle(.roundedBorder)
                        .font(.subheadline)
                }
            }
        }
    }

    // MARK: - Computed helpers

    private var wetterAnzeige: WetterSnapshot? {
        if let temp = wetterTemperatur, let code = wetterCode {
            return WetterSnapshot(temperatur: temp, code: code,
                                  windgeschwindigkeit: wetterWind ?? 0)
        }
        return wetter.aktuell
    }

    private var staerkeLabel: String {
        switch schmerzstaerke {
        case 0:     return "Kein Schmerz"
        case 1...3: return "Leicht"
        case 4...6: return "Mittel"
        case 7...8: return "Stark"
        default:    return "Sehr stark"
        }
    }

    private var staerkeFarbe: Color {
        switch schmerzstaerke {
        case 0:     return .secondary
        case 1...3: return .green
        case 4...6: return .yellow
        case 7...8: return .orange
        default:    return .red
        }
    }

    private var stressLabel: String {
        ["", "Entspannt", "Ruhig", "Mässig", "Gestresst", "Extrem"][stressLevel]
    }

    private var stressFarbe: Color {
        switch stressLevel {
        case 1:     return .green
        case 2:     return .yellow
        case 3:     return .orange
        default:    return .red
        }
    }

    private var fatigueFarbe: Color {
        switch fatigue {
        case 0:     return .secondary
        case 1...3: return .green
        case 4...6: return .yellow
        case 7...8: return .orange
        default:    return .red
        }
    }

    // MARK: - Template

    private func wendeVorlageAn(_ e: PainEntry) {
        withAnimation(.spring(response: 0.25)) {
            koerperstelle = e.koerperstelle
            schmerzstaerke = e.schmerzstaerke
            dauerStunden = e.dauerMinuten / 60
            dauerMinuten = e.dauerMinuten % 60
            ausgewaehlterCharakter = Set(e.schmerzart.components(separatedBy: ", ").filter { !$0.isEmpty })
                .intersection(Set(charakterOptionen))
            ausgewaehlteAusloeser  = Set(e.ausloeser.components(separatedBy: ", ").filter { !$0.isEmpty })
                .intersection(Set(ausloeserOptionen))
            ausgewaehlteBegleit    = Set(e.begleiterscheinungen.components(separatedBy: ", ").filter { !$0.isEmpty })
                .intersection(Set(begleitOptionen))
            ausgewaehlteMassnahmen = Set(e.massnahmen.components(separatedBy: ", ").filter { !$0.isEmpty })
                .intersection(Set(massnahmenOptionen))
            stimmung = e.stimmung
            stressLevel = e.stressLevel
            schlafStunden = e.schlafStunden
            vorlageAngewendet = true
        }
    }

    // MARK: - Load / Save

    private func laden() {
        if let e = eintrag {
            datum = e.datum
            koerperstelle = e.koerperstelle
            schmerzstaerke = e.schmerzstaerke
            dauerStunden = e.dauerMinuten / 60
            dauerMinuten = e.dauerMinuten % 60

            let alleChar  = Set(e.schmerzart.components(separatedBy: ", ").filter { !$0.isEmpty })
            let alleAusl  = Set(e.ausloeser.components(separatedBy: ", ").filter { !$0.isEmpty })
            let alleBegl  = Set(e.begleiterscheinungen.components(separatedBy: ", ").filter { !$0.isEmpty })
            let alleMass  = Set(e.massnahmen.components(separatedBy: ", ").filter { !$0.isEmpty })

            ausgewaehlterCharakter = alleChar.intersection(Set(charakterOptionen))
            charakterFreitext      = alleChar.subtracting(Set(charakterOptionen)).sorted().joined(separator: ", ")

            ausgewaehlteAusloeser  = alleAusl.intersection(Set(ausloeserOptionen))
            ausloeserFreitext      = alleAusl.subtracting(Set(ausloeserOptionen)).sorted().joined(separator: ", ")

            ausgewaehlteBegleit    = alleBegl.intersection(Set(begleitOptionen))
            begleitFreitext        = alleBegl.subtracting(Set(begleitOptionen)).sorted().joined(separator: ", ")

            ausgewaehlteMassnahmen = alleMass.intersection(Set(massnahmenOptionen))
            massnahmenFreitext     = alleMass.subtracting(Set(massnahmenOptionen)).sorted().joined(separator: ", ")

            stimmung = e.stimmung
            stressLevel = e.stressLevel
            schlafStunden = e.schlafStunden
            fatigue = e.fatigue
            notizen = e.notizen
            wetterTemperatur = e.wetterTemperatur
            wetterCode = e.wetterCode
            wetterWind = e.wetterWind
        } else {
            if let snap = wetter.aktuell {
                wetterTemperatur = snap.temperatur
                wetterCode = snap.code
                wetterWind = snap.windgeschwindigkeit
            } else {
                wetter.laden()
            }

            var alleDesc = FetchDescriptor<PainEntry>(
                sortBy: [SortDescriptor(\.datum, order: .reverse)]
            )
            alleDesc.fetchLimit = 1
            letzterEintrag = try? modelContext.fetch(alleDesc).first

            let heute = Calendar.current.startOfDay(for: Date())
            let heuteDesc = FetchDescriptor<PainEntry>(
                predicate: #Predicate { $0.datum >= heute },
                sortBy: [SortDescriptor(\.datum, order: .reverse)]
            )
            if let letzterHeute = try? modelContext.fetch(heuteDesc).first {
                schlafStunden = letzterHeute.schlafStunden
            }
        }
    }

    private func speichern() {
        func merge(_ set: Set<String>, _ text: String) -> String {
            var s = set
            let t = text.trimmingCharacters(in: .whitespaces)
            if !t.isEmpty { s.insert(t) }
            return s.sorted().joined(separator: ", ")
        }

        let charStr = merge(ausgewaehlterCharakter, charakterFreitext)
        let auslStr = merge(ausgewaehlteAusloeser,  ausloeserFreitext)
        let beglStr = merge(ausgewaehlteBegleit,    begleitFreitext)
        let massStr = merge(ausgewaehlteMassnahmen, massnahmenFreitext)
        let dauer   = dauerStunden * 60 + dauerMinuten
        let snap    = wetter.aktuell
        let finalTemp = wetterTemperatur ?? snap?.temperatur
        let finalCode = wetterCode ?? snap?.code
        let finalWind = wetterWind ?? snap?.windgeschwindigkeit

        if let e = eintrag {
            e.datum = datum; e.koerperstelle = koerperstelle
            e.schmerzstaerke = schmerzstaerke; e.dauerMinuten = dauer
            e.schmerzart = charStr; e.ausloeser = auslStr
            e.begleiterscheinungen = beglStr; e.massnahmen = massStr
            e.stimmung = stimmung; e.stressLevel = stressLevel
            e.schlafStunden = schlafStunden; e.fatigue = fatigue
            e.notizen = notizen
        } else {
            let neu = PainEntry(
                datum: datum, schmerzstaerke: schmerzstaerke,
                koerperstelle: koerperstelle, schmerzart: charStr,
                dauerMinuten: dauer, ausloeser: auslStr,
                begleiterscheinungen: beglStr, massnahmen: massStr,
                notizen: notizen, stimmung: stimmung,
                schlafStunden: schlafStunden, stressLevel: stressLevel,
                fatigue: fatigue,
                wetterTemperatur: finalTemp, wetterCode: finalCode,
                wetterWind: finalWind
            )
            modelContext.insert(neu)
        }
        // Migräne-Erkennung bei Kopfschmerz mit Migräne-Symptomen
        if eintrag == nil, migraeneModulAktiv, koerperstelle.contains("Kopf") {
            let migraeneSym: Set<String> = ["Lichtempfindlichkeit", "Lärmempfindlichkeit", "Übelkeit", "Sehstörungen (Aura)"]
            let symptomListe = Set(beglStr.components(separatedBy: ", ").filter { !$0.isEmpty })
            if !symptomListe.isDisjoint(with: migraeneSym) {
                migraeneVorDatum = datum
                migraeneVorStaerke = min(10, max(1, schmerzstaerke))
                migraeneVorBegleit = symptomListe.intersection(migraeneSym)
                istMigraeneEintrag = true
            }
        }

#if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
#endif
        zeigeErfolg = true
        if !istMigraeneEintrag {
            onGespeichert?()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { dismiss() }
        }
    }
}
