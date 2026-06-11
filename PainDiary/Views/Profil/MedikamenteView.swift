import SwiftUI
import SwiftData

struct MedikamenteView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Dauermedikation.name) private var medikamente: [Dauermedikation]
    @Query(sort: \EinnahmeLog.datum, order: .reverse) private var logs: [EinnahmeLog]

    @State private var formAnzeigen = false
    @State private var zuBearbeiten: Dauermedikation? = nil
    @State private var logAnzeigen = false
    @State private var tagesstart = Calendar.current.startOfDay(for: Date())
    @State private var medZuLoggen: Dauermedikation? = nil
    @State private var loeschenZiel: (liste: [Dauermedikation], offsets: IndexSet)?

    private let notif = NotificationManager.shared
    private var aktive: [Dauermedikation] { medikamente.filter(\.aktiv) }
    private var inaktive: [Dauermedikation] { medikamente.filter { !$0.aktiv } }

    private var heutigeLogsHeute: [EinnahmeLog] {
        let tagesende = Calendar.current.date(byAdding: .day, value: 1, to: tagesstart) ?? tagesstart
        return logs.filter { $0.datum >= tagesstart && $0.datum < tagesende }
    }

    var body: some View {
        List {
            berechtigungBanner
            uebergebrauchWarnung
            vorratsAblaufWarnung
            bewertungsSektion
            heuteSektion
            if !aktive.isEmpty {
                Section("Aktiv") {
                    ForEach(aktive) { med in
                        MedikamentZeile(medikament: med, notif: notif)
                            .contentShape(Rectangle())
                            .onTapGesture { zuBearbeiten = med }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    medZuLoggen = med
                                } label: {
                                    Label("Einnahme erfassen", systemImage: "calendar.badge.plus")
                                }
                                .tint(.blue)
                            }
                    }
                    .onDelete { loeschen(aus: aktive, offsets: $0) }
                }
            }
            if !inaktive.isEmpty {
                Section("Pausiert / Abgesetzt") {
                    ForEach(inaktive) { med in
                        MedikamentZeile(medikament: med, notif: notif)
                            .contentShape(Rectangle())
                            .onTapGesture { zuBearbeiten = med }
                    }
                    .onDelete { loeschen(aus: inaktive, offsets: $0) }
                }
            }
            if !logs.isEmpty {
                Section {
                    NavigationLink("Einnahme-Verlauf anzeigen") {
                        EinnahmeLogView()
                    }
                }
            }
        }
        .navigationTitle("Medikamente")
        .toolbar {
#if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) { EditButton() }
#endif
            ToolbarItem(placement: .primaryAction) {
                Button { formAnzeigen = true } label: {
                    Label("Hinzufügen", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $formAnzeigen) { MedikamentFormView() }
        .sheet(item: $zuBearbeiten) { med in MedikamentFormView(medikament: med) }
        .sheet(item: $medZuLoggen) { med in
            EinnahmeLogSheet(med: med)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                tagesstart = Calendar.current.startOfDay(for: Date())
            }
        }
        .alert("Medikament löschen?", isPresented: Binding(
            get: { loeschenZiel != nil },
            set: { if !$0 { loeschenZiel = nil } }
        )) {
            Button("Löschen", role: .destructive) {
                if let ziel = loeschenZiel {
                    ziel.offsets.forEach { i in
                        notif.loescheErinnerungen(fuer: ziel.liste[i])
                        modelContext.delete(ziel.liste[i])
                    }
                }
                loeschenZiel = nil
            }
            Button("Abbrechen", role: .cancel) { loeschenZiel = nil }
        } message: {
            Text("Das Medikament wird unwiderruflich gelöscht. Einnahme-Logs bleiben erhalten.")
        }
    }

    @ViewBuilder
    private var vorratsAblaufWarnung: some View {
        let kal = Calendar.current
        let heute = kal.startOfDay(for: Date())
        let ablaufWarnungen = aktive.filter { med in
            guard let ablauf = med.ablaufDatum else { return false }
            let tage = kal.dateComponents([.day], from: heute, to: kal.startOfDay(for: ablauf)).day ?? 0
            return tage <= 14
        }
        let vorratWarnungen = aktive.filter { med in
            guard let vorrat = med.vorrat else { return false }
            return vorrat <= med.vorratSchwelle
        }
        if !ablaufWarnungen.isEmpty || !vorratWarnungen.isEmpty {
            Section {
                ForEach(ablaufWarnungen) { med in
                    let tage = kal.dateComponents([.day], from: heute,
                        to: kal.startOfDay(for: med.ablaufDatum!)).day ?? 0
                    HStack(spacing: 10) {
                        Image(systemName: tage <= 0 ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(tage <= 0 ? .red : .orange)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(med.name).font(.subheadline.bold())
                            Text(tage <= 0 ? "Abgelaufen!" : "Läuft in \(tage) Tag\(tage == 1 ? "" : "en") ab")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                ForEach(vorratWarnungen) { med in
                    HStack(spacing: 10) {
                        Image(systemName: "shippingbox.fill").foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(med.name).font(.subheadline.bold())
                            Text("Vorrat: noch \(med.vorrat ?? 0) Stück")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Label("Achtung", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        }
    }

    // Unrated Bei Bedarf logs from today (older than 1h) waiting for effectiveness rating
    @ViewBuilder
    private var bewertungsSektion: some View {
        let zuBewerten = logs.filter { log in
            guard log.eingenommen && log.wirkung.isEmpty else { return false }
            let schwelle = Double(
                medikamente.first(where: { $0.name == log.medikamentName })?.wirkungsAbfrageStunden ?? 2
            ) * 3600
            let alter = Date().timeIntervalSince(log.datum)
            return alter >= schwelle && alter < 7 * 24 * 3600
        }.prefix(3)
        if !zuBewerten.isEmpty {
            Section {
                ForEach(Array(zuBewerten)) { log in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "questionmark.circle.fill").foregroundStyle(.blue)
                            Text("Hat \(log.medikamentName) gewirkt?")
                                .font(.subheadline.bold())
                            Spacer()
                            Text(log.datum, style: .time)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        HStack(spacing: 8) {
                            wirkungsButton(log: log, wert: "gut",       label: "Gut",       farbe: .green)
                            wirkungsButton(log: log, wert: "teilweise", label: "Teilweise", farbe: .orange)
                            wirkungsButton(log: log, wert: "nicht",     label: "Nicht",     farbe: .red)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Wirksamkeit bewerten")
            }
        }
    }

    private func wirkungsButton(log: EinnahmeLog, wert: String, label: String, farbe: Color) -> some View {
        let ausgewaehlt = log.wirkung == wert
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { log.wirkung = wert }
        } label: {
            HStack(spacing: 4) {
                if ausgewaehlt {
                    Image(systemName: "checkmark").font(.caption2.bold())
                }
                Text(label).font(.caption.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(ausgewaehlt ? farbe : farbe.opacity(0.12))
            .foregroundStyle(ausgewaehlt ? .white : farbe)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .animation(.easeInOut(duration: 0.15), value: ausgewaehlt)
        }
        .buttonStyle(.plain)
    }

    // Warn if any med was logged > 10x in the last 30 days (medication overuse threshold)
    @ViewBuilder
    private var uebergebrauchWarnung: some View {
        let grenze = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let letzter30Tage = logs.filter { $0.datum >= grenze && $0.eingenommen }
        let zaehlung = Dictionary(
            grouping: letzter30Tage,
            by: { $0.dosierung.isEmpty ? $0.medikamentName : "\($0.medikamentName) \($0.dosierung)" }
        ).mapValues(\.count)
        let probleme = zaehlung.filter { $0.value > 10 }.sorted { $0.value > $1.value }

        if !probleme.isEmpty {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Möglicher Medikamenten-Übergebrauch", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                    Text("Folgende Medikamente wurden in den letzten 30 Tagen mehr als 10-mal eingenommen. Häufiger Gebrauch von Schmerzmedikamenten kann Übergebrauchskopfschmerzen verursachen. Bitte sprich mit deinem Arzt.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(probleme, id: \.key) { name, anzahl in
                        HStack {
                            Text(name).font(.caption.bold())
                            Spacer()
                            Text("\(anzahl)× in 30 Tagen").font(.caption).foregroundStyle(.orange)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private var heuteSektion: some View {
        if !aktive.isEmpty {
            Section("Heute") {
                ForEach(aktive) { med in
                    HStack(spacing: 12) {
                        Image(systemName: med.typSymbol)
                            .foregroundStyle(.blue)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(med.name).font(.subheadline).fontWeight(.medium)
                            if !med.dosierung.isEmpty {
                                Text(med.dosierung).font(.caption).foregroundStyle(.secondary)
                            }
                            if !med.einnahmeHinweis.isEmpty {
                                Text(med.einnahmeHinweis)
                                    .font(.caption2).foregroundStyle(.blue)
                            }
                        }
                        Spacer()
                        einnahmeKontrolle(med: med)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    @ViewBuilder
    private func einnahmeKontrolle(med: Dauermedikation) -> some View {
        if med.frequenz == "Wöchentlich" {
            // Wöchentliche Injektion: Tage seit / bis zur nächsten
            let letzteInjektion = logs.first { $0.medikamentName == med.name && $0.eingenommen }
            let tageSeit: Int? = letzteInjektion.map {
                max(0, Calendar.current.dateComponents([.day], from: $0.datum, to: Date()).day ?? 0)
            }
            HStack(spacing: 8) {
                if let tage = tageSeit {
                    VStack(alignment: .trailing, spacing: 1) {
                        if tage == 0 {
                            Text("Heute injiziert").font(.caption).foregroundStyle(.green)
                        } else if tage < 7 {
                            Text("Vor \(tage) Tag\(tage == 1 ? "" : "en")")
                                .font(.caption2).foregroundStyle(.secondary)
                            Text("In \(7 - tage) Tag\(7 - tage == 1 ? "" : "en")")
                                .font(.caption).foregroundStyle(tage >= 6 ? .orange : .blue)
                        } else {
                            Text("Fällig!").font(.caption.bold()).foregroundStyle(.orange)
                        }
                    }
                } else {
                    Text("Noch nicht erfasst").font(.caption).foregroundStyle(.secondary)
                }
                if tageSeit == nil || (tageSeit ?? 0) >= 1 {
                    Button {
                        medZuLoggen = med
                    } label: {
                        Image(systemName: med.typSymbol)
                            .font(.title3).foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            let anzahlErwartet = notif.anzahlDosen(med.frequenz)
            let anzahlHeute = heutigeLogsHeute.filter {
                $0.medikamentName == med.name && $0.dosierung == med.dosierung
            }.count

            if anzahlErwartet == 0 {
                // Bei Bedarf: Freitext-Zähler + Plus-Button
                HStack(spacing: 8) {
                    if anzahlHeute > 0 {
                        Text("\(anzahlHeute)× heute")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Button {
                        loggeMedikament(med)
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.title3).foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // Reguläre Dosen: ein Kreis pro erwarteter Dosis
                HStack(spacing: 6) {
                    ForEach(0..<anzahlErwartet, id: \.self) { i in
                        let bestaetigt = i < anzahlHeute
                        Button {
                            guard !bestaetigt else { return }
                            loggeMedikament(med)
                        } label: {
                            Image(systemName: bestaetigt ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(bestaetigt ? .green : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var berechtigungBanner: some View {
        if notif.status == .denied {
            Section {
                Label("Push-Benachrichtigungen deaktiviert.", systemImage: "bell.slash")
                    .font(.caption).foregroundStyle(.orange)
                Button("Einstellungen öffnen") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.caption)
            }
        } else if notif.status == .notDetermined {
            Section {
                Button {
                    Task { await notif.berechtigungAnfordern() }
                } label: {
                    Label("Benachrichtigungen aktivieren", systemImage: "bell.badge")
                }
            }
        }
    }


    private func loggeMedikament(_ med: Dauermedikation) {
        let log = EinnahmeLog(medikamentName: med.name, dosierung: med.dosierung, eingenommen: true)
        modelContext.insert(log)
        notif.planeWirkungsAbfrage(fuer: log, stunden: med.wirkungsAbfrageStunden)
        if let vorrat = med.vorrat, vorrat > 0 {
            med.vorrat = vorrat - 1
            notif.planeVorratWarnung(fuer: med)
        }
    }

    private func loeschen(aus liste: [Dauermedikation], offsets: IndexSet) {
        loeschenZiel = (liste: liste, offsets: offsets)
    }
}

// MARK: - Zeile

private struct MedikamentZeile: View {
    let medikament: Dauermedikation
    let notif: NotificationManager

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(medikament.aktiv ? Color.blue.opacity(0.15) : Color.secondary.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: medikament.typSymbol)
                    .foregroundStyle(medikament.aktiv ? .blue : .secondary)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(medikament.name).font(.headline)
                    if medikament.erinnerungAktiv {
                        Image(systemName: "bell.fill").font(.caption).foregroundStyle(.orange)
                    }
                    if !medikament.aktiv {
                        Text("Pausiert").font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2)).clipShape(Capsule())
                            .foregroundStyle(.secondary)
                    }
                }
                if !medikament.dosierung.isEmpty {
                    Text(medikament.dosierung).font(.subheadline).foregroundStyle(.secondary)
                }
                if !medikament.frequenz.isEmpty {
                    let zeiten = notif.gueltigeZeiten(fuer: medikament)
                    let zeitText = zeiten.isEmpty ? medikament.frequenz : zeiten.map(\.anzeigeText).joined(separator: ", ")
                    Label(zeitText, systemImage: "clock").font(.caption).foregroundStyle(.secondary)
                }
                if !medikament.einnahmeHinweis.isEmpty {
                    Label(medikament.einnahmeHinweis, systemImage: "fork.knife")
                        .font(.caption).foregroundStyle(.blue)
                }
                if let ablauf = medikament.ablaufDatum {
                    let tage = Calendar.current.dateComponents(
                        [.day],
                        from: Calendar.current.startOfDay(for: Date()),
                        to: Calendar.current.startOfDay(for: ablauf)
                    ).day ?? 0
                    Label {
                        Text(ablauf, format: .dateTime.day().month(.abbreviated).year())
                    } icon: {
                        Image(systemName: tage <= 14 ? "exclamationmark.triangle.fill" : "calendar.badge.clock")
                    }
                    .font(.caption)
                    .foregroundStyle(tage <= 14 ? .orange : .secondary)
                }
                if let vorrat = medikament.vorrat {
                    Label {
                        Text("\(vorrat) Stück verbleibend")
                    } icon: {
                        Image(systemName: vorrat <= medikament.vorratSchwelle ? "exclamationmark.circle.fill" : "shippingbox.fill")
                    }
                    .font(.caption)
                    .foregroundStyle(vorrat <= medikament.vorratSchwelle ? .orange : .secondary)
                }
                if !medikament.aktiv, let ende = medikament.endDatum {
                    Label {
                        Text(ende, format: .dateTime.day().month(.abbreviated).year())
                    } icon: {
                        Image(systemName: "calendar.badge.minus")
                    }
                    .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Formular

struct MedikamentFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var medikament: Dauermedikation? = nil

    @State private var name = ""
    @State private var dosierung = ""
    @State private var frequenz = ""
    @State private var startDatum = Date()
    @State private var aktiv = true
    @State private var endDatum = Date()
    @State private var medikamentTyp: String = MedikamentTyp.tablette.rawValue
    @State private var erinnerungAktiv = false
    @State private var erinnerungsZeiten: [Date] = [defaultZeit(8)]
    @State private var wirkungsAbfrageStunden: Int = 2
    @State private var einnahmeHinweis: String = ""
    @State private var vorratAktiv: Bool = false
    @State private var vorratAnzahl: Int = 28
    @State private var vorratSchwelle: Int = 7
    @State private var ablaufAktiv: Bool = false
    @State private var ablaufDatumState: Date = Date()

    private let notif = NotificationManager.shared
    private let frequenzOptionen = [
        "1× täglich", "2× täglich", "3× täglich",
        "Morgens", "Abends", "Morgens & Abends",
        "Bei Bedarf", "Wöchentlich"
    ]
    private let hinweisOptionen = [
        "", "Mit Essen", "Nüchtern", "Mit viel Wasser",
        "Vor dem Schlafen", "Morgens nüchtern", "Mit Milch"
    ]

    private var anzahlZeiten: Int { notif.anzahlDosen(frequenz) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Medikament") {
                    TextField("Name (z.B. Ibuprofen)", text: $name)
                    TextField("Dosierung (z.B. 400 mg)", text: $dosierung)
                    Picker("Art", selection: $medikamentTyp) {
                        ForEach(MedikamentTyp.allCases, id: \.rawValue) { typ in
                            Label(typ.rawValue, systemImage: typ.symbol).tag(typ.rawValue)
                        }
                    }
                    .onChange(of: medikamentTyp) { _, neue in
                        guard let typ = MedikamentTyp(rawValue: neue) else { return }
                        if typ.istInjektion { wirkungsAbfrageStunden = 24 }
                        else if wirkungsAbfrageStunden == 24 { wirkungsAbfrageStunden = 2 }
                    }
                    Picker("Einnahmehinweis", selection: $einnahmeHinweis) {
                        ForEach(hinweisOptionen, id: \.self) { opt in
                            Text(opt.isEmpty ? "Kein Hinweis" : opt).tag(opt)
                        }
                    }
                }

                Section {
                    Toggle("Vorrat verfolgen", isOn: $vorratAktiv)
                    if vorratAktiv {
                        Stepper("Aktueller Vorrat: \(vorratAnzahl)", value: $vorratAnzahl, in: 0...999)
                        Stepper("Warnung ab: \(vorratSchwelle) Stück", value: $vorratSchwelle, in: 1...99)
                    }
                } header: {
                    Text("Vorrat")
                } footer: {
                    if vorratAktiv {
                        Text("Du erhältst eine Benachrichtigung wenn der Vorrat auf \(vorratSchwelle) Stück fällt.")
                    }
                }

                Section {
                    Toggle("Ablaufdatum setzen", isOn: $ablaufAktiv)
                    if ablaufAktiv {
                        DatePicker("Ablaufdatum", selection: $ablaufDatumState, displayedComponents: .date)
                    }
                } header: {
                    Text("Verfallsdatum")
                } footer: {
                    if ablaufAktiv {
                        Text("Du erhältst eine Erinnerung 7 Tage vor dem Ablaufdatum.")
                    }
                }

                Section("Einnahme") {
                    Picker("Frequenz", selection: $frequenz) {
                        Text("Bitte wählen").tag("")
                        ForEach(frequenzOptionen, id: \.self) { Text($0).tag($0) }
                    }
                    .onChange(of: frequenz) { old, neue in
                        // old is "" during initial load from ladeWerte() — skip to preserve saved times
                        guard medikament == nil || !old.isEmpty else { return }
                        aktualisiereStandardZeiten(neue)
                    }
                    DatePicker("Seit", selection: $startDatum, displayedComponents: .date)
                }

                Section {
                    Toggle("Aktiv / Wird eingenommen", isOn: $aktiv)
                    if !aktiv {
                        DatePicker("Abgesetzt am", selection: $endDatum, displayedComponents: .date)
                    }
                }

                if !frequenz.isEmpty && frequenz != "Bei Bedarf" {
                    Section {
                        Toggle(isOn: $erinnerungAktiv) {
                            Label("Push-Erinnerung", systemImage: "bell.badge")
                        }
                        .onChange(of: erinnerungAktiv) { _, an in
                            if an && notif.status == .notDetermined {
                                Task { await notif.berechtigungAnfordern() }
                            }
                        }

                        if erinnerungAktiv {
                            ForEach(0..<max(1, anzahlZeiten), id: \.self) { i in
                                if i < erinnerungsZeiten.count {
                                    DatePicker(
                                        anzahlZeiten > 1 ? "Zeit \(i + 1)" : "Uhrzeit",
                                        selection: $erinnerungsZeiten[i],
                                        displayedComponents: .hourAndMinute
                                    )
                                }
                            }
                        }
                    } header: {
                        Text("Erinnerungen")
                    } footer: {
                        if erinnerungAktiv && anzahlZeiten > 0 {
                            Text("Du erhältst täglich \(anzahlZeiten == 1 ? "eine" : "\(anzahlZeiten)") Erinnerung\(anzahlZeiten > 1 ? "en" : "") zur eingestellten Zeit.")
                        }
                    }
                }

                if !frequenz.isEmpty {
                    Section {
                        Picker("Wirksamkeits-Abfrage", selection: $wirkungsAbfrageStunden) {
                            Text("Nach 2 Stunden").tag(2)
                            Text("Nach 24 Stunden").tag(24)
                            Text("Nach 48 Stunden").tag(48)
                        }
                    } header: {
                        Text("Wirkung")
                    } footer: {
                        Text(frequenz == "Wöchentlich"
                             ? "Empfohlen: 24–48h nach der Injektion. Du wirst dann nach der Wirkung gefragt."
                             : "Nach dieser Zeit erhältst du eine Abfrage, ob das Medikament gewirkt hat.")
                    }
                }
            }
            .navigationTitle(medikament == nil ? "Neues Medikament" : "Medikament bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { speichern() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || frequenz.isEmpty)
                }
            }
            .onAppear { ladeWerte() }
        }
    }

    private func aktualisiereStandardZeiten(_ frequenz: String) {
        let standard = notif.standardZeiten(frequenz)
        erinnerungsZeiten = standard.isEmpty ? [defaultZeit(8)] : standard.map(\.alsDate)
        if frequenz == "Wöchentlich" {
            if medikamentTyp == MedikamentTyp.tablette.rawValue {
                medikamentTyp = MedikamentTyp.spritze.rawValue
            }
            if wirkungsAbfrageStunden == 2 { wirkungsAbfrageStunden = 24 }
        }
    }

    private func ladeWerte() {
        guard let m = medikament else { return }
        name = m.name
        dosierung = m.dosierung
        frequenz = m.frequenz
        startDatum = m.startDatum
        aktiv = m.aktiv
        endDatum = m.endDatum ?? Date()
        medikamentTyp = m.medikamentTyp
        erinnerungAktiv = m.erinnerungAktiv
        wirkungsAbfrageStunden = m.wirkungsAbfrageStunden
        einnahmeHinweis = m.einnahmeHinweis
        vorratSchwelle = m.vorratSchwelle
        if let v = m.vorrat { vorratAktiv = true; vorratAnzahl = v }
        if let a = m.ablaufDatum { ablaufAktiv = true; ablaufDatumState = a }
        if !m.erinnerungsZeiten.isEmpty {
            erinnerungsZeiten = notif.parseZeitString(m.erinnerungsZeiten).map(\.alsDate)
        } else {
            aktualisiereStandardZeiten(m.frequenz)
        }
    }

    private func speichern() {
        let zeitenString = erinnerungAktiv
            ? notif.zeitenAlsString(erinnerungsZeiten.prefix(max(1, anzahlZeiten)).map(notif.dateZuZeitPunkt))
            : ""

        if let m = medikament {
            m.name = name; m.dosierung = dosierung; m.frequenz = frequenz
            m.startDatum = startDatum; m.aktiv = aktiv
            m.endDatum = aktiv ? nil : endDatum
            m.medikamentTyp = medikamentTyp
            m.erinnerungAktiv = erinnerungAktiv
            m.erinnerungsZeiten = zeitenString
            m.wirkungsAbfrageStunden = wirkungsAbfrageStunden
            m.einnahmeHinweis = einnahmeHinweis
            m.vorrat = vorratAktiv ? vorratAnzahl : nil
            m.vorratSchwelle = vorratSchwelle
            m.ablaufDatum = ablaufAktiv ? ablaufDatumState : nil
            erinnerungAktiv ? notif.planeErinnerungen(fuer: m) : notif.loescheErinnerungen(fuer: m)
            notif.planeAblaufWarnung(fuer: m)
        } else {
            let neu = Dauermedikation(name: name, dosierung: dosierung, frequenz: frequenz,
                                      startDatum: startDatum, aktiv: aktiv)
            neu.medikamentTyp = medikamentTyp
            neu.erinnerungAktiv = erinnerungAktiv
            neu.erinnerungsZeiten = zeitenString
            neu.wirkungsAbfrageStunden = wirkungsAbfrageStunden
            neu.einnahmeHinweis = einnahmeHinweis
            neu.vorrat = vorratAktiv ? vorratAnzahl : nil
            neu.vorratSchwelle = vorratSchwelle
            neu.ablaufDatum = ablaufAktiv ? ablaufDatumState : nil
            modelContext.insert(neu)
            if erinnerungAktiv { notif.planeErinnerungen(fuer: neu) }
            notif.planeAblaufWarnung(fuer: neu)
        }
        dismiss()
    }
}

// MARK: - Einnahme-Log Sheet

private struct EinnahmeLogSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \EinnahmeLog.datum, order: .reverse) private var logs: [EinnahmeLog]

    let med: Dauermedikation
    private let notif = NotificationManager.shared

    @State private var logDatum = Date()
    @State private var notizen = ""
    @State private var fehlende: [Date] = []

    private var istWöchentlich: Bool { med.frequenz == "Wöchentlich" }
    private var istBeiBedarfs: Bool { med.frequenz == "Bei Bedarf" }

    var body: some View {
        NavigationStack {
            Form {
                // Einzelne Einnahme
                Section {
                    DatePicker(
                        "Datum & Uhrzeit",
                        selection: $logDatum,
                        in: ...Date(),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                } header: {
                    Label(med.name, systemImage: med.typSymbol).font(.headline)
                } footer: {
                    if istWöchentlich {
                        Text("Wähle das Datum deiner letzten oder aktuellen Einnahme.")
                    } else {
                        Text("Einzelne Einnahme zu einem bestimmten Zeitpunkt erfassen.")
                    }
                }

                if !med.dosierung.isEmpty {
                    Section {
                        HStack {
                            Text("Dosierung")
                            Spacer()
                            Text(med.dosierung).foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Notizen") {
                    TextField("Besonderheiten, Nebenwirkungen…", text: $notizen, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }

                // Rückwirkend nacherfassen (nur für Dauermedikamente mit fixer Einnahmezeit)
                if !istBeiBedarfs && !istWöchentlich && !fehlende.isEmpty {
                    Section {
                        Button {
                            erstelleFehlendeLogs()
                            dismiss()
                        } label: {
                            Label(
                                "Alle \(fehlende.count) fehlenden Einnahmen nacherfassen",
                                systemImage: "calendar.badge.checkmark"
                            )
                            .foregroundStyle(.blue)
                        }
                    } header: {
                        Text("Rückwirkend nachführen")
                    } footer: {
                        let zeiten = notif.gueltigeZeiten(fuer: med)
                        let zeitText = zeiten.map(\.anzeigeText).joined(separator: ", ")
                        Text("Erstellt Einträge ab \(med.startDatum, format: .dateTime.day().month(.abbreviated).year()) bis heute zu den Zeiten \(zeitText). Bereits vorhandene Einnahmen werden übersprungen.")
                    }
                }
            }
            .navigationTitle("Einnahme erfassen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { speichereEinzelLog() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear { berechneFehlende() }
        }
        .presentationDetents([.medium, .large])
    }

    private func speichereEinzelLog() {
        let log = EinnahmeLog(datum: logDatum, medikamentName: med.name,
                              dosierung: med.dosierung, eingenommen: true, notizen: notizen)
        modelContext.insert(log)
        let stundenBisJetzt = max(0, Date().timeIntervalSince(logDatum)) / 3600
        let verbleibend = Double(med.wirkungsAbfrageStunden) - stundenBisJetzt
        if verbleibend > 0.1 {
            notif.planeWirkungsAbfrage(fuer: log, stunden: max(1, Int(verbleibend.rounded(.up))))
        }
        if let vorrat = med.vorrat, vorrat > 0 {
            med.vorrat = vorrat - 1
            notif.planeVorratWarnung(fuer: med)
        }
        dismiss()
    }

    private func berechneFehlende() {
        guard !istBeiBedarfs && !istWöchentlich else { return }
        let zeiten = notif.gueltigeZeiten(fuer: med)
        guard !zeiten.isEmpty else { return }

        let kal = Calendar.current
        let heute = Date()
        let heuteStart = kal.startOfDay(for: heute)
        // Max 90 Tage rückwirkend
        let maxStart = kal.date(byAdding: .day, value: -90, to: heuteStart) ?? heuteStart
        let start = [kal.startOfDay(for: med.startDatum), maxStart].max() ?? maxStart

        var result: [Date] = []
        var tag = start
        while tag <= heuteStart {
            for zeit in zeiten {
                var dc = kal.dateComponents([.year, .month, .day], from: tag)
                dc.hour = zeit.stunde; dc.minute = zeit.minute
                guard let datum = kal.date(from: dc), datum <= heute else { continue }
                let schonVorhanden = logs.contains { log in
                    log.medikamentName == med.name &&
                    log.dosierung == med.dosierung &&
                    log.eingenommen &&
                    kal.isDate(log.datum, inSameDayAs: tag) &&
                    abs(log.datum.timeIntervalSince(datum)) < 7200
                }
                if !schonVorhanden { result.append(datum) }
            }
            guard let naechster = kal.date(byAdding: .day, value: 1, to: tag) else { break }
            tag = naechster
        }
        fehlende = result
    }

    private func erstelleFehlendeLogs() {
        for datum in fehlende {
            let log = EinnahmeLog(datum: datum, medikamentName: med.name,
                                  dosierung: med.dosierung, eingenommen: true)
            modelContext.insert(log)
        }
    }
}

private func defaultZeit(_ stunde: Int) -> Date {
    var dc = DateComponents(); dc.hour = stunde; dc.minute = 0
    return Calendar.current.date(from: dc) ?? Date()
}

// MARK: - Einnahme-Log View

struct EinnahmeLogView: View {
    @Query(sort: \EinnahmeLog.datum, order: .reverse) private var logs: [EinnahmeLog]
    @Query(sort: \Dauermedikation.name) private var medikamente: [Dauermedikation]
    @Query private var profile: [Benutzerprofil]
    @Environment(\.modelContext) private var modelContext
    @State private var zeigePDFShare = false
    @State private var pdfURL: URL? = nil

    var body: some View {
        List {
            ForEach(logs as [EinnahmeLog]) { log in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 12) {
                        Image(systemName: log.eingenommen ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(log.eingenommen ? .green : .red)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(log.medikamentName).font(.headline)
                            if !log.dosierung.isEmpty {
                                Text(log.dosierung).font(.caption).foregroundStyle(.secondary)
                            }
                            if !log.wirkung.isEmpty {
                                wirkungBadge(log.wirkung)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(log.datum, style: .date).font(.caption).foregroundStyle(.secondary)
                            Text(log.datum, style: .time).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if !log.notizen.isEmpty {
                        Text(log.notizen)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 40)
                    }
                }
                .padding(.vertical, 2)
            }
            .onDelete { idx in idx.forEach { modelContext.delete(logs[$0]) } }
        }
        .navigationTitle("Einnahme-Verlauf")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { @MainActor in
                        if let url = PDFExportService.shared.erstelleMedikamentenZusammenfassung(
                            medikamente: Array(medikamente), logs: Array(logs),
                            profil: profile.first) {
                            pdfURL = url
                            zeigePDFShare = true
                        }
                    }
                } label: {
                    Label("Arztbesuch-PDF", systemImage: "doc.richtext")
                }
            }
        }
        .sheet(isPresented: $zeigePDFShare) {
            if let url = pdfURL {
                PDFPreviewView(url: url)
            }
        }
    }

    @ViewBuilder
    private func wirkungBadge(_ wirkung: String) -> some View {
        let (label, farbe): (String, Color) = switch wirkung {
        case "gut":       ("Gut gewirkt", .green)
        case "teilweise": ("Teilweise", .orange)
        case "nicht":     ("Nicht gewirkt", .red)
        default:          (wirkung, .secondary)
        }
        Text(label)
            .font(.caption2.bold())
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(farbe.opacity(0.15))
            .foregroundStyle(farbe)
            .clipShape(Capsule())
    }
}

