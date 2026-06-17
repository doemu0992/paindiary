import SwiftUI
import SwiftData
import Charts

struct MigraeneView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MigraeneEintrag.datum, order: .reverse) private var anfaelle: [MigraeneEintrag]
    @Query(sort: \MIDASBewertung.datum, order: .reverse) private var midas: [MIDASBewertung]
    @Query(sort: \ZyklusEintrag.datum, order: .reverse) private var zyklusEintraege: [ZyklusEintrag]
    @AppStorage("zyklusModulAktiv") private var zyklusModulAktiv = false

    @State private var zeigeForm = false
    @State private var bearbeitet: MigraeneEintrag? = nil
    @State private var zeigeAnalyse = false

    private var zyklusAnalyse: ZyklusAnalyse {
        ZyklusRechner.analyse(eintraege: Array(zyklusEintraege))
    }

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

            if !anfaelle.isEmpty {
                Section {
                    Button {
                        zeigeAnalyse = true
                    } label: {
                        Label("Migräne-Analyse öffnen", systemImage: "chart.bar.xaxis.ascending")
                            .font(.subheadline.bold())
                            .foregroundStyle(.purple)
                            .frame(maxWidth: .infinity, alignment: .leading)
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

                zyklusKorrelationSektion

                Section("Anfälle") {
                    ForEach(anfaelle) { anfall in
                        NavigationLink(destination: MigraeneAnfallDetailView(anfall: anfall)) {
                            MigraeneAnfallZeile(anfall: anfall)
                        }
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
        .sheet(isPresented: $zeigeAnalyse) {
            MigraeneAnalyseView(anfaelle: anfaelle, zyklusAnalyse: zyklusAnalyse)
        }
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

    @ViewBuilder
    private var zyklusKorrelationSektion: some View {
        let daten = ZyklusRechner.migraeneJePhase(anfaelle: anfaelle, analyse: zyklusAnalyse)
        if zyklusModulAktiv && !daten.isEmpty {
            Section("Migräne & Zyklus") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Anfälle je Zyklusphase (gesamt)")
                        .font(.caption).foregroundStyle(.secondary)

                    Chart(daten, id: \.phase.rawValue) { d in
                        BarMark(
                            x: .value("Phase", d.phase.rawValue),
                            y: .value("Anfälle", d.anzahl)
                        )
                        .foregroundStyle(phaseFarbe(d.phase).gradient)
                        .cornerRadius(6)
                        .annotation(position: .top) {
                            Text("\(d.anzahl)")
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .chartYScale(domain: 0...(daten.map(\.anzahl).max().map { $0 + 1 } ?? 5))
                    .frame(height: 140)

                    VStack(spacing: 4) {
                        ForEach(daten, id: \.phase.rawValue) { d in
                            HStack {
                                Circle().fill(phaseFarbe(d.phase)).frame(width: 8, height: 8)
                                Text(d.phase.rawValue).font(.caption)
                                Spacer()
                                Text("\(d.anzahl) Anfälle")
                                    .font(.caption2).foregroundStyle(.secondary)
                                Text(String(format: "Ø %.1f", d.avgStaerke))
                                    .font(.caption.bold())
                            }
                        }
                    }

                    if let top = daten.max(by: { $0.anzahl < $1.anzahl }) {
                        Label("Häufigste Phase: \(top.phase.rawValue)", systemImage: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(phaseFarbe(top.phase))
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func phaseFarbe(_ p: ZyklusRechner.Zyklusphase) -> Color {
        switch p {
        case .menstruation: return .red
        case .follikelphase: return .yellow
        case .ovulation: return .orange
        case .lutealphase: return .purple
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

    @Query private var zyklusEintraege: [ZyklusEintrag]
    @AppStorage("zyklusModulAktiv") private var zyklusModulAktiv = false

    @State private var schritt = 0
    @State private var vorwaerts = true
    @State private var zeigeErfolg = false
    @State private var datum = Date()
    @State private var dauerStunden = 0
    @State private var dauerMinuten = 0
    @State private var hatEndZeit = false
    @State private var endZeit = Date()
    @State private var staerke = 6
    @State private var kopfschmerzTyp = "Migräne"
    @State private var ausgewaehlteSeiten: Set<String> = []
    @State private var hatAura = false
    @State private var ausgewaehlteProdrom: Set<String> = []
    @State private var ausgewaehlterCharakter: Set<String> = []
    @State private var ausgewaehlteBegleitsymptome: Set<String> = []
    @State private var ausgewaehlteAusloeser: Set<String> = []
    @State private var ausgewaehltePostdrom: Set<String> = []
    @State private var akutmedikament = ""
    @State private var ausgewaehltesMedikament: Dauermedikation? = nil
    @State private var medikamentWirksam = ""
    @State private var notizen = ""
    @State private var wetterTemperatur: Double? = nil
    @State private var wetterCode: Int? = nil
    @State private var wetterWind: Double? = nil

    private let wetter = WetterService.shared
    private let maxSchritt = 4
    private let schrittNamen = ["Intensität", "Prodrom", "Charakter", "Symptome & Auslöser", "Abschluss"]
    private let progressTint: Color = .purple
    private let pflichtSchritte: Set<Int> = [0]

    private let kopfschmerzTypen = ["Migräne", "Spannungskopfschmerz", "Cluster"]
    private let prodromOptionen = [
        "Müdigkeit", "Nackensteife", "Stimmungsschwankungen", "Heisshunger",
        "Lichtempfindlichkeit", "Konzentrationsprobleme", "Gähnen",
        "Wassereinlagerungen", "Reizbarkeit"
    ]
    private let postdromOptionen = [
        "Erschöpfung", "Konzentrationsprobleme", "Stimmungstief",
        "Kopfhaut empfindlich", "Schwindel", "Helligkeitsempfindlichkeit", "Hunger"
    ]

    private let lokalisationen = [
        "Einseitig links", "Einseitig rechts", "Beidseitig",
        "Stirn / Vorne", "Schläfe links", "Schläfe rechts",
        "Hinterkopf", "Scheitel", "Nacken"
    ]
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
            VStack(spacing: 0) {
                progressBar
                    .padding(.horizontal)
                    .padding(.top, 10)

                schrittInhalt
                    .frame(maxHeight: .infinity)
                    .id(schritt)
                    .transition(.asymmetric(
                        insertion: .move(edge: vorwaerts ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: vorwaerts ? .leading : .trailing).combined(with: .opacity)
                    ))

                navigationsLeiste
            }
            .navigationTitle(anfall == nil ? "Neuer Anfall" : "Anfall bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
            }
        }
        .onAppear { laden() }
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
            ScrollView {
                intensitaetSchritt.padding(.vertical, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
        case 1:
            ScrollView {
                prodromSchritt.padding(.vertical, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
        case 2:
            ScrollView {
                charakterSchritt.padding(.vertical, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
        case 3:
            ScrollView {
                symptomeSchritt.padding(.vertical, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
        default:
            ScrollView {
                medikamentSchritt.padding(.vertical, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
        }
    }

    // MARK: - Schritt 0: Intensität

    private var intensitaetSchritt: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .font(.largeTitle)
                    .foregroundStyle(.purple)
                Text("Wie stark?")
                    .font(.title2.bold())
            }
            .padding(.top, 8)

            karte {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Kopfschmerztyp").font(.headline)
                    HStack(spacing: 8) {
                        ForEach(kopfschmerzTypen, id: \.self) { typ in
                            Button { kopfschmerzTyp = typ } label: {
                                Text(typ)
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(kopfschmerzTyp == typ ? Color.purple : Color(.tertiarySystemBackground))
                                    .foregroundStyle(kopfschmerzTyp == typ ? .white : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            karte {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Stärke").font(.headline)
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(staerkeFarbe.opacity(0.15))
                                .frame(width: 104, height: 104)
                            Circle()
                                .strokeBorder(staerkeFarbe, lineWidth: 5)
                                .frame(width: 104, height: 104)
                            VStack(spacing: 1) {
                                Text("\(staerke)")
                                    .font(.system(size: 44, weight: .bold, design: .rounded))
                                    .foregroundStyle(staerkeFarbe)
                                Text("/ 10")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: staerke)
                        Spacer()
                    }
                    Text(staerkeLabel)
                        .font(.subheadline.bold())
                        .foregroundStyle(staerkeFarbe)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Slider(
                        value: Binding(get: { Double(staerke) }, set: { staerke = Int($0) }),
                        in: 1...10, step: 1
                    ).tint(staerkeFarbe)
                    HStack {
                        Text("Leicht").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("Extrem").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            karte {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Dauer").font(.headline)
                    HStack {
                        Stepper("\(dauerStunden) Std.", value: $dauerStunden, in: 0...72)
                        Stepper("\(dauerMinuten) Min.", value: $dauerMinuten, in: 0...59, step: 15)
                    }
                    .font(.subheadline)
                    Divider()
                    Toggle(isOn: $hatEndZeit) {
                        Text("Endzeit erfassen")
                            .font(.subheadline)
                    }
                    .tint(.purple)
                    if hatEndZeit {
                        DatePicker("Ende", selection: $endZeit, displayedComponents: [.date, .hourAndMinute])
                            .font(.subheadline)
                    }
                }
            }

            karte {
                VStack(alignment: .leading, spacing: 10) {
                    DatePicker("Datum & Uhrzeit", selection: $datum, displayedComponents: [.date, .hourAndMinute])
                    if let snap = wetterAnzeige {
                        Divider()
                        HStack(spacing: 6) {
                            Image(systemName: snap.symbol).foregroundStyle(.yellow)
                            Text(String(format: "%.0f°C", snap.temperatur)).font(.caption.bold())
                            if !snap.luftdruckText.isEmpty {
                                Text(snap.luftdruckText).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    // MARK: - Schritt 1: Prodromsymptome

    private var prodromSchritt: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.largeTitle)
                    .foregroundStyle(.indigo)
                Text("Vor dem Anfall")
                    .font(.title2.bold())
                Text("Optional – überspringen wenn nichts bemerkt")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            karte {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Prodromsymptome").font(.headline)
                    FlowLayout(prodromOptionen) { opt in
                        ChipButton(
                            label: opt,
                            ausgewaehlt: ausgewaehlteProdrom.contains(opt),
                            farbe: .indigo
                        ) {
                            if ausgewaehlteProdrom.contains(opt) { ausgewaehlteProdrom.remove(opt) }
                            else { ausgewaehlteProdrom.insert(opt) }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    // MARK: - Schritt 2: Charakter

    private var charakterSchritt: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Image(systemName: "waveform.path.ecg")
                    .font(.largeTitle)
                    .foregroundStyle(.purple)
                Text("Wie & Wo?")
                    .font(.title2.bold())
            }
            .padding(.top, 8)

            karte {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Lokalisation (mehrere möglich)").font(.headline)
                    FlowLayout(lokalisationen) { opt in
                        ChipButton(
                            label: opt,
                            ausgewaehlt: ausgewaehlteSeiten.contains(opt),
                            farbe: .purple
                        ) {
                            if ausgewaehlteSeiten.contains(opt) { ausgewaehlteSeiten.remove(opt) }
                            else { ausgewaehlteSeiten.insert(opt) }
                        }
                    }
                }
            }

            karte {
                Toggle(isOn: $hatAura) {
                    HStack(spacing: 10) {
                        Image(systemName: "eye.fill")
                            .foregroundStyle(.purple)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Aura vorhanden")
                                .font(.headline)
                            Text("Sehstörungen, Kribbeln vor dem Anfall")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .tint(.purple)
            }

            karte {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Schmerzcharakter (mehrere möglich)").font(.headline)
                    FlowLayout(charakterOptionen) { opt in
                        ChipButton(
                            label: opt,
                            ausgewaehlt: ausgewaehlterCharakter.contains(opt),
                            farbe: .purple
                        ) {
                            if ausgewaehlterCharakter.contains(opt) { ausgewaehlterCharakter.remove(opt) }
                            else { ausgewaehlterCharakter.insert(opt) }
                        }
                    }
                }
            }

        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    // MARK: - Schritt 3: Symptome & Auslöser

    private var symptomeSchritt: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Image(systemName: "list.clipboard.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.red)
                Text("Symptome & Auslöser")
                    .font(.title2.bold())
            }
            .padding(.top, 8)

            karte {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Begleitsymptome (mehrere möglich)").font(.headline)
                    FlowLayout(begleitOptionen) { opt in
                        ChipButton(
                            label: opt,
                            ausgewaehlt: ausgewaehlteBegleitsymptome.contains(opt),
                            farbe: .red
                        ) {
                            if ausgewaehlteBegleitsymptome.contains(opt) { ausgewaehlteBegleitsymptome.remove(opt) }
                            else { ausgewaehlteBegleitsymptome.insert(opt) }
                        }
                    }
                }
            }

            karte {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Mögliche Auslöser (mehrere möglich)").font(.headline)
                    FlowLayout(ausloeserOptionen) { opt in
                        ChipButton(
                            label: opt,
                            ausgewaehlt: ausgewaehlteAusloeser.contains(opt),
                            farbe: .orange
                        ) {
                            if ausgewaehlteAusloeser.contains(opt) { ausgewaehlteAusloeser.remove(opt) }
                            else { ausgewaehlteAusloeser.insert(opt) }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    // MARK: - Schritt 3: Abschluss

    private var medikamentSchritt: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.purple)
                Text("Abschluss")
                    .font(.title2.bold())
            }
            .padding(.top, 8)

            let aktiveMeds = alleMedikamente.filter(\.aktiv)
            karte {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Akutmedikament").font(.headline)
                    if !aktiveMeds.isEmpty {
                        VStack(spacing: 2) {
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
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)
                                if med.id != aktiveMeds.last?.id { Divider() }
                            }
                        }
                        Divider()
                        TextField("Anderes Medikament", text: $akutmedikament)
                            .disabled(ausgewaehltesMedikament != nil)
                            .foregroundStyle(ausgewaehltesMedikament != nil ? .secondary : .primary)
                    } else {
                        TextField("z.B. Sumatriptan 50 mg", text: $akutmedikament)
                    }
                    if !akutmedikament.isEmpty || ausgewaehltesMedikament != nil {
                        Divider()
                        Picker("Wirksam?", selection: $medikamentWirksam) {
                            Text("Nicht angegeben").tag("")
                            ForEach(["Ja", "Teilweise", "Nein"], id: \.self) { Text($0).tag($0) }
                        }
                    }
                }
            }

            karte {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Postdromsymptome").font(.headline)
                    Text("Beschwerden nach dem Anfall")
                        .font(.caption).foregroundStyle(.secondary)
                    FlowLayout(postdromOptionen) { opt in
                        ChipButton(
                            label: opt,
                            ausgewaehlt: ausgewaehltePostdrom.contains(opt),
                            farbe: .teal
                        ) {
                            if ausgewaehltePostdrom.contains(opt) { ausgewaehltePostdrom.remove(opt) }
                            else { ausgewaehltePostdrom.insert(opt) }
                        }
                    }
                }
            }

            if zyklusModulAktiv && !autoZyklusPhase.isEmpty {
                karte {
                    HStack(spacing: 12) {
                        Image(systemName: "moon.stars.fill").foregroundStyle(.pink)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Zyklusphase").font(.headline)
                            Text(autoZyklusPhase)
                                .font(.subheadline).foregroundStyle(.pink)
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
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
                        .frame(width: 40, height: 40)
                        .background(Color(.secondarySystemBackground), in: Circle())
                }
                .buttonStyle(.plain)
            } else {
                Spacer().frame(width: 40)
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
                        .padding(.vertical, 10)
                        .background(progressTint, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            } else {
                Button { speichern() } label: {
                    Text("✓ Speichern")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(Color.green, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(.bar)
    }

    // MARK: - Card helper

    @ViewBuilder
    private func karte<C: View>(@ViewBuilder content: () -> C) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
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

    private var autoZyklusPhase: String {
        guard zyklusModulAktiv, !zyklusEintraege.isEmpty else { return "" }
        let analyse = ZyklusRechner.analyse(eintraege: zyklusEintraege)
        let tag = Calendar.current.startOfDay(for: datum)
        if analyse.periodeTageSet.contains(tag)   { return "Menstruation" }
        if analyse.ovulationsTageSet.contains(tag) { return "Eisprung" }
        if analyse.fruchtbareTageSet.contains(tag) { return "Fruchtbar" }
        return ""
    }

    private func laden() {
        if let a = anfall {
            datum = a.datum
            dauerStunden = a.dauer / 60
            dauerMinuten = a.dauer % 60
            staerke = a.staerke
            hatAura = a.hatAura
            kopfschmerzTyp = a.kopfschmerzTyp.isEmpty ? "Migräne" : a.kopfschmerzTyp
            ausgewaehlteSeiten = Set(a.seite.components(separatedBy: ", ").filter { !$0.isEmpty })
            ausgewaehlterCharakter = Set(a.charakterListe)
            ausgewaehlteProdrom = Set(a.prodromListe)
            ausgewaehlteBegleitsymptome = Set(a.begleitsymptomeListe)
            ausgewaehlteAusloeser = Set(a.ausloeserListe)
            ausgewaehltePostdrom = Set(a.postdromListe)
            hatEndZeit = a.endZeit != nil
            endZeit = a.endZeit ?? Date()
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
        let seitenStr  = ausgewaehlteSeiten.sorted().joined(separator: ", ")
        let charStr    = ausgewaehlterCharakter.sorted().joined(separator: ", ")
        let beglStr    = ausgewaehlteBegleitsymptome.sorted().joined(separator: ", ")
        let auslStr    = ausgewaehlteAusloeser.sorted().joined(separator: ", ")
        let prodromStr = ausgewaehlteProdrom.sorted().joined(separator: ", ")
        let postdromStr = ausgewaehltePostdrom.sorted().joined(separator: ", ")
        let zyklusPhase = autoZyklusPhase

        let wetterSnap = wetter.aktuell
        let finalTemp = wetterTemperatur ?? wetterSnap?.temperatur
        let finalCode = wetterCode ?? wetterSnap?.code
        let finalWind = wetterWind ?? wetterSnap?.windgeschwindigkeit

        if let a = anfall {
            a.datum = datum; a.dauer = dauer; a.staerke = staerke; a.seite = seitenStr
            a.hatAura = hatAura; a.charakter = charStr; a.begleitsymptome = beglStr
            a.ausloeser = auslStr; a.akutmedikament = akutmedikament
            a.medikamentWirksam = medikamentWirksam; a.notizen = notizen
            a.wetterTemperatur = finalTemp
            a.wetterCode = finalCode
            a.wetterWind = finalWind
            a.kopfschmerzTyp = kopfschmerzTyp
            a.prodromsymptome = prodromStr
            a.postdrom = postdromStr
            a.endZeit = hatEndZeit ? endZeit : nil
            a.zyklusPhase = zyklusPhase
        } else {
            let neu = MigraeneEintrag(datum: datum, dauer: dauer, staerke: staerke, seite: seitenStr,
                                      charakter: charStr, begleitsymptome: beglStr, hatAura: hatAura,
                                      ausloeser: auslStr, akutmedikament: akutmedikament,
                                      medikamentWirksam: medikamentWirksam, notizen: notizen,
                                      wetterTemperatur: finalTemp, wetterCode: finalCode,
                                      wetterWind: finalWind)
            neu.kopfschmerzTyp = kopfschmerzTyp
            neu.prodromsymptome = prodromStr
            neu.postdrom = postdromStr
            neu.endZeit = hatEndZeit ? endZeit : nil
            neu.zyklusPhase = zyklusPhase
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
            if ausgewaehltePostdrom.isEmpty && !hatEndZeit {
                NotificationManager.shared.planeMigraenePostdromErinnerung(nach: datum)
            }
        }

#if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
#endif
        zeigeErfolg = true
        onGespeichert?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { dismiss() }
    }
}
