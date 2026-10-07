import SwiftUI
import SwiftData

/// Zyklus-Tracker: Frosted-Glass-Karten über sanftem Rosé/Pfirsich/Lavendel-Verlauf.
/// Drei Ansichten: Heute (Phasen-Ring + Prognose), Monat (Band-Kalender), Verlauf (Zyklenliste).
struct ZyklusView: View {
    @Query(sort: \ZyklusEintrag.datum, order: .reverse) private var eintraege: [ZyklusEintrag]
    @Environment(\.modelContext) private var modelContext
    @Query private var schmerzEintraege: [PainEntry]
    @Query private var profile: [Benutzerprofil]
    @State private var berichtURL: URL? = nil
    @State private var zeigeBericht = false
    @State private var berichtLaeuft = false
    @AppStorage("zyklusPrognosenPausiert") private var pausiert = false

    enum Ansicht: String, CaseIterable, Identifiable {
        case heute = "Heute"
        case monat = "Monat"
        case verlauf = "Verlauf"
        var id: String { rawValue }
    }

    @State private var ansicht: Ansicht = .heute
    @State private var anzeigeMonat = Date()
    @State private var ausgewaehlterTag: ZyklusTagAuswahl? = nil
    @State private var zeigeAnalyse = false
    @State private var ringAuswahl: Int? = nil
    @State private var monatsAuswahl: Date? = nil
    @State private var notifManager = NotificationManager.shared
    @State private var healthLaeuft = false
    @State private var healthMeldung: String? = nil

    private var kal: Calendar { Calendar.current }

    /// Pro Kalendertag alle Einträge zusammengeführt (Duplikate gehen so nicht verloren).
    private var eintraegeProTag: [Date: ZyklusTagesSicht] {
        Dictionary(grouping: eintraege) { $0.tag.beginn(in: kal.timeZone) }
            .mapValues { ZyklusTagesSicht($0) }
    }

