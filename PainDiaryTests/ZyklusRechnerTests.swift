import Foundation
import Testing
@testable import PainDiary

/// Tests der Zyklus-Engine. Fixe Zeitzone (UTC) und injiziertes „heute" → deterministisch.
@MainActor
struct ZyklusRechnerTests {

    // MARK: - Helfer

    private var kal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.firstWeekday = 2
        return c
    }

    private func d(_ jahr: Int, _ monat: Int, _ tag: Int) -> Date {
        kal.date(from: DateComponents(year: jahr, month: monat, day: tag))!
    }

    private func tag(_ start: Date, plus n: Int) -> Date {
        kal.date(byAdding: .day, value: n, to: start)!
    }

    /// Eintrag mit fixer Erfassungs-Zeitzone (UTC) — unabhängig von der Zeitzone der Test-Maschine.
    private func neuerEintrag(_ datum: Date, zeitzone: String = "UTC") -> ZyklusEintrag {
        let e = ZyklusEintrag(datum: datum)
        e.timeZoneID = zeitzone
        return e
    }

    private func blutung(_ datum: Date, _ fluss: Blutungsfluss = .mittel) -> ZyklusEintrag {
        let e = neuerEintrag(datum)
        e.istPeriode = true
        e.fluss = fluss
        return e
    }

    /// Regelmäßige Zyklen: je `perioden` Tage Blutung ab den berechneten Starts.
    private func zyklen(start: Date, laengen: [Int], periodenTage: Int = 5, laufenderZyklusBis: Date? = nil) -> [ZyklusEintrag] {
        var eintraege: [ZyklusEintrag] = []
        var aktuellerStart = start
        for l in laengen {
            for i in 0..<periodenTage { eintraege.append(blutung(tag(aktuellerStart, plus: i))) }
            aktuellerStart = tag(aktuellerStart, plus: l)
        }
        // laufender Zyklus
        for i in 0..<periodenTage {
            let t = tag(aktuellerStart, plus: i)
            if let bis = laufenderZyklusBis, t > bis { break }
            eintraege.append(blutung(t))
        }
        return eintraege
    }

    private func analyse(_ e: [ZyklusEintrag], heute: Date) -> ZyklusAnalyse {
        ZyklusRechner.analyse(eintraege: e, heute: heute, kalender: kal)
    }

    // MARK: - Zyklusstart-Erkennung

    @Test func vergessenerBlutungstagErzeugtKeinenFakeZyklus() {
        var e: [ZyklusEintrag] = []
        for i in [0, 1, 3, 4] { e.append(blutung(tag(d(2026, 1, 1), plus: i))) }   // Tag 3 vergessen
        for i in 0..<5 { e.append(blutung(tag(d(2026, 1, 29), plus: i))) }
        let a = analyse(e, heute: d(2026, 2, 3))
        #expect(a.zyklusStarts.count == 2)
        #expect(a.zyklen.first?.laenge == 28)
    }

    @Test func schmierblutungIstKeinZyklusstart() {
        var e = zyklen(start: d(2026, 1, 1), laengen: [28], laufenderZyklusBis: d(2026, 1, 31))
        e.append(blutung(d(2026, 1, 27), .schmierblutung))   // Spotting vor der Periode
        let a = analyse(e, heute: d(2026, 1, 31))
        #expect(a.zyklusStarts.count == 2)
        #expect(a.zyklen.first?.laenge == 28)
    }

    @Test func zwischenblutungNachwenigenTagenIstKeinNeuerZyklus() {
        var e = zyklen(start: d(2026, 1, 1), laengen: [], laufenderZyklusBis: d(2026, 1, 5))
        for i in 0..<2 { e.append(blutung(tag(d(2026, 1, 15), plus: i))) }   // Lücke > 7 Tage, aber Start nur 14 Tage nach dem letzten
        let a = analyse(e, heute: d(2026, 1, 20))
        #expect(a.zyklusStarts.count == 1)
    }

    // MARK: - Statistik

    @Test func regelmaessigeZyklenLiefernMedianUndRegelmaessigkeit() {
        let e = zyklen(start: d(2026, 1, 1), laengen: [28, 28, 28, 28, 28, 28], laufenderZyklusBis: d(2026, 6, 20))
        let a = analyse(e, heute: d(2026, 6, 20))
        #expect(a.gueltigeZyklen == 6)
        #expect(a.medianZykluslaenge == 28)
        #expect(a.regelmaessigkeit == .regelmaessig)
        #expect(a.datenQualitaet == .sehrGut)
        #expect(a.aktuellerZyklustag == 3)
        #expect(a.naechstePeriodeStart == d(2026, 7, 16))
    }

    @Test func ausreisserZyklusWirdAusgeschlossen() {
        let e = zyklen(start: d(2026, 1, 1), laengen: [28, 28, 28, 28, 28, 80])
        let a = analyse(e, heute: tag(d(2026, 1, 1), plus: 28 * 5 + 80 + 2))
        #expect(a.gueltigeZyklen == 5)
        #expect(a.zykluslaenge == 28)
        #expect(a.zyklen.last(where: { $0.laenge == 80 })?.fuerStatistikGueltig == false)
    }

    @Test func ueberfaelligePeriodeWirdAlsStatusGemeldet() {
        let e = zyklen(start: d(2026, 1, 1), laengen: [28, 28, 28, 28, 28], laufenderZyklusBis: d(2026, 5, 21))
        // letzter Start: 21.5.; erwartet 18.6.; heute 27.6. → 9 Tage überfällig
        let a = analyse(e, heute: d(2026, 6, 27))
        #expect(a.status == .ueberfaellig(tage: 9))
    }

    @Test func zuAltenZyklusstartErzeugtKeinePrognose() {
        let e = zyklen(start: d(2026, 1, 1), laengen: [28, 28], laufenderZyklusBis: d(2026, 3, 1))
        let a = analyse(e, heute: d(2026, 8, 1))
        #expect(a.status == .keineAktuellenDaten)
        #expect(a.naechstePeriodeStart == nil)
        #expect(a.vorhergesagteOvulation == nil)
    }

    // MARK: - Eisprung & fruchtbares Fenster

    @Test func kalenderEisprungIstLutealphaseVorNaechsterPeriode() {
        let e = zyklen(start: d(2026, 1, 1), laengen: [28, 28, 28], laufenderZyklusBis: d(2026, 4, 25))
        let a = analyse(e, heute: d(2026, 4, 25))
        // Zyklus 1: 1.1.–28.1., nächster Start 29.1. → Standard-Lutealphase 13: Eisprung = 29.1. − 14 Tage = 15.1. (Zyklustag 15)
        #expect(a.ovulationsTageSet.contains(d(2026, 1, 15)))
        #expect(a.zyklen.first?.lutealLaenge == 13)
        // Fenster: 6 Tage bis einschließlich Eisprung
        for t in 10...15 { #expect(a.fruchtbareTageSet.contains(d(2026, 1, t))) }
        #expect(!a.fruchtbareTageSet.contains(d(2026, 1, 16)))
        #expect(!a.fruchtbareTageSet.contains(d(2026, 1, 9)))
    }

    @Test func positiverLHTestLegtEisprungAufFolgetag() {
        var e = zyklen(start: d(2026, 1, 1), laengen: [28, 28], laufenderZyklusBis: d(2026, 2, 28))
        let lh = neuerEintrag(d(2026, 1, 12))
        lh.lhTest = .positiv
        e.append(lh)
        let a = analyse(e, heute: d(2026, 2, 28))
        #expect(a.zyklen.first?.eisprung == d(2026, 1, 13))
        #expect(a.zyklen.first?.eisprungQuelle == .lhTest)
        #expect(a.zyklen.first?.lutealLaenge == 15)
    }

    @Test func bbtAnstiegBestaetigtEisprung() {
        var e = zyklen(start: d(2026, 1, 1), laengen: [28, 28], laufenderZyklusBis: d(2026, 2, 28))
        for i in 0..<28 {
            let m = neuerEintrag(tag(d(2026, 1, 1), plus: i))
            m.basaltemperatur = i < 14 ? 36.25 + Double(i % 3) * 0.05 : 36.7   // Anstieg ab Zyklustag 15
            e.append(m)
        }
        let a = analyse(e, heute: d(2026, 2, 28))
        #expect(a.zyklen.first?.eisprung == d(2026, 1, 14))
        #expect(a.zyklen.first?.eisprungQuelle == .temperatur)
        #expect(a.zyklen.first?.lutealLaenge == 14)
    }

    @Test func unplausibleTemperaturenWerdenIgnoriert() {
        var e = zyklen(start: d(2026, 1, 1), laengen: [28], laufenderZyklusBis: d(2026, 1, 31))
        // 20 gültige Werte mit klarem Anstieg ab Tag 15 → würde bestätigen …
        for i in 0..<20 {
            let g = neuerEintrag(tag(d(2026, 1, 1), plus: i))
            g.basaltemperatur = i < 14 ? 36.3 : 36.7
            if i == 9 { g.basaltemperatur = 3.65 }   // … Tippfehler wird ignoriert, Anstieg bleibt erkannt
            e.append(g)
        }
        let a = analyse(e, heute: d(2026, 1, 31))
        #expect(a.zyklen.first?.eisprungQuelle == .temperatur)
        #expect(a.zyklen.first?.eisprung == d(2026, 1, 14))
    }

    @Test func eisprungKannAuchFruehererAlsKalenderPrognoseSein() {
        // Früher Eisprung (LH positiv Zyklustag 9) im laufenden Zyklus verschiebt die Prognose nach vorn.
        var e = zyklen(start: d(2026, 1, 1), laengen: [28, 28, 28], laufenderZyklusBis: d(2026, 4, 25))
        let lh = neuerEintrag(d(2026, 4, 3))   // laufender Zyklus ab 26.3. → Zyklustag 9
        lh.lhTest = .positiv
        e.append(lh)
        let a = analyse(e, heute: d(2026, 4, 25))
        #expect(a.zyklen.last?.eisprung == d(2026, 4, 4))
    }

    // MARK: - Phasen

    @Test func phasenSindKonsistentMitKalender() {
        let e = zyklen(start: d(2026, 1, 1), laengen: [28, 28, 28], laufenderZyklusBis: d(2026, 4, 25))
        let a = analyse(e, heute: d(2026, 4, 25))
        #expect(ZyklusRechner.phase(for: d(2026, 1, 2), analyse: a, kalender: kal) == .menstruation)
        #expect(ZyklusRechner.phase(for: d(2026, 1, 8), analyse: a, kalender: kal) == .follikelphase)
        #expect(ZyklusRechner.phase(for: d(2026, 1, 13), analyse: a, kalender: kal) == .follikelphase)
        #expect(ZyklusRechner.phase(for: d(2026, 1, 15), analyse: a, kalender: kal) == .ovulation)   // = Kalender-Eisprung
        #expect(ZyklusRechner.phase(for: d(2026, 1, 20), analyse: a, kalender: kal) == .lutealphase)
        #expect(ZyklusRechner.phase(for: d(2026, 1, 27), analyse: a, kalender: kal) == .praemenstruell)
        #expect(ZyklusRechner.phase(for: d(2025, 12, 1), analyse: a, kalender: kal) == nil)
    }

    @Test func phaseJenseitsPlausiblemZyklusendeIstNil() {
        let e = zyklen(start: d(2026, 1, 1), laengen: [28, 28], laufenderZyklusBis: d(2026, 3, 1))
        let a = analyse(e, heute: d(2026, 4, 10))
        // Zyklus läuft ab 26.2.; der 15.5. wäre Zyklustag 79 — weit jenseits der erwarteten Länge (28 + 14)
        #expect(ZyklusRechner.phase(for: d(2026, 5, 15), analyse: a, kalender: kal) == nil)
    }

    @Test func perimenstruellesFensterIstMinusZweiBisPlusDrei() {
        let e = zyklen(start: d(2026, 1, 1), laengen: [28], laufenderZyklusBis: d(2026, 1, 31))
        let a = analyse(e, heute: d(2026, 1, 31))
        #expect(ZyklusRechner.istPerimenstruell(d(2025, 12, 30), analyse: a, kalender: kal))
        #expect(ZyklusRechner.istPerimenstruell(d(2026, 1, 4), analyse: a, kalender: kal))
        #expect(!ZyklusRechner.istPerimenstruell(d(2026, 1, 5), analyse: a, kalender: kal))
        #expect(!ZyklusRechner.istPerimenstruell(d(2025, 12, 28), analyse: a, kalender: kal))
    }

    @Test func prognoseLaengeNutztGewichtetenMedianDerLetztenSechs() {
        #expect(ZyklusRechner.prognoseLaenge(aus: []) == 28)
        #expect(ZyklusRechner.prognoseLaenge(aus: [30]) == 30)
        #expect(ZyklusRechner.prognoseLaenge(aus: [26, 30]) == 26 * 0.4 + 30 * 0.6)
        #expect(ZyklusRechner.prognoseLaenge(aus: [28, 28, 28, 28, 28, 28]) == 28)
        // Jüngere Zyklen zählen stärker: Trend nach oben → Prognose über dem einfachen Median
        #expect(ZyklusRechner.prognoseLaenge(aus: [26, 26, 26, 30, 30, 30]) > 28)
    }

    @Test func kuenftigeZyklenReichenWeitInDieZukunft() {
        let e = zyklen(start: d(2026, 1, 1), laengen: [28, 28, 28, 28], laufenderZyklusBis: d(2026, 5, 21))
        let a = analyse(e, heute: d(2026, 5, 21))
        // Letzter Start 23.4., erwartet ab 21.5.; vier künftige Zyklen à 28 Tage → letzte vorhergesagte Periode 13.–17.8.
        let letzteVorhersage = a.vorhergesagtePeriodeTageSet.max()
        #expect(letzteVorhersage != nil)
        #expect(letzteVorhersage! >= d(2026, 8, 17))
    }

    // MARK: - Dynamik: Belege, verspätete Periode, Lernen

    @Test func eisprungBelegVerankertNaechstePeriodeNeu() {
        // Aktueller Zyklus ab 26.3.; positiver LH-Test am 5.4. → Eisprung 6.4.
        var e = zyklen(start: d(2026, 1, 1), laengen: [28, 28, 28], laufenderZyklusBis: d(2026, 4, 10))
        let lh = neuerEintrag(d(2026, 4, 5))
        lh.lhTest = .positiv
        e.append(lh)
        let a = analyse(e, heute: d(2026, 4, 10))
        // Zyklus-basiert: 23.4.; Eisprung-basiert: 6.4. + 13 + 1 = 20.4. → Mittel 21,5 → 22.4.
        #expect(a.evidenzVerankert)
        #expect(a.naechstePeriodeStart == d(2026, 4, 22))
        #expect(a.unsicherheitTage <= 2)
    }

    @Test func ueberfaelligePeriodeSchiebtEisprungDesLaufendenZyklusMit() {
        let e = zyklen(start: d(2026, 1, 1), laengen: [28, 28, 28], laufenderZyklusBis: d(2026, 4, 28))
        // erwartet 23.4., heute 28.4. (5 Tage überfällig, nichts belegt) → Periode frühestens morgen (29.4.)
        let a = analyse(e, heute: d(2026, 4, 28))
        #expect(a.status == .ueberfaellig(tage: 5))
        // Lutealphase 13 → Eisprung = 29.4. − 14 = 15.4. statt der ursprünglich erwarteten 9.4.
        #expect(a.zyklen.last?.eisprung == d(2026, 4, 15))
        #expect(a.zyklen.last?.erwarteteLaenge == 34)
    }

    @Test func periodeVorZeitSchliesstZyklusMitTatsaechlicherLaengeUndVerschiebtAlles() {
        // Zyklus 4 beginnt schon nach 22 statt 28 Tagen → Eisprung/Fenster des Vorzyklus liegen jetzt früher,
        // die Prognose für den Folgezyklus rechnet ab dem neuen Start.
        var e = zyklen(start: d(2026, 1, 1), laengen: [28, 28, 22], laufenderZyklusBis: d(2026, 3, 25))
        let a1 = analyse(e, heute: d(2026, 3, 25))
        let letzterStart = a1.zyklusStarts.last!
        #expect(letzterStart == d(2026, 3, 20))                       // 1.1. + 28 + 28 + 22 Tage
        #expect(a1.zyklen[2].laenge == 22)
        #expect(a1.zyklen[2].eisprung == d(2026, 3, 20 - 14))         // 22 − 14 Tage vor dem neuen Start
        e.removeAll()
        #expect(analyse(e, heute: d(2026, 3, 25)).zyklusStarts.isEmpty)
    }

    @Test func lutealphaseWirdAusLHBelegGelerntUndSchleimPeakLerntNicht() {
        // Zwei Zyklen mit LH-Beleg (Lutealphase 15) → persönliche Lutealphase rückt von 13 nach oben
        var e = zyklen(start: d(2026, 1, 1), laengen: [28, 28, 28], laufenderZyklusBis: d(2026, 4, 1))
        for startTag in [0, 28] {
            let lh = neuerEintrag(tag(d(2026, 1, 1), plus: startTag + 12))   // positiv Zyklustag 13 → Eisprung Zyklustag 14
            lh.lhTest = .positiv
            e.append(lh)
        }
        let a = analyse(e, heute: d(2026, 4, 1))
        #expect(a.lutealphaseGelernt)
        #expect(a.lutealphase >= 14)

        // Schleim-Peak allein ändert die Lutealphase nicht
        var f = zyklen(start: d(2026, 1, 1), laengen: [28, 28, 28], laufenderZyklusBis: d(2026, 4, 1))
        for startTag in [0, 28, 56] {
            let m = neuerEintrag(tag(d(2026, 1, 1), plus: startTag + 12))
            m.schleim = .eiweiss
            f.append(m)
        }
        #expect(analyse(f, heute: d(2026, 4, 1)).lutealphase == ZyklusGrenzen.standardLutealphase)
    }

    @Test func prognoseWaehltDenGenauestenPraediktorUndMisstDenFehler() {
        let e = zyklen(start: d(2026, 1, 1), laengen: [28, 28, 28, 28, 28, 28], laufenderZyklusBis: d(2026, 6, 20))
        let a = analyse(e, heute: d(2026, 6, 20))
        #expect(a.prognoseFehler == 0)
        #expect(a.unsicherheitTage == 1)
        #expect(a.fruchtbarRandTageSet.isEmpty)   // perfekt vorhersagbar → keine Randtage
    }

    @Test func schwankendeZyklenErzeugenFruchtbareRandtage() {
        let laengen = [24, 31, 26, 29, 25, 30]
        let e = zyklen(start: d(2026, 1, 1), laengen: laengen, laufenderZyklusBis: tag(d(2026, 1, 1), plus: 168))
        let a = analyse(e, heute: tag(d(2026, 1, 1), plus: 168))
        #expect(a.prognoseFehler != nil)
        #expect(!a.fruchtbarRandTageSet.isEmpty)
        #expect(a.fruchtbarRandTageSet.isDisjoint(with: a.fruchtbareTageSet))
    }

    // MARK: - Tagessicht & Tests

    @Test func tagessichtFuehrtMehrereEintraegeDesTagesZusammen() {
        let periode = blutung(d(2026, 7, 6), .mittel)
        let test = neuerEintrag(d(2026, 7, 6))
        test.lhTest = .positiv
        let zweiterTest = neuerEintrag(d(2026, 7, 6).addingTimeInterval(3600))
        zweiterTest.lhTest = .negativ    // später, aber ein positives Ergebnis bleibt maßgeblich
        zweiterTest.symptome = "Krämpfe"
        let sicht = ZyklusTagesSicht([periode, test, zweiterTest])
        #expect(sicht.anzahl == 3)
        #expect(sicht.lhTest == .positiv)
        #expect(sicht.hatBlutung)
        #expect(sicht.fluss == .mittel)
        #expect(sicht.symptome == "Krämpfe")
    }

    @Test func positiveLHTageWerdenInZyklusUndAnalyseGefuehrt() {
        var e = zyklen(start: d(2026, 1, 1), laengen: [28, 28], laufenderZyklusBis: d(2026, 2, 28))
        let lh = neuerEintrag(d(2026, 1, 13))
        lh.lhTest = .positiv
        e.append(lh)
        let a = analyse(e, heute: d(2026, 2, 28))
        #expect(a.lhPositiveTageSet == [d(2026, 1, 13)])
        #expect(a.zyklen.first?.lhPositiveTage == [d(2026, 1, 13)])
        #expect(a.zyklen.last?.lhPositiveTage.isEmpty == true)
    }

    // MARK: - DayKey / Zeitzonen

    @Test func laufendeNummerIstFortlaufendUndUmkehrbar() {
        var vorher: Int? = nil
        var key = DayKey(jahr: 2023, monat: 12, tag: 25)
        for _ in 0..<800 {   // über Jahreswechsel und Schaltjahr 2024
            if let v = vorher { #expect(key.laufendeNummer == v + 1) }
            #expect(DayKey(laufendeNummer: key.laufendeNummer) == key)
            vorher = key.laufendeNummer
            key = key.addiere(tage: 1)
        }
        #expect(DayKey(jahr: 1970, monat: 1, tag: 1).laufendeNummer == 0)
        #expect(DayKey(jahr: 2026, monat: 1, tag: 1).laufendeNummer == 20454)
    }

    @Test func eintragGehoertZumTagSeinerErfassungsZeitzone() {
        // 1.1.2026 20:00 UTC = 2.1.2026 09:00 in Auckland (UTC+13) → der Eintrag zählt als 2.1.
        let zeitpunkt = kal.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 20))!
        var e: [ZyklusEintrag] = []
        for i in 0..<5 {
            e.append(neuerEintrag(tag(zeitpunkt, plus: i), zeitzone: "Pacific/Auckland").mitBlutung())
        }
        let a = analyse(e, heute: d(2026, 1, 10))
        #expect(a.zyklusStarts == [d(2026, 1, 2)])
    }

    @Test func gleicheEintraegeInAndererZeitzoneAendernKeineZykluslaenge() {
        // Erfasst in UTC, Auswertung auf einem Gerät in einer anderen Zeitzone → identische Zykluslängen
        let e = zyklen(start: d(2026, 1, 1), laengen: [28, 28, 28], laufenderZyklusBis: d(2026, 4, 1))
        var tokio = Calendar(identifier: .gregorian)
        tokio.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let a = ZyklusRechner.analyse(eintraege: e, heute: d(2026, 4, 1), kalender: tokio)
        #expect(a.zyklen.compactMap { $0.laenge } == [28, 28, 28])
    }

    // MARK: - Typen

    @Test func enumsNormalisierenAltdaten() {
        #expect(Zervixschleim(roh: "Eiweiss") == .eiweiss)
        #expect(Zervixschleim(roh: "wässrig") == .waessrig)
        #expect(Zervixschleim(roh: "") == .keine)
        #expect(Blutungsfluss(roh: "Schmierblutung").istSpotting)
        #expect(LHTest(roh: "POSITIV") == .positiv)
        #expect(SexAktivitaet(roh: "ungeschützt") == .ungeschuetzt)
    }

    @Test func leereEintraegeLiefernLeereAnalyse() {
        let a = analyse([], heute: d(2026, 1, 1))
        #expect(a.zyklusStarts.isEmpty)
        #expect(a.naechstePeriodeStart == nil)
        #expect(a.datenQualitaet == .standardwert)
    }
}

private extension ZyklusEintrag {
    func mitBlutung() -> ZyklusEintrag {
        istPeriode = true
        fluss = .mittel
        return self
    }
}

@MainActor
struct LHTestParsingTests {
    @Test func tolerantesParsen() {
        #expect(LHTest(roh: "") == .keine)
        #expect(LHTest(roh: "positiv") == .positiv)
        #expect(LHTest(roh: "Positiv (LH-Anstieg)") == .positiv)
        #expect(LHTest(roh: "+") == .positiv)
        #expect(LHTest(roh: "Negativ") == .negativ)
        #expect(LHTest(roh: "irgendwas") == .unklar)
    }
}
