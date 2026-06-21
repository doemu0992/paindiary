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
                zyklusKorrelationSektion

                Section("Anfälle") {
                    ForEach(anfaelle) { anfall in
                        NavigationLink(destination: MigraeneAnfallDetailView(anfall: anfall)) {
                            MigraeneAnfallZeile(anfall: anfall)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                NotificationManager.shared.loescheMigraeneErinnerungen(fuer: anfall.datum)
                                modelContext.delete(anfall)
                            } label: { Label("Löschen", systemImage: "trash") }
                            Button { bearbeitet = anfall } label: { Label("Bearbeiten", systemImage: "pencil") }
                                .tint(.blue)
                        }
                    }
                    .onDelete { idx in
                        idx.forEach {
                            NotificationManager.shared.loescheMigraeneErinnerungen(fuer: anfaelle[$0].datum)
                            modelContext.delete(anfaelle[$0])
                        }
                    }
                }
            }
        }
        .navigationTitle("Migräne")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { zeigeForm = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $zeigeForm) { MigraeneAnfallForm() }
        .sheet(item: $bearbeitet) { MigraeneAnfallForm(anfall: $0) }
        .sheet(isPresented: $zeigeAnalyse) {
            MigraeneAnalyseView()
        }
    }

    // MARK: - Sections

    private var avgStaerke30: Double {
        anfaelle30.isEmpty ? 0 : Double(anfaelle30.map(\.staerke).reduce(0, +)) / Double(anfaelle30.count)
    }

    private var statistikSektion: some View {
        Section {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    Label("30-Tage-Überblick", systemImage: "chart.bar.fill")
                        .font(.headline).foregroundStyle(.purple)
                    Divider()
                    HStack(spacing: 0) {
                        statPill(
                            "\(anfaelle30.count)",
                            label: "Anfälle",
                            farbe: anfaelle30.count == 0 ? .green : anfaelle30.count <= 4 ? .orange : .red
                        )
                        Divider().frame(height: 40)
                        statPill(
                            anfaelle30.isEmpty ? "–" : String(format: "%.1f", avgStaerke30),
                            label: "Ø Schmerzstärke",
                            farbe: anfaelle30.isEmpty ? .secondary : avgStaerke30 <= 4 ? .orange : .red
                        )
                        Divider().frame(height: 40)
                        statPill(
                            midas.first.map { "\($0.score)" } ?? "–",
                            label: "MIDAS Score",
                            farbe: midas.first.map { $0.score <= 5 ? Color.green : $0.score <= 20 ? .orange : .red } ?? .secondary
                        )
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)

                if !anfaelle.isEmpty {
                    Button { zeigeAnalyse = true } label: {
                        Label("Migräne-Analyse öffnen", systemImage: "chart.bar.xaxis.ascending")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.purple, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.clear)
    }

    private func statPill(_ wert: String, label: String, farbe: Color) -> some View {
        VStack(spacing: 4) {
            Text(wert).font(.title2.bold()).foregroundStyle(farbe)
            Text(label).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
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
    @State private var ausgewaehltesMedikamenteNamen: Set<String> = []
    @State private var freiTextMedikament = ""
    @State private var medikamentWirksam = ""
    @State private var notizen = ""
    @State private var wetterTemperatur: Double? = nil
    @State private var wetterCode: Int? = nil
    @State private var wetterWind: Double? = nil
    @State private var schlafStunden: Double = 7.0
    @State private var stimmung = 3
    @State private var stressLevel = 3
    @State private var fatigue = 0
    @State private var energielevel = 0
    @State private var ausloeserFreitext = ""
    @State private var begleitFreitext = ""
    @State private var prodromFreitext = ""
    @State private var charakterFreitext = ""
    @State private var postdromFreitext = ""
    @State private var customAusloeser: [String] = []
    @State private var customBegleit: [String] = []
    @State private var customProdrom: [String] = []
    @State private var customCharakter: [String] = []
    @State private var customPostdrom: [String] = []

    private let wetter = WetterService.shared
    private let maxSchritt = 5
    private let progressTint: Color = .purple
    private let pflichtSchritte: Set<Int> = [0]

    private let kopfschmerzTypen = ["Migräne", "Spannungskopfschmerz", "Cluster"]
    private let prodromBasis = [
        "Müdigkeit", "Nackensteife", "Stimmungsschwankungen", "Heisshunger",
        "Lichtempfindlichkeit", "Konzentrationsprobleme", "Gähnen",
        "Wassereinlagerungen", "Reizbarkeit"
    ]
    private let postdromBasis = [
        "Erschöpfung", "Konzentrationsprobleme", "Stimmungstief",
        "Kopfhaut empfindlich", "Schwindel", "Helligkeitsempfindlichkeit", "Hunger"
    ]
    private var prodromOptionen: [String] { prodromBasis + customProdrom.filter { !prodromBasis.contains($0) } }
    private var postdromOptionen: [String] { postdromBasis + customPostdrom.filter { !postdromBasis.contains($0) } }

    private let lokalisationen = [
        "Einseitig links", "Einseitig rechts", "Beidseitig",
        "Stirn / Vorne", "Schläfe links", "Schläfe rechts",
        "Hinterkopf", "Scheitel", "Nacken"
    ]
    private let charakterBasis = ["Pulsierend", "Hämmernd", "Drückend", "Stechend", "Brennend"]
    private var charakterOptionen: [String] { charakterBasis + customCharakter.filter { !charakterBasis.contains($0) } }
    private let begleitBasis = [
        "Übelkeit", "Erbrechen", "Lichtempfindlichkeit", "Lärmempfindlichkeit",
        "Geruchsempfindlichkeit", "Sehstörungen / Flimmern", "Kribbeln / Taubheit"
    ]
    private let ausloeserBasis = [
        "Stress", "Schlafmangel", "Zu viel Schlaf", "Hormonschwankungen",
        "Wetter / Luftdruck", "Alkohol", "Bestimmte Lebensmittel", "Koffeinentzug",
        "Körperliche Anstrengung", "Bildschirm / Licht", "Lärm", "Ausgelassene Mahlzeit"
    ]
    private var begleitOptionen: [String] { begleitBasis + customBegleit.filter { !begleitBasis.contains($0) } }
    private var ausloeserOptionen: [String] { ausloeserBasis + customAusloeser.filter { !ausloeserBasis.contains($0) } }

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
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(progressTint.opacity(0.15))
                    .frame(height: 3)
                Capsule()
                    .fill(progressTint)
                    .frame(
                        width: geo.size.width * CGFloat(schritt + 1) / CGFloat(maxSchritt + 1),
                        height: 3
                    )
                    .animation(.easeInOut(duration: 0.3), value: schritt)
            }
        }
        .frame(height: 3)
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
        case 4:
            ScrollView {
                medikamentSchritt.padding(.vertical, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
        default:
            ScrollView {
                WohlbefindenStepView(
                    stimmung: $stimmung,
                    schlafStunden: $schlafStunden,
                    stressLevel: $stressLevel,
                    notizen: $notizen,
                    energielevel: $energielevel
                )
                .padding(.vertical, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
        }
    }

    // MARK: - Schritt 0: Intensität

    private var intensitaetSchritt: some View {
        VStack(spacing: 20) {
            schrittHeader(symbol: "brain.head.profile", titel: "Wie stark?", untertitel: "Intensität und Dauer des Anfalls")

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
                                    .background(kopfschmerzTyp == typ ? Color.purple : Color(.secondarySystemGroupedBackground))
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
        VStack(spacing: 20) {
            schrittHeader(symbol: "clock.arrow.circlepath", titel: "Vor dem Anfall", untertitel: "Optional – überspringen wenn nichts bemerkt")

            chipKarte(
                titel: "Prodromsymptome (mehrere möglich)",
                optionen: prodromOptionen,
                ausgewaehlt: $ausgewaehlteProdrom,
                freitext: $prodromFreitext,
                platzhalter: "Eigenes Prodromsymptom…",
                beiCustomEintrag: { term in
                    ChipSpeicher.hinzufuegen(term, schluessel: "migraeneCustomProdrom")
                    customProdrom = ChipSpeicher.laden(schluessel: "migraeneCustomProdrom")
                }
            )
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    // MARK: - Schritt 2: Charakter

    private var charakterSchritt: some View {
        VStack(spacing: 20) {
            schrittHeader(symbol: "waveform.path.ecg", titel: "Wie & Wo?", untertitel: "Lokalisation und Schmerzcharakter")

            chipKarte(
                titel: "Lokalisation (mehrere möglich)",
                optionen: lokalisationen,
                ausgewaehlt: $ausgewaehlteSeiten
            )

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

            chipKarte(
                titel: "Schmerzcharakter (mehrere möglich)",
                optionen: charakterOptionen,
                ausgewaehlt: $ausgewaehlterCharakter,
                freitext: $charakterFreitext,
                platzhalter: "Eigener Charakter…",
                beiCustomEintrag: { term in
                    ChipSpeicher.hinzufuegen(term, schluessel: "migraeneCustomCharakter")
                    customCharakter = ChipSpeicher.laden(schluessel: "migraeneCustomCharakter")
                }
            )
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    // MARK: - Schritt 3: Symptome & Auslöser

    private var symptomeSchritt: some View {
        VStack(spacing: 20) {
            schrittHeader(symbol: "list.clipboard.fill", titel: "Symptome & Auslöser", untertitel: "Was hat begleitet und ausgelöst?")

            chipKarte(
                titel: "Begleitsymptome (mehrere möglich)",
                optionen: begleitOptionen,
                ausgewaehlt: $ausgewaehlteBegleitsymptome,
                freitext: $begleitFreitext,
                platzhalter: "Eigenes Symptom…",
                beiCustomEintrag: { term in
                    ChipSpeicher.hinzufuegen(term, schluessel: "migraeneCustomBegleit")
                    customBegleit = ChipSpeicher.laden(schluessel: "migraeneCustomBegleit")
                }
            )

            chipKarte(
                titel: "Mögliche Auslöser (mehrere möglich)",
                optionen: ausloeserOptionen,
                ausgewaehlt: $ausgewaehlteAusloeser,
                freitext: $ausloeserFreitext,
                platzhalter: "Eigener Auslöser…",
                beiCustomEintrag: { term in
                    ChipSpeicher.hinzufuegen(term, schluessel: "migraeneCustomAusloeser")
                    customAusloeser = ChipSpeicher.laden(schluessel: "migraeneCustomAusloeser")
                }
            )
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    // MARK: - Schritt 3: Abschluss

    private var medikamentSchritt: some View {
        VStack(spacing: 20) {
            schrittHeader(symbol: "checkmark.seal.fill", titel: "Abschluss", untertitel: "Medikamente und Postdrom")

            let aktiveMeds = alleMedikamente.filter(\.aktiv)
            karte {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Akutmedikamente (mehrere möglich)").font(.headline)

                    // Known medications list — multi-select
                    if !aktiveMeds.isEmpty {
                        VStack(spacing: 2) {
                            ForEach(aktiveMeds) { med in
                                let vollname = med.dosierung.isEmpty ? med.name : "\(med.name) \(med.dosierung)"
                                let sel = ausgewaehltesMedikamenteNamen.contains(vollname)
                                Button {
                                    if sel {
                                        ausgewaehltesMedikamenteNamen.remove(vollname)
                                    } else {
                                        ausgewaehltesMedikamenteNamen.insert(vollname)
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: med.typSymbol)
                                            .foregroundStyle(.purple)
                                            .frame(width: 24)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(med.name).foregroundStyle(.primary)
                                            if !med.dosierung.isEmpty {
                                                Text(med.dosierung)
                                                    .font(.caption).foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: sel ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(sel ? Color.purple : Color.secondary)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)
                                .animation(.easeInOut(duration: 0.15), value: sel)
                                if med.id != aktiveMeds.last?.id { Divider() }
                            }
                        }
                        Divider()
                    }

                    // Free-text entry
                    HStack(spacing: 8) {
                        TextField(aktiveMeds.isEmpty ? "z.B. Sumatriptan 50 mg" : "Anderes Medikament…", text: $freiTextMedikament)
                            .font(.subheadline)
                            .padding(14)
                            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                            .submitLabel(.done)
                        if !freiTextMedikament.isEmpty {
                            Button {
                                let term = freiTextMedikament.trimmingCharacters(in: .whitespaces)
                                guard !term.isEmpty else { return }
                                ausgewaehltesMedikamenteNamen.insert(term)
                                freiTextMedikament = ""
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.purple)
                                    .font(.title2)
                            }
                        }
                    }

                    // Chips for free-text medications not in the known-meds list
                    let customChips = ausgewaehltesMedikamenteNamen.filter { name in
                        !aktiveMeds.contains(where: { med in
                            let vn = med.dosierung.isEmpty ? med.name : "\(med.name) \(med.dosierung)"
                            return vn == name
                        })
                    }.sorted()
                    if !customChips.isEmpty {
                        FlowLayout(customChips) { chip in
                            HStack(spacing: 4) {
                                Text(chip).font(.caption)
                                Button {
                                    ausgewaehltesMedikamenteNamen.remove(chip)
                                } label: {
                                    Image(systemName: "xmark").font(.caption2.bold())
                                }
                            }
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color.purple.opacity(0.12), in: Capsule())
                            .foregroundStyle(.purple)
                            .buttonStyle(.plain)
                        }
                    }

                    if !ausgewaehltesMedikamenteNamen.isEmpty {
                        Divider()
                        Picker("Wirksam?", selection: $medikamentWirksam) {
                            Text("Nicht angegeben").tag("")
                            ForEach(["Ja", "Teilweise", "Nein"], id: \.self) { Text($0).tag($0) }
                        }
                    }
                }
            }

            chipKarte(
                titel: "Postdromsymptome (mehrere möglich)",
                optionen: postdromOptionen,
                ausgewaehlt: $ausgewaehltePostdrom,
                freitext: $postdromFreitext,
                platzhalter: "Eigenes Postdromsymptom…",
                beiCustomEintrag: { term in
                    ChipSpeicher.hinzufuegen(term, schluessel: "migraeneCustomPostdrom")
                    customPostdrom = ChipSpeicher.laden(schluessel: "migraeneCustomPostdrom")
                }
            )

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
                    Text("Zurück")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            if !pflichtSchritte.contains(schritt) && schritt < maxSchritt {
                Button {
                    vorwaerts = true
                    withAnimation(.easeInOut(duration: 0.25)) { schritt += 1 }
                } label: {
                    Text("Überspringen")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            if schritt < maxSchritt {
                Button {
                    vorwaerts = true
                    withAnimation(.easeInOut(duration: 0.25)) { schritt += 1 }
                } label: {
                    Text("Weiter ›")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(progressTint, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            } else {
                Button { speichern() } label: {
                    Label("Speichern", systemImage: "checkmark")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(progressTint, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
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
        farbe: Color = .purple,
        freitext: Binding<String>? = nil,
        platzhalter: String? = nil,
        beiCustomEintrag: ((String) -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(titel).font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(optionen, id: \.self) { opt in
                    let sel = ausgewaehlt.wrappedValue.contains(opt)
                    Button {
                        var s = ausgewaehlt.wrappedValue
                        if s.contains(opt) { s.remove(opt) } else { s.insert(opt) }
                        ausgewaehlt.wrappedValue = s
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: sel ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(sel ? farbe : .secondary)
                                .font(.caption)
                            Text(opt).font(.caption).lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(
                            sel ? farbe.opacity(0.12) : Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.15), value: sel)
                }
            }
            if let ft = freitext, let ph = platzhalter {
                HStack(spacing: 8) {
                    TextField(ph, text: ft)
                        .font(.subheadline)
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                    if !ft.wrappedValue.isEmpty {
                        Button {
                            let term = ft.wrappedValue.trimmingCharacters(in: .whitespaces)
                            guard !term.isEmpty else { return }
                            var s = ausgewaehlt.wrappedValue
                            s.insert(term)
                            ausgewaehlt.wrappedValue = s
                            ft.wrappedValue = ""
                            beiCustomEintrag?(term)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(farbe)
                                .font(.title2)
                        }
                    }
                }
            }
        }
    }

    private func schrittHeader(symbol: String, titel: String, untertitel: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 32)).foregroundStyle(progressTint)
            Text(titel).font(.title3.bold())
            Text(untertitel).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.bottom, 4)
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
        customAusloeser = ChipSpeicher.laden(schluessel: "migraeneCustomAusloeser")
        customBegleit = ChipSpeicher.laden(schluessel: "migraeneCustomBegleit")
        customProdrom = ChipSpeicher.laden(schluessel: "migraeneCustomProdrom")
        customCharakter = ChipSpeicher.laden(schluessel: "migraeneCustomCharakter")
        customPostdrom = ChipSpeicher.laden(schluessel: "migraeneCustomPostdrom")
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
            medikamentWirksam = a.medikamentWirksam
            ausgewaehltesMedikamenteNamen = Set(a.akutmedikament.components(separatedBy: ", ").filter { !$0.isEmpty })
            notizen = a.notizen
            wetterTemperatur = a.wetterTemperatur
            wetterCode = a.wetterCode
            wetterWind = a.wetterWind
            schlafStunden = a.schlafStunden
            stimmung = a.stimmung
            stressLevel = a.stressLevel
            fatigue = a.fatigue
            energielevel = a.energielevel
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
            let heute = Calendar.current.startOfDay(for: Date())
            let heuteDesc = FetchDescriptor<MigraeneEintrag>(
                predicate: #Predicate { $0.datum >= heute },
                sortBy: [SortDescriptor(\.datum, order: .reverse)]
            )
            if let letzterHeute = try? modelContext.fetch(heuteDesc).first {
                schlafStunden = letzterHeute.schlafStunden
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

        let akutmedikamentStr = ausgewaehltesMedikamenteNamen.sorted().joined(separator: ", ")

        if let a = anfall {
            a.datum = datum; a.dauer = dauer; a.staerke = staerke; a.seite = seitenStr
            a.hatAura = hatAura; a.charakter = charStr; a.begleitsymptome = beglStr
            a.ausloeser = auslStr; a.akutmedikament = akutmedikamentStr
            a.medikamentWirksam = medikamentWirksam; a.notizen = notizen
            a.wetterTemperatur = finalTemp
            a.wetterCode = finalCode
            a.wetterWind = finalWind
            a.kopfschmerzTyp = kopfschmerzTyp
            a.prodromsymptome = prodromStr
            a.postdrom = postdromStr
            a.endZeit = hatEndZeit ? endZeit : nil
            a.zyklusPhase = zyklusPhase
            a.schlafStunden = schlafStunden
            a.stimmung = stimmung
            a.stressLevel = stressLevel
            a.fatigue = fatigue
            a.energielevel = energielevel
        } else {
            let neu = MigraeneEintrag(datum: datum, dauer: dauer, staerke: staerke, seite: seitenStr,
                                      charakter: charStr, begleitsymptome: beglStr, hatAura: hatAura,
                                      ausloeser: auslStr, akutmedikament: akutmedikamentStr,
                                      medikamentWirksam: medikamentWirksam, notizen: notizen,
                                      wetterTemperatur: finalTemp, wetterCode: finalCode,
                                      wetterWind: finalWind)
            neu.kopfschmerzTyp = kopfschmerzTyp
            neu.prodromsymptome = prodromStr
            neu.postdrom = postdromStr
            neu.endZeit = hatEndZeit ? endZeit : nil
            neu.zyklusPhase = zyklusPhase
            neu.schlafStunden = schlafStunden
            neu.stimmung = stimmung
            neu.stressLevel = stressLevel
            neu.fatigue = fatigue
            neu.energielevel = energielevel
            modelContext.insert(neu)

            let wirkungMap = ["Ja": "gut", "Teilweise": "teilweise", "Nein": "nicht"]
            var ersterMedName: String? = nil
            for med in alleMedikamente.filter(\.aktiv) {
                let vollname = med.dosierung.isEmpty ? med.name : "\(med.name) \(med.dosierung)"
                guard ausgewaehltesMedikamenteNamen.contains(vollname) else { continue }
                let log = EinnahmeLog(
                    datum: datum,
                    medikamentName: med.name,
                    dosierung: med.dosierung,
                    eingenommen: true,
                    notizen: "Migräne-Anfall"
                )
                log.wirkung = wirkungMap[medikamentWirksam] ?? ""
                modelContext.insert(log)
                if ersterMedName == nil { ersterMedName = med.name }
            }
            if let name = ersterMedName {
                NotificationManager.shared.planeMigraeneWirkungsAbfrage(nach: datum, medikamentName: name)
            } else if let name = ausgewaehltesMedikamenteNamen.sorted().first {
                NotificationManager.shared.planeMigraeneWirkungsAbfrage(nach: datum, medikamentName: name)
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
