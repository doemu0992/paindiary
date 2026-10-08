import SwiftUI
import SwiftData

/// Zyklus-Tracker: Frosted-Glass-Karten über sanftem Rosé/Pfirsich/Lavendel-Verlauf.
/// Drei Ansichten: Heute (Phasen-Ring + Prognose), Monat (Band-Kalender), Verlauf (Zyklenliste).
struct ZyklusView: View {
    @Query(sort: \ZyklusEintrag.datum, order: .reverse) private var eintraege: [ZyklusEintrag]
    @Environment(\.modelContext) private var modelContext
    @Query private var schmerzEintraege: [PainEntry]
    @Query private var profile: [Benutzerprofil]
    @State private var zeigePartner = false
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
        .auroraScreen(.zyklus)
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
        .sheet(isPresented: $zeigePartner) { ZyklusPartnerTeilenSheet(eintraege: Array(eintraege)) }
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

            Button { zeigePartner = true } label: {
                Label("Mit Partner:in teilen", systemImage: "person.2")
            }

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
        ZyklusPartnerService.shared.synchronisieren(eintraege: Array(eintraege))
    }

    private func oeffneHeuteSheet() {
        ausgewaehlterTag = ZyklusTagAuswahl(datum: kal.startOfDay(for: Date()))
    }

    private func wechselMonat(_ richtung: Int) {
        withAnimation {
            anzeigeMonat = kal.date(byAdding: .month, value: richtung, to: anzeigeMonat) ?? anzeigeMonat
        }
    }

    // MARK: - Heute

    @ViewBuilder
    private func heuteInhalt(_ analyse: ZyklusAnalyse, _ proTag: [Date: ZyklusTagesSicht]) -> some View {
        if analyse.zyklusStarts.isEmpty {
            leerKarte
        } else if pausiert {
            pausiertKarte
        } else {
            ZyklusRingKarte(analyse: analyse, auswahl: $ringAuswahl)
            if analyse.status != .normal { ZyklusStatusKarte(analyse: analyse) }
            ZyklusPrognoseReihe(analyse: analyse)
        }

        erfassenKarte(proTag)

        if !analyse.zyklusStarts.isEmpty {
            ZyklusUeberblickKarte(analyse: analyse)
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
                    .background(Color.pink, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .glassCard(padding: 0)
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
        .glassCard(padding: 0)
    }

    // MARK: Prognose-Karten

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
        .glassCard(radius: 20, padding: 0)
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

    private var analyseButton: some View {
        Button { zeigeAnalyse = true } label: {
            Label("Zyklusanalyse öffnen", systemImage: "chart.bar.xaxis.ascending")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.pink, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
        .glassCard(padding: 0)

        if let tag = monatsAuswahl {
            ZyklusTagesKarte(
                tag: tag, analyse: analyse, proTag: proTag, prognosen: !pausiert,
                onBearbeiten: { ausgewaehlterTag = ZyklusTagAuswahl(datum: $0) },
                onEisprung: { eisprungUmschalten(an: $0) })
                .transition(.opacity)
        }

        ZyklusKalenderLegende()
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
                .glassCard(radius: 18, padding: 0)
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
                .glassCard(radius: 18, padding: 0)
            }
        }
    }
}

// MARK: - Helpers

private struct ZyklusTagAuswahl: Identifiable {
    let id = UUID()
    let datum: Date
}
