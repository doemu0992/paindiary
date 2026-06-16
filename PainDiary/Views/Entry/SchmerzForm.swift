import SwiftUI
import SwiftData

struct SchmerzForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var eintrag: PainEntry? = nil
    var onGespeichert: (() -> Void)? = nil

    @StateObject private var scanService = BodyScanService.shared
    @State private var schritt = 0
    @State private var datum = Date()
    @State private var koerperstelle = ""
    @State private var scanSetupAnzeigen = false
    @State private var schmerzstaerke = 5
    @State private var dauerStunden = 0
    @State private var dauerMinuten = 0
    @State private var ausgewaehlterCharakter: Set<String> = []
    @State private var ausgewaehlteAusloeser: Set<String> = []
    @State private var ausgewaehlteBegleit: Set<String> = []
    @State private var ausgewaehlteMassnahmen: Set<String> = []
    @State private var stimmung = 3
    @State private var stressLevel = 3
    @State private var schlafStunden = 7.0
    @State private var notizen = ""
    @State private var wetterTemperatur: Double? = nil
    @State private var wetterCode: Int? = nil
    @State private var wetterWind: Double? = nil

    private let wetter = WetterService.shared
    private let maxSchritt = 4

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

    var body: some View {
        NavigationStack {
            Group {
                switch schritt {
                case 0: schritt1
                case 1: schritt2
                case 2: schritt3
                case 3: schritt4
                default: schritt5
                }
            }
            .navigationTitle(eintrag == nil ? "Neuer Schmerzeintrag" : "Schmerz bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if schritt == 0 {
                        Button("Abbrechen") { dismiss() }
                    } else {
                        Button {
                            withAnimation { schritt -= 1 }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Zurück")
                            }
                        }
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("\(schritt + 1) / \(maxSchritt + 1)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if schritt < maxSchritt {
                        Button("Weiter") {
                            withAnimation { schritt += 1 }
                        }
                        .fontWeight(.semibold)
                    } else {
                        Button("Speichern") { speichern() }
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .onAppear { laden() }
        .sheet(isPresented: $scanSetupAnzeigen) { BodyScanSetupView() }
    }

    // MARK: - Schritt 1: Zeitpunkt & Schmerzstärke

    private var schritt1: some View {
        Form {
            Section("Zeitpunkt") {
                DatePicker("Datum & Uhrzeit", selection: $datum)

                if let snap = wetterAnzeige {
                    HStack(spacing: 6) {
                        Image(systemName: snap.symbol)
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        Text(String(format: "%.0f°C · %@ · %.0f km/h",
                                    snap.temperatur, snap.beschreibung, snap.windgeschwindigkeit))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Schmerzstärke") {
                VStack(alignment: .leading, spacing: 6) {
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

            Section("Dauer") {
                HStack {
                    Stepper("\(dauerStunden) Std.", value: $dauerStunden, in: 0...72)
                    Stepper("\(dauerMinuten) Min.", value: $dauerMinuten, in: 0...59, step: 15)
                }
                .font(.subheadline)
            }
        }
    }

    // MARK: - Schritt 2: Körperstelle (3D Modell – Vollbild)

    private var schritt2: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Wo tut es weh?")
                    .font(.subheadline.bold())
                Spacer()
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

            KoerperPickerView(
                auswahl: $koerperstelle,
                tintColor: .systemRed
            )
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

    // MARK: - Schritt 3: Schmerzcharakter & Auslöser

    private var schritt3: some View {
        Form {
            Section("Schmerzcharakter") {
                FlowLayout(charakterOptionen) { opt in
                    ChipButton(label: opt,
                               ausgewaehlt: ausgewaehlterCharakter.contains(opt),
                               farbe: .indigo) {
                        toggle(&ausgewaehlterCharakter, opt)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Auslöser") {
                FlowLayout(ausloeserOptionen) { opt in
                    ChipButton(label: opt,
                               ausgewaehlt: ausgewaehlteAusloeser.contains(opt),
                               farbe: .orange) {
                        toggle(&ausgewaehlteAusloeser, opt)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Schritt 4: Begleitsymptome & Massnahmen

    private var schritt4: some View {
        Form {
            Section("Begleitsymptome") {
                FlowLayout(begleitOptionen) { opt in
                    ChipButton(label: opt,
                               ausgewaehlt: ausgewaehlteBegleit.contains(opt),
                               farbe: .red) {
                        toggle(&ausgewaehlteBegleit, opt)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Massnahmen") {
                FlowLayout(massnahmenOptionen) { opt in
                    ChipButton(label: opt,
                               ausgewaehlt: ausgewaehlteMassnahmen.contains(opt),
                               farbe: .green) {
                        toggle(&ausgewaehlteMassnahmen, opt)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Schritt 5: Wohlbefinden & Notizen

    private var schritt5: some View {
        Form {
            Section("Stimmung") {
                HStack(spacing: 12) {
                    ForEach(1...5, id: \.self) { wert in
                        Button { stimmung = wert } label: {
                            Image(systemName: stimmung >= wert ? "heart.fill" : "heart")
                                .foregroundStyle(stimmung >= wert ? .pink : .secondary)
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                    Text(stimmungLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Stress") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Stress: \(stressLevel) / 5")
                        Spacer()
                        Text(stressLabel).font(.caption).foregroundStyle(.secondary)
                    }
                    Slider(
                        value: Binding(get: { Double(stressLevel) }, set: { stressLevel = Int($0) }),
                        in: 1...5, step: 1
                    ).tint(.orange)
                }
            }

            Section("Schlaf") {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(format: "%.1f Stunden", schlafStunden))
                    Slider(value: $schlafStunden, in: 0...12, step: 0.5).tint(.blue)
                }
            }

            Section("Notizen") {
                TextEditor(text: $notizen).frame(minHeight: 80)
            }
        }
    }

    // MARK: - Helpers

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

    private var stimmungLabel: String {
        ["", "Sehr schlecht", "Schlecht", "Neutral", "Gut", "Sehr gut"][stimmung]
    }

    private var stressLabel: String {
        ["", "Entspannt", "Ruhig", "Mässig", "Gestresst", "Extrem"][stressLevel]
    }

    private func toggle(_ set: inout Set<String>, _ val: String) {
        if set.contains(val) { set.remove(val) } else { set.insert(val) }
    }

    // MARK: - Load / Save

    private func laden() {
        if let e = eintrag {
            datum = e.datum
            koerperstelle = e.koerperstelle
            schmerzstaerke = e.schmerzstaerke
            dauerStunden = e.dauerMinuten / 60
            dauerMinuten = e.dauerMinuten % 60
            ausgewaehlterCharakter  = Set(e.schmerzart.components(separatedBy: ", ").filter { !$0.isEmpty })
            ausgewaehlteAusloeser   = Set(e.ausloeser.components(separatedBy: ", ").filter { !$0.isEmpty })
            ausgewaehlteBegleit     = Set(e.begleiterscheinungen.components(separatedBy: ", ").filter { !$0.isEmpty })
            ausgewaehlteMassnahmen  = Set(e.massnahmen.components(separatedBy: ", ").filter { !$0.isEmpty })
            stimmung = e.stimmung
            stressLevel = e.stressLevel
            schlafStunden = e.schlafStunden
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
        }
    }

    private func speichern() {
        let charStr  = ausgewaehlterCharakter.sorted().joined(separator: ", ")
        let auslStr  = ausgewaehlteAusloeser.sorted().joined(separator: ", ")
        let beglStr  = ausgewaehlteBegleit.sorted().joined(separator: ", ")
        let massStr  = ausgewaehlteMassnahmen.sorted().joined(separator: ", ")
        let dauer    = dauerStunden * 60 + dauerMinuten
        let snap     = wetter.aktuell
        let finalTemp = wetterTemperatur ?? snap?.temperatur
        let finalCode = wetterCode ?? snap?.code
        let finalWind = wetterWind ?? snap?.windgeschwindigkeit

        if let e = eintrag {
            e.datum = datum; e.koerperstelle = koerperstelle
            e.schmerzstaerke = schmerzstaerke; e.dauerMinuten = dauer
            e.schmerzart = charStr; e.ausloeser = auslStr
            e.begleiterscheinungen = beglStr; e.massnahmen = massStr
            e.stimmung = stimmung; e.stressLevel = stressLevel
            e.schlafStunden = schlafStunden; e.notizen = notizen
        } else {
            let neu = PainEntry(
                datum: datum, schmerzstaerke: schmerzstaerke,
                koerperstelle: koerperstelle, schmerzart: charStr,
                dauerMinuten: dauer, ausloeser: auslStr,
                begleiterscheinungen: beglStr, massnahmen: massStr,
                notizen: notizen, stimmung: stimmung,
                schlafStunden: schlafStunden, stressLevel: stressLevel,
                wetterTemperatur: finalTemp, wetterCode: finalCode,
                wetterWind: finalWind
            )
            modelContext.insert(neu)
        }
        onGespeichert?()
        dismiss()
    }
}
