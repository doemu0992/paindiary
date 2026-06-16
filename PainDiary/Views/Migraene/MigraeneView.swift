import SwiftUI
import SwiftData

struct MigraeneView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MigraeneEintrag.datum, order: .reverse) private var anfaelle: [MigraeneEintrag]
    @Query(sort: \MIDASBewertung.datum, order: .reverse) private var midas: [MIDASBewertung]

    @State private var zeigeForm = false
    @State private var bearbeitet: MigraeneEintrag? = nil

    private var anfaelle30: [MigraeneEintrag] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return anfaelle.filter { $0.datum >= cutoff }
    }

    var body: some View {
        List {
            statistikSektion

            Section("Fragebögen & Scores") {
                NavigationLink(destination: MIDASView()) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("MIDAS-Score")
                            if let letzter = midas.first {
                                Text("Score \(letzter.score) – \(letzter.gradText)")
                                    .font(.caption).foregroundStyle(.secondary)
                            } else {
                                Text("Noch keine Bewertung")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    } icon: {
                        Image(systemName: "list.clipboard.fill").foregroundStyle(.purple)
                    }
                }
            }

            if anfaelle.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Keine Anfälle erfasst",
                        systemImage: "brain.head.profile",
                        description: Text("Tippe auf + um einen Migräne-Anfall einzutragen.")
                    )
                    .listRowSeparator(.hidden)
                }
            } else {
                if !anfaelle30.isEmpty {
                    ausloeserSektion
                }

                Section("Anfälle") {
                    ForEach(anfaelle) { anfall in
                        MigraeneAnfallZeile(anfall: anfall)
                            .contentShape(Rectangle())
                            .onTapGesture { bearbeitet = anfall }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    modelContext.delete(anfall)
                                } label: { Label("Löschen", systemImage: "trash") }
                                Button { bearbeitet = anfall } label: { Label("Bearbeiten", systemImage: "pencil") }
                                    .tint(.blue)
                            }
                    }
                    .onDelete { idx in idx.forEach { modelContext.delete(anfaelle[$0]) } }
                }
            }
        }
        .navigationTitle("Migräne")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { zeigeForm = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $zeigeForm) { MigraeneAnfallForm() }
        .sheet(item: $bearbeitet) { MigraeneAnfallForm(anfall: $0) }
    }

    // MARK: - Sections

    private var statistikSektion: some View {
        Section {
            let anzahl = anfaelle30.count
            let avgStaerke = anfaelle30.isEmpty ? 0.0
                : Double(anfaelle30.map(\.staerke).reduce(0, +)) / Double(anfaelle30.count)
            let mitAura = anfaelle30.filter(\.hatAura).count
            let letzterMidas = midas.first

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MigraeneStatCard(
                    wert: "\(anzahl)",
                    label: "Anfälle (30 Tage)",
                    farbe: anzahl == 0 ? .green : anzahl <= 4 ? .orange : .red
                )
                MigraeneStatCard(
                    wert: anfaelle30.isEmpty ? "–" : String(format: "%.1f / 10", avgStaerke),
                    label: "Ø Schmerzstärke",
                    farbe: .orange
                )
                MigraeneStatCard(
                    wert: "\(mitAura)",
                    label: "Davon mit Aura",
                    farbe: .purple
                )
                MigraeneStatCard(
                    wert: letzterMidas.map { "\($0.score)" } ?? "–",
                    label: "MIDAS Score",
                    farbe: .blue
                )
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var ausloeserSektion: some View {
        let alle = anfaelle30.flatMap(\.ausloeserListe)
        let map = alle.reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
        let sortiert = map.sorted { $0.value > $1.value }.prefix(5)

        if !sortiert.isEmpty {
            Section("Häufige Auslöser (30 Tage)") {
                ForEach(Array(sortiert), id: \.key) { key, count in
                    HStack {
                        Text(key)
                        Spacer()
                        Text("\(count)×").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Zeile

private struct MigraeneAnfallZeile: View {
    let anfall: MigraeneEintrag

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(staerkeFarbe.opacity(0.18)).frame(width: 46, height: 46)
                VStack(spacing: 0) {
                    Text("\(anfall.staerke)")
                        .font(.title3.bold())
                        .foregroundStyle(staerkeFarbe)
                    Text("/10")
                        .font(.system(size: 7))
                        .foregroundStyle(staerkeFarbe.opacity(0.65))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(anfall.datum, style: .date).font(.subheadline.bold())
                    if anfall.hatAura {
                        Text("Aura")
                            .font(.caption2.bold())
                            .foregroundStyle(.purple)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Color.purple.opacity(0.15)).clipShape(Capsule())
                    }
                }
                HStack(spacing: 8) {
                    if !anfall.seite.isEmpty {
                        Text(anfall.seite).font(.caption).foregroundStyle(.secondary)
                    }
                    if anfall.dauer > 0 {
                        Text(anfall.dauerText).font(.caption).foregroundStyle(.secondary)
                    }
                }
                if !anfall.ausloeser.isEmpty {
                    Text(anfall.ausloeser).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }

    private var staerkeFarbe: Color {
        switch anfall.staerke {
        case 1...3: return .green
        case 4...6: return .orange
        default:    return .red
        }
    }
}

// MARK: - Stat Card

private struct MigraeneStatCard: View {
    let wert: String; let label: String; let farbe: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(wert).font(.title2.bold()).foregroundStyle(farbe)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(farbe.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Form

struct MigraeneAnfallForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Dauermedikation.name) private var alleMedikamente: [Dauermedikation]

    var anfall: MigraeneEintrag? = nil
    var vorDatum: Date = Date()
    var vorStaerke: Int = 6
    var vorBegleit: Set<String> = []
    var onGespeichert: (() -> Void)? = nil

    @State private var datum = Date()
    @State private var dauerStunden = 0
    @State private var dauerMinuten = 0
    @State private var staerke = 6
    @State private var seite = "Einseitig links"
    @State private var hatAura = false
    @State private var ausgewaehlterCharakter: Set<String> = []
    @State private var ausgewaehlteBegleitsymptome: Set<String> = []
    @State private var ausgewaehlteAusloeser: Set<String> = []
    @State private var akutmedikament = ""
    @State private var ausgewaehltesMedikament: Dauermedikation? = nil
    @State private var medikamentWirksam = ""
    @State private var notizen = ""
    @State private var wetterTemperatur: Double? = nil
    @State private var wetterCode: Int? = nil
    @State private var wetterWind: Double? = nil

    private let wetter = WetterService.shared

    private let seiten = ["Einseitig links", "Einseitig rechts", "Beidseitig"]
    private let charakterOptionen = ["Pulsierend", "Hämmernd", "Drückend", "Stechend", "Brennend"]
    private let begleitOptionen = [
        "Übelkeit", "Erbrechen", "Lichtempfindlichkeit", "Lärmempfindlichkeit",
        "Geruchsempfindlichkeit", "Sehstörungen / Flimmern", "Kribbeln / Taubheit"
    ]
    private let ausloeserOptionen = [
        "Stress", "Schlafmangel", "Zu viel Schlaf", "Hormonschwankungen",
        "Wetter / Luftdruck", "Alkohol", "Bestimmte Lebensmittel", "Koffeinentzug",
        "Körperliche Anstrengung", "Bildschirm / Licht", "Lärm", "Ausgelassene Mahlzeit"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Anfall") {
                    DatePicker("Datum & Uhrzeit", selection: $datum)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dauer").font(.subheadline)
                        HStack {
                            Stepper("\(dauerStunden) Std.", value: $dauerStunden, in: 0...72)
                            Stepper("\(dauerMinuten) Min.", value: $dauerMinuten, in: 0...59, step: 15)
                        }
                        .font(.subheadline)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Stärke: \(staerke) / 10")
                            Spacer()
                            Text(staerkeLabel).font(.caption).foregroundStyle(staerkeFarbe)
                        }
                        Slider(value: Binding(get: { Double(staerke) }, set: { staerke = Int($0) }),
                               in: 1...10, step: 1).tint(staerkeFarbe)
                    }

                    Picker("Seite", selection: $seite) {
                        ForEach(seiten, id: \.self) { Text($0).tag($0) }
                    }

                    Toggle("Aura vorhanden", isOn: $hatAura)

                    if let snap = wetterAnzeige {
                        HStack(spacing: 6) {
                            Image(systemName: snap.symbol)
                                .foregroundStyle(.secondary)
                                .font(.caption)
                            Text(String(format: "%.0f°C · %@", snap.temperatur, snap.beschreibung))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(String(format: "· %.0f km/h", snap.windgeschwindigkeit))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Schmerzcharakter") {
                    FlowLayout(charakterOptionen) { opt in
                        ChipButton(label: opt,
                                   ausgewaehlt: ausgewaehlterCharakter.contains(opt),
                                   farbe: .purple) {
                            if ausgewaehlterCharakter.contains(opt) { ausgewaehlterCharakter.remove(opt) }
                            else { ausgewaehlterCharakter.insert(opt) }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Begleitsymptome") {
                    FlowLayout(begleitOptionen) { opt in
                        ChipButton(label: opt,
                                   ausgewaehlt: ausgewaehlteBegleitsymptome.contains(opt),
                                   farbe: .red) {
                            if ausgewaehlteBegleitsymptome.contains(opt) { ausgewaehlteBegleitsymptome.remove(opt) }
                            else { ausgewaehlteBegleitsymptome.insert(opt) }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Mögliche Auslöser") {
                    FlowLayout(ausloeserOptionen) { opt in
                        ChipButton(label: opt,
                                   ausgewaehlt: ausgewaehlteAusloeser.contains(opt),
                                   farbe: .orange) {
                            if ausgewaehlteAusloeser.contains(opt) { ausgewaehlteAusloeser.remove(opt) }
                            else { ausgewaehlteAusloeser.insert(opt) }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Akutmedikament") {
                    let aktiveMeds = alleMedikamente.filter(\.aktiv)
                    if !aktiveMeds.isEmpty {
                        ForEach(aktiveMeds) { med in
                            Button {
                                if ausgewaehltesMedikament?.id == med.id {
                                    ausgewaehltesMedikament = nil
                                    akutmedikament = ""
                                } else {
                                    ausgewaehltesMedikament = med
                                    akutmedikament = med.dosierung.isEmpty
                                        ? med.name : "\(med.name) \(med.dosierung)"
                                }
                            } label: {
                                HStack {
                                    Image(systemName: med.typSymbol)
                                        .foregroundStyle(.blue)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(med.name).foregroundStyle(.primary)
                                        if !med.dosierung.isEmpty {
                                            Text(med.dosierung)
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if ausgewaehltesMedikament?.id == med.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        Divider()
                        TextField("Anderes Medikament", text: $akutmedikament)
                            .disabled(ausgewaehltesMedikament != nil)
                            .foregroundStyle(ausgewaehltesMedikament != nil ? .secondary : .primary)
                    } else {
                        TextField("z.B. Sumatriptan 50 mg", text: $akutmedikament)
                    }
                    if !akutmedikament.isEmpty || ausgewaehltesMedikament != nil {
                        Picker("Wirksam?", selection: $medikamentWirksam) {
                            Text("Nicht angegeben").tag("")
                            ForEach(["Ja", "Teilweise", "Nein"], id: \.self) { Text($0).tag($0) }
                        }
                    }
                }

                Section("Notizen") {
                    TextEditor(text: $notizen).frame(minHeight: 60)
                }
            }
            .navigationTitle(anfall == nil ? "Neuer Anfall" : "Anfall bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { speichern() }
                }
            }
        }
        .onAppear { laden() }
    }

    private var wetterAnzeige: WetterSnapshot? {
        if let temp = wetterTemperatur, let code = wetterCode {
            return WetterSnapshot(temperatur: temp, code: code,
                                  windgeschwindigkeit: wetterWind ?? 0)
        }
        return wetter.aktuell
    }

    private var staerkeLabel: String {
        switch staerke {
        case 1...3: return "Leicht"
        case 4...6: return "Mittel"
        case 7...8: return "Stark"
        default:    return "Sehr stark"
        }
    }

    private var staerkeFarbe: Color {
        switch staerke {
        case 1...3: return .green
        case 4...6: return .orange
        default:    return .red
        }
    }

    private func laden() {
        if let a = anfall {
            datum = a.datum
            dauerStunden = a.dauer / 60
            dauerMinuten = a.dauer % 60
            staerke = a.staerke
            seite = a.seite.isEmpty ? "Einseitig links" : a.seite
            hatAura = a.hatAura
            ausgewaehlterCharakter = Set(a.charakterListe)
            ausgewaehlteBegleitsymptome = Set(a.begleitsymptomeListe)
            ausgewaehlteAusloeser = Set(a.ausloeserListe)
            akutmedikament = a.akutmedikament
            medikamentWirksam = a.medikamentWirksam
            notizen = a.notizen
            wetterTemperatur = a.wetterTemperatur
            wetterCode = a.wetterCode
            wetterWind = a.wetterWind
            ausgewaehltesMedikament = alleMedikamente.first { med in
                let vollname = med.dosierung.isEmpty ? med.name : "\(med.name) \(med.dosierung)"
                return vollname == a.akutmedikament || med.name == a.akutmedikament
            }
        } else {
            if !vorBegleit.isEmpty || vorStaerke != 6 {
                datum = vorDatum
                staerke = max(1, min(10, vorStaerke))
                let mapping: [String: String] = [
                    "Übelkeit": "Übelkeit",
                    "Lichtempfindlichkeit": "Lichtempfindlichkeit",
                    "Lärmempfindlichkeit": "Lärmempfindlichkeit",
                    "Sehstörungen (Aura)": "Sehstörungen / Flimmern"
                ]
                ausgewaehlteBegleitsymptome = Set(vorBegleit.compactMap { mapping[$0] })
                hatAura = vorBegleit.contains("Sehstörungen (Aura)")
            }
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
        let dauer = dauerStunden * 60 + dauerMinuten
        let charStr   = ausgewaehlterCharakter.sorted().joined(separator: ", ")
        let beglStr   = ausgewaehlteBegleitsymptome.sorted().joined(separator: ", ")
        let auslStr   = ausgewaehlteAusloeser.sorted().joined(separator: ", ")

        let wetterSnap = wetter.aktuell
        let finalTemp = wetterTemperatur ?? wetterSnap?.temperatur
        let finalCode = wetterCode ?? wetterSnap?.code
        let finalWind = wetterWind ?? wetterSnap?.windgeschwindigkeit

        if let a = anfall {
            a.datum = datum; a.dauer = dauer; a.staerke = staerke; a.seite = seite
            a.hatAura = hatAura; a.charakter = charStr; a.begleitsymptome = beglStr
            a.ausloeser = auslStr; a.akutmedikament = akutmedikament
            a.medikamentWirksam = medikamentWirksam; a.notizen = notizen
            a.wetterTemperatur = finalTemp
            a.wetterCode = finalCode
            a.wetterWind = finalWind
        } else {
            let neu = MigraeneEintrag(datum: datum, dauer: dauer, staerke: staerke, seite: seite,
                                      charakter: charStr, begleitsymptome: beglStr, hatAura: hatAura,
                                      ausloeser: auslStr, akutmedikament: akutmedikament,
                                      medikamentWirksam: medikamentWirksam, notizen: notizen,
                                      wetterTemperatur: finalTemp, wetterCode: finalCode,
                                      wetterWind: finalWind)
            modelContext.insert(neu)

            if let med = ausgewaehltesMedikament {
                let wirkungMap = ["Ja": "gut", "Teilweise": "teilweise", "Nein": "nicht"]
                let log = EinnahmeLog(
                    datum: datum,
                    medikamentName: med.name,
                    dosierung: med.dosierung,
                    eingenommen: true,
                    notizen: "Migräne-Anfall"
                )
                log.wirkung = wirkungMap[medikamentWirksam] ?? ""
                modelContext.insert(log)
                NotificationManager.shared.planeMigraeneWirkungsAbfrage(nach: datum, medikamentName: med.name)
            } else if !akutmedikament.isEmpty {
                NotificationManager.shared.planeMigraeneWirkungsAbfrage(nach: datum, medikamentName: akutmedikament)
            }
        }
        onGespeichert?()
        dismiss()
    }
}
