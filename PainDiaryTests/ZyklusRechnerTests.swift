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

    private func blutung(_ datum: Date, _ fluss: Blutungsfluss = .mittel) -> ZyklusEintrag {
        let e = ZyklusEintrag(datum: datum)
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
        // Zyklus 1: 1.1.–28.1., nächster Start 29.1. → Eisprung = 29.1. − 15 Tage = 14.1. (Zyklustag 14), Lutealphase 14 Tage
        #expect(a.ovulationsTageSet.contains(d(2026, 1, 14)))
        #expect(a.zyklen.first?.lutealLaenge == 14)
        // Fenster: 6 Tage bis einschließlich Eisprung
        for t in 9...14 { #expect(a.fruchtbareTageSet.contains(d(2026, 1, t))) }
        #expect(!a.fruchtbareTageSet.contains(d(2026, 1, 15)))
        #expect(!a.fruchtbareTageSet.contains(d(2026, 1, 8)))
    }

    @Test func positiverLHTestLegtEisprungAufFolgetag() {
        var e = zyklen(start: d(2026, 1, 1), laengen: [28, 28], laufenderZyklusBis: d(2026, 2, 28))
        let lh = ZyklusEintrag(datum: d(2026, 1, 12))
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
            let m = ZyklusEintrag(datum: tag(d(2026, 1, 1), plus: i))
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
            let g = ZyklusEintrag(datum: tag(d(2026, 1, 1), plus: i))
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
        let lh = ZyklusEintrag(datum: d(2026, 4, 3))   // laufender Zyklus ab 26.3. → Zyklustag 9
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
        #expect(ZyklusRechner.phase(for: d(2026, 1, 14), analyse: a, kalender: kal) == .ovulation)   // = Kalender-Eisprung
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
