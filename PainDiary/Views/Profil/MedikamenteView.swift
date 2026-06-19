import SwiftUI
import SwiftData

struct MedikamenteView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Dauermedikation.name) private var medikamente: [Dauermedikation]
    @Query(sort: \EinnahmeLog.datum, order: .reverse) private var logs: [EinnahmeLog]

    @State private var formAnzeigen = false
    @State private var zuBearbeiten: Dauermedikation? = nil
    @State private var zeigeAnalyse = false
    @State private var tagesstart = Calendar.current.startOfDay(for: Date())
    @State private var medZuLoggen: Dauermedikation? = nil
    @State private var loeschenZiel: (liste: [Dauermedikation], offsets: IndexSet)?

    private let notif = NotificationManager.shared
    private var aktive: [Dauermedikation] { medikamente.filter(\.aktiv) }
    private var inaktive: [Dauermedikation] { medikamente.filter { !$0.aktiv } }

    private var heutigeLogs: [EinnahmeLog] {
        let ende = Calendar.current.date(byAdding: .day, value: 1, to: tagesstart) ?? tagesstart
        return logs.filter { $0.datum >= tagesstart && $0.datum < ende }
    }

    // MARK: - Statistiken

    private var adherenz7T: Double {
        let kal = Calendar.current
        var erwartet = 0; var eingenommen = 0
        for offset in 0..<7 {
            guard let tag = kal.date(byAdding: .day, value: -offset, to: tagesstart),
                  let tagEnde = kal.date(byAdding: .day, value: 1, to: tag) else { continue }
            for med in aktive {
                let n = notif.anzahlDosen(med.frequenz)
                guard n > 0 else { continue }
                erwartet += n
                let genommen = logs.filter {
                    $0.medikamentName == med.name && $0.dosierung == med.dosierung &&
                    $0.eingenommen && $0.datum >= tag && $0.datum < tagEnde
                }.count
                eingenommen += min(genommen, n)
            }
        }
        return erwartet > 0 ? Double(eingenommen) / Double(erwartet) * 100 : 0
    }

    private var heuteErwartet: Int {
        aktive.map { notif.anzahlDosen($0.frequenz) }.reduce(0, +)
    }

    private var heuteEingenommen: Int {
        aktive.map { med in
            let n = notif.anzahlDosen(med.frequenz)
            guard n > 0 else { return 0 }
            return min(n, heutigeLogs.filter {
                $0.medikamentName == med.name && $0.dosierung == med.dosierung && $0.eingenommen
            }.count)
        }.reduce(0, +)
    }

    private var streak: Int {
        let kal = Calendar.current
        var tag = tagesstart; var count = 0
        while count < 365 {
            let tagEnde = kal.date(byAdding: .day, value: 1, to: tag) ?? tag
            let vollst = aktive.allSatisfy { med in
                let n = notif.anzahlDosen(med.frequenz)
                guard n > 0 else { return true }
                return logs.filter {
                    $0.medikamentName == med.name && $0.dosierung == med.dosierung &&
                    $0.eingenommen && $0.datum >= tag && $0.datum < tagEnde
                }.count >= n
            }
            guard vollst else { break }
            count += 1
            guard let prev = kal.date(byAdding: .day, value: -1, to: tag) else { break }
            tag = prev
        }
        return count
    }

    // MARK: - Body

    var body: some View {
        List {
            statistikSektion
            berechtigungBanner
            uebergebrauchWarnung
            vorratsAblaufWarnung
            bewertungsSektion
            heuteSektion
            if !inaktive.isEmpty { inaktiveSektion }
        }
        .navigationTitle("Medikamente")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { formAnzeigen = true } label: {
                    Label("Hinzufügen", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $formAnzeigen) { MedikamentFormView() }
        .sheet(item: $zuBearbeiten) { MedikamentFormView(medikament: $0) }
        .sheet(item: $medZuLoggen) { EinnahmeLogSheet(med: $0) }
        .sheet(isPresented: $zeigeAnalyse) {
            MedikamenteAnalyseView(medikamente: Array(medikamente), logs: Array(logs))
        }
        .onChange(of: scenePhase) { _, p in
            if p == .active { tagesstart = Calendar.current.startOfDay(for: Date()) }
        }
        .alert("Medikament löschen?", isPresented: Binding(
            get: { loeschenZiel != nil },
            set: { if !$0 { loeschenZiel = nil } }
        )) {
            Button("Löschen", role: .destructive) {
                if let z = loeschenZiel {
                    z.offsets.forEach { notif.loescheErinnerungen(fuer: z.liste[$0]); modelContext.delete(z.liste[$0]) }
                }
                loeschenZiel = nil
            }
            Button("Abbrechen", role: .cancel) { loeschenZiel = nil }
        } message: {
            Text("Das Medikament wird unwiderruflich gelöscht. Einnahme-Logs bleiben erhalten.")
        }
    }

    // MARK: - Statistik-Sektion

    private var statistikSektion: some View {
        Section {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    Label("7-Tage-Überblick", systemImage: "pill.fill")
                        .font(.headline).foregroundStyle(.blue)
                    Divider()
                    HStack(spacing: 0) {
                        let adFarbe: Color = adherenz7T >= 80 ? .green : adherenz7T >= 50 ? .orange : adherenz7T > 0 ? .red : .secondary
                        statPill(adherenz7T > 0 ? String(format: "%.0f%%", adherenz7T) : "–", label: "Adherenz", farbe: adFarbe)
                        Divider().frame(height: 40)
                        let heuteFarbe: Color = heuteErwartet == 0 ? .secondary : heuteEingenommen >= heuteErwartet ? .green : .blue
                        statPill(heuteErwartet > 0 ? "\(heuteEingenommen)/\(heuteErwartet)" : "–", label: "Heute", farbe: heuteFarbe)
                        Divider().frame(height: 40)
                        let streakFarbe: Color = streak >= 7 ? .green : streak >= 3 ? .orange : .secondary
                        statPill(streak > 0 ? "\(streak)T" : "–", label: "Streak", farbe: streakFarbe)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)

                if !logs.isEmpty {
                    Button { zeigeAnalyse = true } label: {
                        Label("Medikamenten-Analyse öffnen", systemImage: "chart.bar.xaxis.ascending")
                            .font(.subheadline.bold()).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Color.blue, in: RoundedRectangle(cornerRadius: 12))
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

    // MARK: - Heute-Sektion (zeitlich sortiert, kein Duplikat)

    @ViewBuilder
    private var heuteSektion: some View {
        if !aktive.isEmpty {
            let planmaessig = aktive
                .filter { $0.frequenz != "Bei Bedarf" }
                .sorted {
                    let s0 = notif.gueltigeZeiten(fuer: $0).first?.stunde ?? 99
                    let s1 = notif.gueltigeZeiten(fuer: $1).first?.stunde ?? 99
                    return s0 < s1
                }
            let beiBedarf = aktive.filter { $0.frequenz == "Bei Bedarf" }

            Section {
                ForEach(planmaessig) { med in
                    heuteZeile(med)
                }
                if !beiBedarf.isEmpty {
                    if !planmaessig.isEmpty {
                        HStack(spacing: 8) {
                            Rectangle().fill(Color.secondary.opacity(0.25)).frame(height: 1)
                            Text("Bei Bedarf")
                                .font(.caption2.bold()).foregroundStyle(.secondary)
                                .fixedSize()
                            Rectangle().fill(Color.secondary.opacity(0.25)).frame(height: 1)
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                    }
                    ForEach(beiBedarf) { med in
                        heuteZeile(med)
                    }
                }
                if !logs.isEmpty {
                    NavigationLink {
                        EinnahmeLogView()
                    } label: {
                        Label("Einnahme-Verlauf anzeigen", systemImage: "list.bullet.rectangle")
                            .font(.subheadline).foregroundStyle(.blue)
                    }
                }
            } header: {
                HStack {
                    Text("Heute").textCase(nil).font(.subheadline.bold()).foregroundStyle(.primary)
                    Spacer()
                    Text(Date(), format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func heuteZeile(_ med: Dauermedikation) -> some View {
        HStack(spacing: 12) {
            Image(systemName: med.typSymbol)
                .foregroundStyle(.blue)
                .font(.body)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(med.name).font(.subheadline).fontWeight(.medium)
                HStack(spacing: 4) {
                    if !med.dosierung.isEmpty {
                        Text(med.dosierung).font(.caption).foregroundStyle(.secondary)
                    }
                    let zeiten = notif.gueltigeZeiten(fuer: med)
                    if !zeiten.isEmpty {
                        if !med.dosierung.isEmpty {
                            Text("·").font(.caption).foregroundStyle(.tertiary)
                        }
                        Text(zeiten.map(\.anzeigeText).joined(separator: ", "))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if !med.einnahmeHinweis.isEmpty {
                    Text(med.einnahmeHinweis).font(.caption2).foregroundStyle(.blue)
                }
                if let vorrat = med.vorrat, vorrat <= med.vorratSchwelle {
                    Label("\(vorrat) Stück verbleibend", systemImage: "exclamationmark.circle.fill")
                        .font(.caption2).foregroundStyle(.orange)
                }
            }

            Spacer()
            einnahmeKontrolle(med: med)
        }
        .padding(.vertical, 3)
        .swipeActions(edge: .trailing) {
            Button { zuBearbeiten = med } label: {
                Label("Bearbeiten", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button { medZuLoggen = med } label: {
                Label("Manuell erfassen", systemImage: "calendar.badge.plus")
            }
            .tint(.green)
        }
    }

    // MARK: - Inaktive Sektion

    @ViewBuilder
    private var inaktiveSektion: some View {
        Section("Pausiert / Abgesetzt") {
            ForEach(inaktive) { med in
                MedikamentZeile(medikament: med, notif: notif)
                    .contentShape(Rectangle())
                    .onTapGesture { zuBearbeiten = med }
                    .opacity(0.6)
            }
            .onDelete { loeschen(aus: inaktive, offsets: $0) }
        }
    }

    // MARK: - Warnungen

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
                    if let ablauf = med.ablaufDatum {
                        let tage = kal.dateComponents([.day], from: heute,
                            to: kal.startOfDay(for: ablauf)).day ?? 0
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
            Section("Wirksamkeit bewerten") {
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
            }
        }
    }

    private func wirkungsButton(log: EinnahmeLog, wert: String, label: String, farbe: Color) -> some View {
        let ausgewaehlt = log.wirkung == wert
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { log.wirkung = wert }
        } label: {
            HStack(spacing: 4) {
                if ausgewaehlt { Image(systemName: "checkmark").font(.caption2.bold()) }
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
                        .font(.subheadline.bold()).foregroundStyle(.orange)
                    Text("Häufiger Gebrauch von Schmerzmedikamenten kann Übergebrauchskopfschmerzen verursachen. Bitte sprich mit deinem Arzt.")
                        .font(.caption).foregroundStyle(.secondary)
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

    // MARK: - Einnahme-Kontrolle

    @ViewBuilder
    private func einnahmeKontrolle(med: Dauermedikation) -> some View {
        if med.frequenz == "Wöchentlich" || med.frequenz == "Monatlich" {
            let intervall = med.frequenz == "Monatlich" ? 30 : 7
            let letzteEinnahme = logs.first { $0.medikamentName == med.name && $0.dosierung == med.dosierung && $0.eingenommen }
            let tageSeit: Int? = letzteEinnahme.map {
                max(0, Calendar.current.dateComponents([.day], from: $0.datum, to: Date()).day ?? 0)
            }
            HStack(spacing: 8) {
                if let tage = tageSeit {
                    VStack(alignment: .trailing, spacing: 1) {
                        if tage == 0 {
                            Text("Heute").font(.caption).foregroundStyle(.green)
                        } else if tage < intervall {
                            Text("Vor \(tage)T").font(.caption2).foregroundStyle(.secondary)
                            Text("In \(intervall - tage)T")
                                .font(.caption).foregroundStyle(tage >= intervall - 1 ? .orange : .blue)
                        } else {
                            Text("Fällig!").font(.caption.bold()).foregroundStyle(.orange)
                        }
                    }
                } else {
                    Text("Noch nicht erfasst").font(.caption).foregroundStyle(.secondary)
                }
                if tageSeit == nil || (tageSeit ?? 0) >= 1 {
                    Button { medZuLoggen = med } label: {
                        Image(systemName: med.typSymbol).font(.title3).foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            let anzahlErwartet = notif.anzahlDosen(med.frequenz)
            let anzahlHeute = heutigeLogs.filter {
                $0.medikamentName == med.name && $0.dosierung == med.dosierung
            }.count

            if anzahlErwartet == 0 {
                HStack(spacing: 8) {
                    if anzahlHeute > 0 {
                        Text("\(anzahlHeute)×").font(.caption).foregroundStyle(.secondary)
                    }
                    Button { loggeMedikament(med) } label: {
                        Image(systemName: "plus.circle").font(.title3).foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
            } else {
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

// MARK: - Zeile (Pausiert / Abgesetzt)

private struct MedikamentZeile: View {
    let medikament: Dauermedikation
    let notif: NotificationManager

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: medikament.typSymbol)
                .foregroundStyle(medikament.aktiv ? .blue : .secondary)
                .font(.body)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(medikament.name).font(.subheadline).fontWeight(.medium)
                    if medikament.erinnerungAktiv {
                        Image(systemName: "bell.fill").font(.caption2).foregroundStyle(.orange)
                    }
                    if !medikament.aktiv {
                        Text("Pausiert")
                            .font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(Capsule())
                            .foregroundStyle(.secondary)
                    }
                }
                if !medikament.dosierung.isEmpty {
                    Text(medikament.dosierung).font(.caption).foregroundStyle(.secondary)
                }
                let zeiten = notif.gueltigeZeiten(fuer: medikament)
                let zeitText = zeiten.isEmpty ? medikament.frequenz : zeiten.map(\.anzeigeText).joined(separator: ", ")
                if !zeitText.isEmpty {
                    Label(zeitText, systemImage: "clock").font(.caption2).foregroundStyle(.tertiary)
                }
                if !medikament.aktiv, let ende = medikament.endDatum {
                    Label(ende.formatted(.dateTime.day().month(.abbreviated).year()),
                          systemImage: "calendar.badge.minus")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Formular (Wizard)

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
    @State private var schritt = 0

    private let notif = NotificationManager.shared
    private let maxSchritt = 2
    private let pflichtSchritte: Set<Int> = [0, 1]

    private let frequenzOptionen = [
        "1× täglich", "2× täglich", "3× täglich",
        "Morgens", "Abends", "Morgens & Abends",
        "Bei Bedarf", "Wöchentlich", "Monatlich"
    ]
    private let hinweisOptionen = [
        "", "Mit Essen", "Nüchtern", "Mit viel Wasser",
        "Vor dem Schlafen", "Morgens nüchtern", "Mit Milch"
    ]

    private var anzahlZeiten: Int { notif.anzahlDosen(frequenz) }

    private var kannWeiter: Bool {
        switch schritt {
        case 0: return !name.trimmingCharacters(in: .whitespaces).isEmpty
        case 1: return !frequenz.isEmpty
        default: return true
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.blue.opacity(0.15)).frame(height: 3)
                        Capsule().fill(Color.blue)
                            .frame(width: geo.size.width * CGFloat(schritt + 1) / CGFloat(maxSchritt + 1), height: 3)
                            .animation(.easeInOut(duration: 0.3), value: schritt)
                    }
                }
                .frame(height: 3)
                .padding(.horizontal)
                .padding(.top, 10)

                Group {
                    switch schritt {
                    case 0: schritt0
                    case 1: schritt1
                    default: schritt2
                    }
                }
                .frame(maxHeight: .infinity)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))

                navigationsLeiste
            }
            .navigationTitle(medikament == nil ? "Neues Medikament" : "Medikament bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
            }
            .onAppear { ladeWerte() }
        }
    }

    // MARK: - Schritt 0: Medikament

    private var schritt0: some View {
        ScrollView {
            VStack(spacing: 20) {
                schrittHeader(symbol: "pill.fill", titel: "Medikament", untertitel: "Name, Typ und Einnahmehinweis")

                VStack(spacing: 0) {
                    TextField("Name (z.B. Ibuprofen)", text: $name)
                        .font(.subheadline).padding(16)
                    Divider().padding(.leading, 16)
                    TextField("Dosierung (z.B. 400 mg)", text: $dosierung)
                        .font(.subheadline).padding(16)
                }
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 10) {
                    Text("Art").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                        ForEach(MedikamentTyp.allCases, id: \.rawValue) { typ in
                            let ausgewaehlt = medikamentTyp == typ.rawValue
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) { medikamentTyp = typ.rawValue }
                                if typ.istInjektion { wirkungsAbfrageStunden = 24 }
                                else if wirkungsAbfrageStunden == 24 { wirkungsAbfrageStunden = 2 }
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: typ.symbol)
                                        .font(.title3)
                                        .foregroundStyle(ausgewaehlt ? .white : .blue)
                                    Text(typ.rawValue)
                                        .font(.caption2)
                                        .foregroundStyle(ausgewaehlt ? .white : .primary)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(ausgewaehlt ? Color.blue : Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .animation(.easeInOut(duration: 0.15), value: ausgewaehlt)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Einnahmehinweis").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(hinweisOptionen, id: \.self) { opt in
                                let ausgewaehlt = einnahmeHinweis == opt
                                Button {
                                    withAnimation(.easeInOut(duration: 0.15)) { einnahmeHinweis = opt }
                                } label: {
                                    Text(opt.isEmpty ? "Kein Hinweis" : opt)
                                        .font(.caption.bold())
                                        .padding(.horizontal, 12).padding(.vertical, 7)
                                        .background(ausgewaehlt ? Color.blue : Color(.secondarySystemGroupedBackground))
                                        .foregroundStyle(ausgewaehlt ? .white : .primary)
                                        .clipShape(Capsule())
                                        .animation(.easeInOut(duration: 0.15), value: ausgewaehlt)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Schritt 1: Einnahme

    private var schritt1: some View {
        ScrollView {
            VStack(spacing: 20) {
                schrittHeader(symbol: "calendar.badge.clock", titel: "Einnahme", untertitel: "Frequenz und Startdatum")

                VStack(alignment: .leading, spacing: 10) {
                    Text("Wie oft?").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                        ForEach(frequenzOptionen, id: \.self) { opt in
                            let ausgewaehlt = frequenz == opt
                            Button {
                                let alt = frequenz
                                frequenz = opt
                                if medikament == nil || !alt.isEmpty { aktualisiereStandardZeiten(opt) }
                            } label: {
                                Text(opt)
                                    .font(.caption.bold())
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 11)
                                    .background(ausgewaehlt ? Color.blue : Color(.secondarySystemGroupedBackground))
                                    .foregroundStyle(ausgewaehlt ? .white : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .animation(.easeInOut(duration: 0.15), value: ausgewaehlt)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(spacing: 0) {
                    HStack {
                        DatePicker("Seit", selection: $startDatum, displayedComponents: .date)
                            .font(.subheadline)
                    }
                    .padding(16)
                    Divider().padding(.leading, 16)
                    Toggle("Aktiv / Wird eingenommen", isOn: $aktiv)
                        .font(.subheadline).padding(16)
                    if !aktiv {
                        Divider().padding(.leading, 16)
                        DatePicker("Abgesetzt am", selection: $endDatum, displayedComponents: .date)
                            .font(.subheadline).padding(16)
                    }
                }
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))

                if !frequenz.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Wirksamkeits-Abfrage").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
                        HStack(spacing: 8) {
                            ForEach([(2, "Nach 2 Std."), (24, "Nach 24 Std."), (48, "Nach 48 Std.")], id: \.0) { std, label in
                                let ausgewaehlt = wirkungsAbfrageStunden == std
                                Button { wirkungsAbfrageStunden = std } label: {
                                    Text(label)
                                        .font(.caption.bold())
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(ausgewaehlt ? Color.blue : Color(.secondarySystemGroupedBackground))
                                        .foregroundStyle(ausgewaehlt ? .white : .primary)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .animation(.easeInOut(duration: 0.15), value: ausgewaehlt)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Schritt 2: Extras

    private var schritt2: some View {
        ScrollView {
            VStack(spacing: 20) {
                schrittHeader(symbol: "bell.badge.fill", titel: "Extras", untertitel: "Erinnerungen, Vorrat & Ablaufdatum")

                if !frequenz.isEmpty && frequenz != "Bei Bedarf" {
                    VStack(spacing: 0) {
                        Toggle(isOn: $erinnerungAktiv) {
                            Label("Push-Erinnerung", systemImage: "bell.badge").font(.subheadline)
                        }
                        .padding(16)
                        .onChange(of: erinnerungAktiv) { _, an in
                            if an && notif.status == .notDetermined {
                                Task { await notif.berechtigungAnfordern() }
                            }
                        }
                        if erinnerungAktiv {
                            ForEach(0..<max(1, anzahlZeiten), id: \.self) { i in
                                if i < erinnerungsZeiten.count {
                                    Divider().padding(.leading, 16)
                                    DatePicker(
                                        anzahlZeiten > 1 ? "Zeit \(i + 1)" : "Uhrzeit",
                                        selection: $erinnerungsZeiten[i],
                                        displayedComponents: .hourAndMinute
                                    )
                                    .font(.subheadline).padding(16)
                                }
                            }
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                }

                VStack(spacing: 0) {
                    Toggle("Vorrat verfolgen", isOn: $vorratAktiv)
                        .font(.subheadline).padding(16)
                    if vorratAktiv {
                        Divider().padding(.leading, 16)
                        Stepper("Aktueller Vorrat: \(vorratAnzahl)", value: $vorratAnzahl, in: 0...999)
                            .font(.subheadline).padding(16)
                        Divider().padding(.leading, 16)
                        Stepper("Warnung ab: \(vorratSchwelle) Stück", value: $vorratSchwelle, in: 1...99)
                            .font(.subheadline).padding(16)
                    }
                }
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))

                VStack(spacing: 0) {
                    Toggle("Ablaufdatum setzen", isOn: $ablaufAktiv)
                        .font(.subheadline).padding(16)
                    if ablaufAktiv {
                        Divider().padding(.leading, 16)
                        DatePicker("Ablaufdatum", selection: $ablaufDatumState, displayedComponents: .date)
                            .font(.subheadline).padding(16)
                    }
                }
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
            .padding(.vertical, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Navigation

    private var navigationsLeiste: some View {
        HStack(spacing: 12) {
            if schritt > 0 {
                Button {
                    withAnimation { schritt -= 1 }
                } label: {
                    Text("Zurück")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }

            if !pflichtSchritte.contains(schritt) && schritt < maxSchritt {
                Button { withAnimation { schritt += 1 } } label: {
                    Text("Überspringen")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }

            if schritt < maxSchritt {
                Button {
                    guard kannWeiter else { return }
                    withAnimation { schritt += 1 }
                } label: {
                    Text("Weiter ›")
                        .font(.subheadline.bold()).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(kannWeiter ? Color.blue : Color.secondary, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(!kannWeiter)
            } else {
                Button { speichern() } label: {
                    Label("Speichern", systemImage: "checkmark")
                        .font(.subheadline.bold()).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color.blue, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || frequenz.isEmpty)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    // MARK: - Header Helper

    private func schrittHeader(symbol: String, titel: String, untertitel: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 32)).foregroundStyle(.blue)
            Text(titel).font(.title3.bold())
            Text(untertitel).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 4)
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
        if frequenz == "Monatlich" {
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

struct EinnahmeLogSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \EinnahmeLog.datum, order: .reverse) private var logs: [EinnahmeLog]

    let med: Dauermedikation
    private let notif = NotificationManager.shared

    @State private var logDatum = Date()
    @State private var notizen = ""
    @State private var fehlende: [Date] = []

    private var istWöchentlich: Bool { med.frequenz == "Wöchentlich" }
    private var istMonatlich: Bool { med.frequenz == "Monatlich" }
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
                    if istWöchentlich || istMonatlich {
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
                if !istBeiBedarfs && !istWöchentlich && !istMonatlich && !fehlende.isEmpty {
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
        guard !istBeiBedarfs && !istWöchentlich && !istMonatlich else { return }
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
    @State private var erstellePDF = false

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
            .onDelete { idx in
                idx.forEach {
                    NotificationManager.shared.loescheWirkungsAbfrage(fuer: logs[$0])
                    modelContext.delete(logs[$0])
                }
            }
        }
        .navigationTitle("Einnahme-Verlauf")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if erstellePDF {
                    ProgressView()
                } else {
                    Button {
                        erstellePDF = true
                        PDFExportService.shared.erstelleMedikamentenZusammenfassung(
                            medikamente: Array(medikamente),
                            logs: Array(logs),
                            profil: profile.first
                        ) { url in
                            erstellePDF = false
                            if let url {
                                pdfURL = url
                                zeigePDFShare = true
                            }
                        }
                    } label: {
                        Label("Arztbesuch-PDF", systemImage: "doc.richtext")
                    }
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