    var body: some View {
        let analyse = ZyklusRechner.analyse(eintraege: Array(eintraege))
        let proTag = eintraegeProTag

        ScrollView {
            VStack(spacing: 16) {
                Picker("Ansicht", selection: $ansicht) {
                    ForEach(Ansicht.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                switch ansicht {
                case .heute:   heuteInhalt(analyse, proTag)
                case .monat:   monatsInhalt(analyse, proTag)
                case .verlauf: verlaufInhalt(analyse)
                }

                erinnerungsBanner(analyse)

                Text("Prognosen sind statistische Schätzungen aus deinen Einträgen. Sie ersetzen weder Verhütung noch ärztliche Beratung.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background { ZyklusHintergrund() }
        .environment(\.locale, ZyklusLocale.de)
        .navigationTitle("Zyklus")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { menue(analyse) }
            ToolbarItem(placement: .primaryAction) {
                Button { oeffneHeuteSheet() } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Heute erfassen")
            }
        }
        .sheet(item: $ausgewaehlterTag) { auswahl in
            ZyklusEintragSheet(
                datum: auswahl.datum,
                bestehend: eintraege.first { $0.tag == DayKey(auswahl.datum, zeitzone: kal.timeZone) }
            )
        }
        .sheet(isPresented: $zeigeAnalyse) { ZyklusAnalyseView() }
#if os(iOS)
        .sheet(isPresented: $zeigeBericht) {
            if let url = berichtURL { PDFPreviewView(url: url) }
        }
#endif
        .alert("Apple Health",
               isPresented: Binding(get: { healthMeldung != nil },
                                    set: { if !$0 { healthMeldung = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(healthMeldung ?? "")
        }
        // Signatur statt Array-Vergleich: erkennt auch Änderungen an bestehenden Einträgen.
        .onChange(of: ZyklusRechner.signatur(Array(eintraege))) { _, _ in planeZyklusNotifs() }
        .onAppear { planeZyklusNotifs() }
    }

    // MARK: - Menü

    private func menue(_ analyse: ZyklusAnalyse) -> some View {
        Menu {
            Button {
                Task { await healthAbgleich() }
            } label: {
                Label("Mit Apple Health abgleichen", systemImage: "heart.text.square")
            }
            .disabled(healthLaeuft || !ZyklusHealthKitService.shared.istVerfuegbar)

            Toggle(isOn: $pausiert) {
                Label("Prognosen pausieren", systemImage: "pause.circle")
            }

            if !analyse.zyklusStarts.isEmpty {
                Button { erstelleZyklusBericht() } label: {
                    Label("Zyklus-Arztbericht (PDF)", systemImage: "doc.text")
                }
                .disabled(berichtLaeuft)
                Button { zeigeAnalyse = true } label: {
                    Label("Zyklusanalyse", systemImage: "chart.bar.xaxis.ascending")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("Weitere Optionen")
    }

    /// Arztbericht nur mit dem Zyklus-Teil (Statistik, Vorhersagen, Zyklushistorie, Symptome, Schmerz je Phase).
    private func erstelleZyklusBericht() {
#if os(iOS)
        berichtLaeuft = true
        var optionen = ExportOptionen()
        optionen.zeitraum = .alles
        optionen.mitZusammenfassung = false
        optionen.mitMedikamente = false
        optionen.mitMedikamentDossier = false
        optionen.mitEintraege = false
        optionen.mitErnaehrung = false
        optionen.mitRheuma = false
        optionen.mitMigraene = false
        optionen.mitZyklus = true
        PDFExportService.shared.erstellePDFAsync(
            eintraege: Array(schmerzEintraege),
            medikamente: [],
            midasBewertungen: [],
            zyklusEintraege: Array(eintraege),
            profil: profile.first,
            optionen: optionen
        ) { @MainActor url in
            berichtLaeuft = false
            if let url { berichtURL = url; zeigeBericht = true }
        }
#endif
    }

    private func healthAbgleich() async {
        healthLaeuft = true
        let ergebnis = await ZyklusHealthKitService.shared.abgleichen(
            context: modelContext, eintraege: Array(eintraege))
        healthLaeuft = false
        var text = "\(ergebnis.importiert) Werte importiert, \(ergebnis.exportiert) Einträge nach Health geschrieben."
        if let fehler = ergebnis.fehler { text += "\n" + fehler }
        healthMeldung = text
    }

    private func planeZyklusNotifs() {
        NotificationManager.shared.planeZyklusErinnerungen(eintraege: Array(eintraege))
        ZyklusWidgetService.aktualisieren(eintraege: Array(eintraege), pausiert: pausiert)
    }

    private func oeffneHeuteSheet() {
        ausgewaehlterTag = ZyklusTagAuswahl(datum: kal.startOfDay(for: Date()))
    }

    private func wechselMonat(_ richtung: Int) {
        withAnimation {
            anzeigeMonat = kal.date(byAdding: .month, value: richtung, to: anzeigeMonat) ?? anzeigeMonat
        }
    }

    private func tageBis(_ datum: Date) -> Int {
        kal.dateComponents([.day], from: kal.startOfDay(for: Date()), to: kal.startOfDay(for: datum)).day ?? 0
    }

    // MARK: - Heute

    @ViewBuilder
    private func heuteInhalt(_ analyse: ZyklusAnalyse, _ proTag: [Date: ZyklusTagesSicht]) -> some View {
        if analyse.zyklusStarts.isEmpty {
            leerKarte
        } else if pausiert {
            pausiertKarte
        } else {
            ringKarte(analyse)
            if analyse.status != .normal { statusKarte(analyse) }
            prognoseReihe(analyse)
        }

        erfassenKarte(proTag)

        if !analyse.zyklusStarts.isEmpty {
            statistikKarte(analyse)
            analyseButton
        }
    }

    private var leerKarte: some View {
        VStack(spacing: 12) {
            Image(systemName: "drop.fill")
                .font(.system(size: 40)).foregroundStyle(.pink)
            Text("Noch keine Zyklusdaten").font(.headline)
            Text("Trage den ersten Tag deiner Periode ein. Nach wenigen Zyklen lernt die App deinen persönlichen Rhythmus.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button { oeffneHeuteSheet() } label: {
                Label("Heute erfassen", systemImage: "plus")
                    .font(.subheadline.bold()).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Color.pink, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .zyklusGlas()
    }

    private var pausiertKarte: some View {
        VStack(spacing: 10) {
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 34)).foregroundStyle(.pink)
            Text("Prognosen pausiert").font(.headline)
            Text("Es werden keine Perioden-, Eisprung- oder Fruchtbarkeits-Prognosen angezeigt (z. B. bei Schwangerschaft, hormoneller Verhütung oder Stillzeit). Deine Einträge bleiben erhalten.")
                .font(.footnote).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Prognosen fortsetzen") { pausiert = false }
                .buttonStyle(.borderedProminent).tint(.pink)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .zyklusGlas()
    }

    private func ringKarte(_ analyse: ZyklusAnalyse) -> some View {
        VStack(spacing: 12) {
            ZyklusRingView(analyse: analyse, untertitel: ringUntertitel(analyse), auswahl: $ringAuswahl)
                .frame(maxWidth: 300)
                .padding(.top, 4)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 6)], alignment: .leading, spacing: 6) {
                legendenPunkt(ZyklusFarbe.periode, "Periode")
                legendenPunkt(ZyklusFarbe.follikel, "Follikel")
                legendenPunkt(ZyklusFarbe.fruchtbar, "Fruchtbar")
                legendenPunkt(ZyklusFarbe.eisprung, "Eisprung")
                legendenPunkt(ZyklusFarbe.luteal, "Luteal")
            }
            .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .zyklusGlas()
    }

    private func legendenPunkt(_ farbe: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(farbe).frame(width: 8, height: 8)
            Text(text)
        }
    }

    private func ringUntertitel(_ a: ZyklusAnalyse) -> String {
        switch a.status {
        case .keineAktuellenDaten:
            return "Keine aktuellen Daten"
        case .ueberfaellig(let tage):
            return tage == 1 ? "Periode 1 Tag überfällig" : "Periode \(tage) Tage überfällig"
        case .normal:
            if let ov = a.vorhergesagteOvulation, a.naechstePeriodeStart.map({ ov < $0 }) ?? true {
                let t = tageBis(ov)
                if t <= 0 { return "Eisprung heute erwartet" }
                if t == 1 { return "Eisprung morgen erwartet" }
                return "Eisprung in ca. \(t) Tagen"
            }
            if let np = a.naechstePeriodeStart {
                let t = tageBis(np)
                if t <= 0 { return "Periode heute erwartet" }
                return t == 1 ? "Periode morgen erwartet" : "Periode in \(t) Tagen"
            }
            return ""
        }
    }

    private func statusKarte(_ a: ZyklusAnalyse) -> some View {
        let text: String
        switch a.status {
        case .ueberfaellig(let tage):
            text = tage >= 7
                ? "Deine Periode ist seit \(tage) Tagen überfällig. Trage sie ein, sobald sie beginnt – die Prognose passt sich dann an."
                : "Deine Periode ist etwas später als erwartet. Zyklen schwanken natürlicherweise um einige Tage."
        case .keineAktuellenDaten:
            text = "Dein letzter erfasster Zyklusstart liegt über 90 Tage zurück. Für neue Prognosen trage bitte die nächste Periode ein."
        case .normal:
            text = ""
        }
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
            Text(text).font(.footnote).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .zyklusGlas(radius: 18)
    }

    // MARK: Prognose-Karten

    private func prognoseReihe(_ a: ZyklusAnalyse) -> some View {
        HStack(alignment: .top, spacing: 12) {
            periodeKarte(a)
            fruchtbarKarte(a)
        }
    }

    private func periodeKarte(_ a: ZyklusAnalyse) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NÄCHSTE PERIODE")
                .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            if case .ueberfaellig(let tage) = a.status {
                Text("Überfällig").font(.title3.bold()).foregroundStyle(.orange)
                Text(tage == 1 ? "seit 1 Tag" : "seit \(tage) Tagen")
                    .font(.caption).foregroundStyle(.secondary)
            } else if let np = a.naechstePeriodeStart {
                Text(np, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                    .font(.title3.bold())
                let t = tageBis(np)
                Text(t <= 0 ? "heute" : "in \(t) \(t == 1 ? "Tag" : "Tagen") · ± \(a.unsicherheitTage) T.")
                    .font(.caption).foregroundStyle(.secondary)
                ZyklusUnsicherheitsBand(spanne: a.unsicherheitTage, farbe: ZyklusFarbe.periode)
                    .padding(.top, 4)
            } else {
                Text("–").font(.title3.bold())
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .zyklusGlas(radius: 20)
        .accessibilityElement(children: .combine)
    }

    private func fruchtbarKarte(_ a: ZyklusAnalyse) -> some View {
        let konf = konfidenz(a)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 2) {
                Text("FRUCHTBARES FENSTER")
                    .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    .lineLimit(2)
                InfoButton(titel: "Fruchtbares Fenster",
                           text: "Die 6 Tage bis einschließlich Eisprungtag (Spermien überleben bis zu 5 Tage, die Eizelle 12–24 Stunden). Die Prognose nutzt – in dieser Reihenfolge – BBT-Anstieg, positiven LH-Test, Schleim-Peak und zuletzt den Kalender (nächste Periode minus persönliche Lutealphase). Kommt die Periode früher oder später, verschiebt sich alles automatisch. Ohne Belege sind hellere Randtage um das Fenster möglich; so breit wie dein typischer Prognosefehler. Keine Verhütungsmethode.")
            }
            if let f = a.naechstesFruchtbaresFenster {
                Text(fensterText(f))
                    .font(.title3.bold())
                    .minimumScaleFactor(0.8).lineLimit(1)
            } else {
                Text("–").font(.title3.bold())
            }
            Text(konf.text)
                .font(.caption2.bold())
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(konf.farbe.opacity(0.18), in: Capsule())
                .foregroundStyle(konf.farbe)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .zyklusGlas(radius: 20)
    }

    private func fensterText(_ f: ClosedRange<Date>) -> String {
        let von = f.lowerBound, bis = f.upperBound
        if kal.isDate(von, equalTo: bis, toGranularity: .month) {
            let tagVon = von.formatted(.dateTime.day().locale(ZyklusLocale.de))
            return "\(tagVon)–\(bis.formatted(.dateTime.day().month(.abbreviated).locale(ZyklusLocale.de)))"
        }
        return "\(von.formatted(.dateTime.day().month(.abbreviated).locale(ZyklusLocale.de))) – \(bis.formatted(.dateTime.day().month(.abbreviated).locale(ZyklusLocale.de)))"
    }

    private func konfidenz(_ a: ZyklusAnalyse) -> (text: String, farbe: Color) {
        if a.datenQualitaet == .standardwert { return ("Schätzung", .secondary) }
        if a.eisprungBestaetigt { return ("Bestätigt", .teal) }
        if a.regelmaessigkeit == .unregelmaessig { return ("Konfidenz niedrig", .orange) }
        if a.regelmaessigkeit == .regelmaessig && a.datenQualitaet >= .gut { return ("Konfidenz hoch", .teal) }
        return ("Konfidenz mittel", .orange)
    }

    // MARK: Erfassen / Statistik

    private func erfassenKarte(_ proTag: [Date: ZyklusTagesSicht]) -> some View {
        let heute = proTag[kal.startOfDay(for: Date())]
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("HEUTE ERFASSEN")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Button("Alle Felder") { oeffneHeuteSheet() }
                    .font(.caption.weight(.semibold)).foregroundStyle(.pink)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                chip("Blutung", "drop.fill", aktiv: heute?.hatBlutung ?? false)
                chip("Schleim", "water.waves", aktiv: (heute?.schleim ?? .keine) != .keine)
                chip("LH-Test", "testtube.2", aktiv: (heute?.lhTest ?? .keine) != .keine)
                chip(heute.map { $0.basaltemperatur > 0 ? String(format: "%.2f°", $0.basaltemperatur) : "Temperatur" } ?? "Temperatur",
                     "thermometer.medium", aktiv: (heute?.basaltemperatur ?? 0) > 0)
                chip("Symptome", "heart.text.square", aktiv: !(heute?.symptome.isEmpty ?? true))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .zyklusGlas(radius: 20)
    }

    private func chip(_ titel: String, _ symbol: String, aktiv: Bool) -> some View {
        Button { oeffneHeuteSheet() } label: {
            Label(titel, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .foregroundStyle(aktiv ? Color.white : Color.primary)
                .background(aktiv ? Color.pink : Color.white.opacity(0.35), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityValue(aktiv ? "erfasst" : "offen")
    }

    private func statistikKarte(_ a: ZyklusAnalyse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Zyklus-Überblick", systemImage: "drop.fill")
                .font(.headline).foregroundStyle(.pink)
            Divider()
            HStack(spacing: 0) {
                statPill(a.aktuellerZyklustag.map { "Tag \($0)" } ?? "–", label: "Zyklustag",
                         farbe: a.aktuellerZyklustag != nil ? .pink : .secondary)
                Divider().frame(height: 40)
                statPill(a.gueltigeZyklen > 0 ? "\(Int(a.medianZykluslaenge.rounded())) T" : "–",
                         label: "Ø Zyklus (Median)", farbe: .pink)
                Divider().frame(height: 40)
                statPill("\(Int(a.adaptiertePeriodendauer.rounded())) T",
                         label: "Ø Periode", farbe: ZyklusFarbe.periode)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .zyklusGlas()
    }

    private func statPill(_ wert: String, label: String, farbe: Color) -> some View {
        VStack(spacing: 4) {
            Text(wert).font(.title2.bold()).foregroundStyle(farbe)
            Text(label).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var analyseButton: some View {
        Button { zeigeAnalyse = true } label: {
            Label("Zyklusanalyse öffnen", systemImage: "chart.bar.xaxis.ascending")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.pink, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Monat

    @ViewBuilder
    private func monatsInhalt(_ analyse: ZyklusAnalyse, _ proTag: [Date: ZyklusTagesSicht]) -> some View {
        if !kal.isDate(anzeigeMonat, equalTo: Date(), toGranularity: .month) || monatsAuswahl != nil {
            HStack {
                Spacer()
                Button {
                    withAnimation {
                        anzeigeMonat = Date()
                        monatsAuswahl = nil
                    }
                } label: {
                    Label("Heute", systemImage: "arrow.uturn.backward.circle.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.pink)
            }
        }

        ZyklusKalenderView(
            monat: anzeigeMonat,
            eintraegeProTag: proTag,
            analyse: analyse,
            zeigePrognosen: !pausiert,
            ausgewaehlterTag: monatsAuswahl,
            onVorheriger: { wechselMonat(-1) },
            onNaechster: { wechselMonat(1) }
        ) { tag in
            withAnimation(.easeInOut(duration: 0.15)) {
                monatsAuswahl = (monatsAuswahl.map { kal.isDate($0, inSameDayAs: tag) } ?? false) ? nil : tag
            }
        }
        .zyklusGlas()

        if let tag = monatsAuswahl {
            tagesKarte(tag, analyse, proTag)
                .transition(.opacity)
        }

        kalenderLegende
    }

    /// Detailkarte zum angetippten Kalendertag: Zyklustag, Phase, Status und erfasste Werte.
    private func tagesKarte(_ tag: Date, _ analyse: ZyklusAnalyse, _ proTag: [Date: ZyklusTagesSicht]) -> some View {
        let start = kal.startOfDay(for: tag)
        let heute = kal.startOfDay(for: Date())
        let eintrag = proTag[start]
        let zustand = ZyklusRechner.tagZustand(datum: start, analyse: analyse, kalender: kal)
        let prognosenAn = !pausiert

        // Phase nur innerhalb des bekannten Zyklus — für Tage nach der erwarteten nächsten Periode wäre sie falsch.
        let imBekanntenZyklus = start <= heute || (analyse.naechstePeriodeStart.map { start < $0 } ?? false)
        let phase: ZyklusRechner.Zyklusphase? = imBekanntenZyklus
            ? ZyklusRechner.phase(for: start, analyse: analyse, kalender: kal) : nil
        let zyklusTag: Int? = phase == nil ? nil : analyse.zyklusStarts.last(where: { $0 <= start })
            .map { (kal.dateComponents([.day], from: $0, to: start).day ?? 0) + 1 }

        var badges: [(String, Color)] = []
        if zustand.periode {
            let fluss = eintrag?.fluss ?? .keine
            badges.append((fluss == .keine ? "Periode" : "Periode · \(fluss.titel)", ZyklusFarbe.periode))
        }
        if prognosenAn && zustand.vorhergesagtePeriode { badges.append(("Periode erwartet", ZyklusFarbe.periode)) }
        if prognosenAn && zustand.ovulation {
            let q = analyse.zyklen.first(where: { $0.eisprung.map { kal.isDate($0, inSameDayAs: start) } ?? false })?.eisprungQuelle
            let zusatz = q.map { $0.istBestaetigt ? " · bestätigt" : ($0 == .kalender ? " · geschätzt" : " · \($0.titel)") } ?? ""
            badges.append(("Eisprung\(zusatz)", ZyklusFarbe.eisprung))
        }
        if prognosenAn && zustand.fruchtbar { badges.append(("Fruchtbar", ZyklusFarbe.fruchtbar)) }

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(start, format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(.subheadline.bold())
                    if let n = zyklusTag, let p = phase {
                        Text("Zyklustag \(n) · \(p.rawValue)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(ZyklusFarbe.farbe(p))
                    } else {
                        Text(start > heute ? "Prognose" : "Außerhalb eines Zyklus")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button { ausgewaehlterTag = ZyklusTagAuswahl(datum: start) } label: {
                    Text(eintrag == nil ? "Erfassen" : "Bearbeiten")
                        .font(.caption.bold()).foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Color.pink, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            if start <= heute && (zustand.ovulation || zustand.fruchtbar) {
                let bestaetigt = eintrag?.eisprungBestaetigt ?? false
                Button { eisprungUmschalten(an: start) } label: {
                    Label(bestaetigt ? "Eisprung-Bestätigung entfernen" : "Eisprung an diesem Tag bestätigen",
                          systemImage: bestaetigt ? "xmark.circle" : "checkmark.seal.fill")
                        .font(.caption.bold())
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(ZyklusFarbe.eisprung.opacity(0.18), in: Capsule())
                        .foregroundStyle(ZyklusFarbe.eisprung)
                }
                .buttonStyle(.plain)
            }

            if !badges.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 6)], alignment: .leading, spacing: 6) {
                    ForEach(Array(badges.enumerated()), id: \.offset) { _, b in
                        Text(b.0)
                            .font(.caption2.bold())
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(b.1.opacity(0.18), in: Capsule())
                            .foregroundStyle(b.1)
                    }
                }
            }

            if let e = eintrag {
                VStack(alignment: .leading, spacing: 3) {
                    if e.schleim != .keine { Text("Zervixschleim: \(e.schleim.titel)") }
                    if e.lhTest != .keine { Text("Ovulationstest: \(e.lhTest.titel)") }
                    if e.basaltemperatur > 0 { Text("Basaltemperatur: \(String(format: "%.2f", e.basaltemperatur)) °C") }
                    if !e.symptome.isEmpty { Text("Symptome: \(ListenFeld.parse(e.symptome).joined(separator: ", "))") }
                    if e.sexAktivitaet != .keine { Text("Sexuelle Aktivität: \(e.sexAktivitaet.titel)") }
                    if !e.notizen.isEmpty { Text(e.notizen).lineLimit(2) }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else if badges.isEmpty {
                Text("Kein Eintrag").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .zyklusGlas(radius: 20)
    }

    /// Setzt/entfernt die manuelle Eisprung-Bestätigung am Tag; der Eisprung ist ein Datum je Zyklus,
    /// daher wird eine Bestätigung im selben Zyklus vorher entfernt.
    private func eisprungUmschalten(an tag: Date) {
        let key = DayKey(tag, zeitzone: kal.timeZone)
        let bestehend = eintraege.first { $0.tag == key }
        if let e = bestehend, e.eisprungBestaetigt {
            e.eisprungBestaetigt = false
            if e.istLeerNachBestaetigung { NotificationManager.shared.planeZyklusErinnerungen(eintraege: eintraege.filter { $0 !== e }); modelContext.delete(e); return }
        } else {
            let analyse = ZyklusRechner.analyse(eintraege: Array(eintraege))
            let start = analyse.zyklusStarts.last(where: { $0 <= tag })
            let ende = analyse.zyklusStarts.first(where: { $0 > tag })
            for e in eintraege where e.eisprungBestaetigt {
                let d = kal.startOfDay(for: e.tag.beginn(in: kal.timeZone))
                if let start, d >= start, ende.map({ d < $0 }) ?? true { e.eisprungBestaetigt = false }
            }
            if let e = bestehend {
                e.eisprungBestaetigt = true
            } else {
                let neu = ZyklusEintrag(datum: tag)
                neu.eisprungBestaetigt = true
                modelContext.insert(neu)
            }
        }
        planeZyklusNotifs()
    }

    private var kalenderLegende: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                ForEach([0.35, 0.6, 0.85, 1.0] as [Double], id: \.self) { op in
                    Circle().fill(ZyklusFarbe.periode.opacity(op)).frame(width: 7, height: 7)
                }
                Text("Periode")
            }
            legendeItem(ZyklusFarbe.periode, gestrichelt: true, text: "Vorhergesagt",
                        info: ("Vorhergesagte Periode",
                               "Geschätzter Periodenbeginn aus deinen bisherigen Zyklen (gewichteter Median der letzten 6). Die Abweichung ± Tage steht im Heute-Tab."))
            legendeItem(ZyklusFarbe.fruchtbar, gestrichelt: false, text: "Fruchtbar",
                        info: ("Fruchtbare Tage",
                               "Die 6 Tage bis einschließlich Eisprungtag (kräftig). Hellere Randtage zeigen die Unsicherheit der Prognose und sind bei bestätigtem Eisprung (Temperatur, LH-Test) verschwunden. Fruchtbarer Zervixschleim und positive LH-Tests markieren den Tag zusätzlich."))
            legendeItem(ZyklusFarbe.eisprung, gestrichelt: false, text: "Eisprung",
                        info: ("Eisprung (Ovulation)",
                               "Festgelegt per BBT-Anstieg (bestätigt), LH-Test oder Zervixschleim-Peak; sonst geschätzt als nächste Periode minus Lutealphase (Standard 14 Tage, persönlich gelernt ab 2 Zyklen mit Evidenz)."))
            HStack(spacing: 4) {
                Circle().fill(Color.purple.opacity(0.8)).frame(width: 7, height: 7)
                Text("Symptome")
            }
            HStack(spacing: 4) {
                Circle().fill(Color.blue.opacity(0.8)).frame(width: 7, height: 7)
                Text("Zervixschleim")
            }
            HStack(spacing: 4) {
                Circle().fill(Color.pink.opacity(0.8)).frame(width: 7, height: 7)
                Text("Sex. Aktivität")
            }
            HStack(spacing: 4) {
                Image(systemName: "star.fill").font(.system(size: 8)).foregroundStyle(ZyklusFarbe.eisprung)
                Text("LH-Test positiv")
            }
            HStack(spacing: 4) {
                Circle().fill(Color.gray.opacity(0.8)).frame(width: 7, height: 7)
                Text("Test / Temperatur / Notiz")
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(14)
        .zyklusGlas(radius: 18)
    }

    private func legendeItem(_ farbe: Color, gestrichelt: Bool, text: String, info: (String, String)) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(gestrichelt ? farbe.opacity(0.15) : farbe)
                .overlay {
                    if gestrichelt {
                        Circle().stroke(farbe, style: StrokeStyle(lineWidth: 1, dash: [2]))
                    }
                }
                .frame(width: 9, height: 9)
            Text(text)
            InfoButton(titel: info.0, text: info.1)
        }
    }

    // MARK: - Verlauf

    @ViewBuilder
    private func verlaufInhalt(_ analyse: ZyklusAnalyse) -> some View {
        if analyse.zyklusStarts.isEmpty {
            leerKarte
        } else {
            ZyklusVerlaufView(analyse: analyse, proTag: eintraegeProTag)
            analyseButton
        }
    }

    // MARK: - Benachrichtigungen

    @ViewBuilder
    private func erinnerungsBanner(_ analyse: ZyklusAnalyse) -> some View {
        if !analyse.zyklusStarts.isEmpty && !pausiert {
            if notifManager.status == .notDetermined {
                HStack(spacing: 12) {
                    Image(systemName: "bell.badge.fill").font(.title3).foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Zyklus-Erinnerungen").font(.subheadline.bold())
                        Text("Erhalte Benachrichtigungen für Periode, fruchtbare Tage und Eisprung.")
                            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Button("Aktivieren") {
                        Task {
                            let granted = await notifManager.berechtigungAnfordern()
                            if granted { planeZyklusNotifs() }
                        }
                    }
                    .buttonStyle(.borderedProminent).controlSize(.small).tint(.pink)
                }
                .padding(14)
                .zyklusGlas(radius: 18)
            } else if notifManager.status == .denied {
                HStack(spacing: 12) {
                    Image(systemName: "bell.slash.fill").font(.title3).foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Erinnerungen deaktiviert").font(.subheadline.bold())
                        Text("Aktiviere Benachrichtigungen in den iOS-Einstellungen.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
#if os(iOS)
                    Button("Einstellungen") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.caption).buttonStyle(.bordered).controlSize(.small)
#endif
                }
                .padding(14)
                .zyklusGlas(radius: 18)
            }
        }
    }
}

// MARK: - Helpers

private struct ZyklusTagAuswahl: Identifiable {
    let id = UUID()
    let datum: Date
}
