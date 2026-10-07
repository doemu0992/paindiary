import Testing
import Foundation
@testable import PainDiary

// MARK: - Hilfen

private func datum(_ j: Int, _ m: Int, _ t: Int, _ h: Int = 12, _ min: Int = 0, tz: String = "UTC") -> Date {
    var kal = Calendar(identifier: .gregorian)
    kal.timeZone = TimeZone(identifier: tz)!
    return kal.date(from: DateComponents(year: j, month: m, day: t, hour: h, minute: min))!
}

private func tag(_ j: Int, _ m: Int, _ t: Int) -> DayKey { DayKey(jahr: j, monat: m, tag: t) }

private func wert(_ t: DayKey, _ w: Double) -> TagesWert { TagesWert(tag: t, wert: w) }

// MARK: - DayKey

struct DayKeyTests {
    @Test func zeitzoneBestimmtDenTag() {
        let moment = datum(2026, 10, 5, 12, 0, tz: "UTC")
        #expect(DayKey(moment, zeitzone: TimeZone(identifier: "America/Los_Angeles")!) == tag(2026, 10, 5))
        #expect(DayKey(moment, zeitzone: TimeZone(identifier: "Pacific/Auckland")!) == tag(2026, 10, 6))
    }

    @Test func addiereUeberMonatsUndJahresgrenzen() {
        #expect(tag(2026, 2, 28).addiere(tage: 1) == tag(2026, 3, 1))
        #expect(tag(2028, 2, 28).addiere(tage: 1) == tag(2028, 2, 29))
        #expect(tag(2026, 12, 31).addiere(tage: 1) == tag(2027, 1, 1))
        #expect(tag(2026, 3, 1).addiere(tage: -1) == tag(2026, 2, 28))
    }

    @Test func tageBisIstSommerzeitunabhaengig() {
        // Sommerzeit-Beginn in Europa: 29.3.2026
        #expect(tag(2026, 3, 28).tage(bis: tag(2026, 3, 30)) == 2)
        #expect(tag(2026, 10, 24).tage(bis: tag(2026, 10, 26)) == 2)
        #expect(tag(2026, 10, 5).tage(bis: tag(2026, 10, 1)) == -4)
    }

    @Test func kompakterWertRoundtrip() {
        #expect(tag(2026, 10, 5).wert == 20261005)
        #expect(DayKey(wert: 20261005) == tag(2026, 10, 5))
        #expect(DayKey(wert: 20261305) == nil)
        #expect(DayKey(wert: 5) == nil)
    }

    @Test func sortierung() {
        #expect(tag(2026, 1, 31) < tag(2026, 2, 1))
        #expect([tag(2026, 5, 1), tag(2025, 12, 31)].sorted().first == tag(2025, 12, 31))
    }
}

// MARK: - Statistik

struct StatistikTests {
    @Test func mittelwertUndStandardabweichung() {
        #expect(Statistik.mittelwert([1, 2, 3]) == 2)
        #expect(Statistik.mittelwert([]) == nil)
        let sd = Statistik.standardabweichung([2, 4, 4, 4, 5, 5, 7, 9])
        #expect(abs((sd ?? 0) - 2.13809) < 0.001)
        #expect(Statistik.standardabweichung([5]) == nil)
    }

    @Test func tagesDurchschnitteGruppiertUndSortiert() {
        let r = Statistik.tagesDurchschnitte([
            (tag(2026, 10, 2), 6), (tag(2026, 10, 1), 2), (tag(2026, 10, 1), 4)
        ])
        #expect(r == [wert(tag(2026, 10, 1), 3), wert(tag(2026, 10, 2), 6)])
    }

    @Test func trendVergleichtZweiZeitraeume() {
        var reihe: [TagesWert] = []
        for t in 1...7 { reihe.append(wert(tag(2026, 10, t), 4)) }
        for t in 8...14 { reihe.append(wert(tag(2026, 10, t), 6)) }
        let ergebnis = Statistik.trend(reihe, heute: tag(2026, 10, 14), tage: 7)
        #expect(ergebnis == TrendErgebnis(aktuell: 6, vorher: 4))
        #expect(ergebnis?.differenz == 2)
        #expect(ergebnis?.richtung() == .schlechter)
        #expect(TrendErgebnis(aktuell: 3, vorher: 5).richtung() == .besser)
        #expect(TrendErgebnis(aktuell: 5.1, vorher: 5).richtung() == .gleich)
    }

    @Test func trendOhneVergleichszeitraumIstNil() {
        let reihe = (8...14).map { wert(tag(2026, 10, $0), 5) }
        #expect(Statistik.trend(reihe, heute: tag(2026, 10, 14), tage: 7) == nil)
    }

    @Test func steigungProTag() {
        let reihe = [wert(tag(2026, 10, 1), 1), wert(tag(2026, 10, 2), 2), wert(tag(2026, 10, 3), 3)]
        #expect(abs((Statistik.steigung(reihe) ?? 0) - 1.0) < 1e-9)
        #expect(Statistik.steigung(Array(reihe.prefix(2))) == nil)
        let flach = [wert(tag(2026, 10, 1), 4), wert(tag(2026, 10, 2), 4), wert(tag(2026, 10, 3), 4)]
        #expect(abs(Statistik.steigung(flach) ?? 1) < 1e-9)
    }

    @Test func gleitenderMittelwert() {
        let reihe = [wert(tag(2026, 10, 1), 2), wert(tag(2026, 10, 2), 4), wert(tag(2026, 10, 3), 6)]
        let g = Statistik.gleitenderMittelwert(reihe, fenster: 2)
        #expect(g.map(\.wert) == [2, 3, 5])
    }

    @Test func korrelation() {
        #expect(abs((Statistik.korrelation([1, 2, 3, 4, 5], [2, 4, 6, 8, 10]) ?? 0) - 1) < 1e-9)
        #expect(abs((Statistik.korrelation([1, 2, 3, 4, 5], [10, 8, 6, 4, 2]) ?? 0) + 1) < 1e-9)
        #expect(Statistik.korrelation([1, 2, 3, 4, 5], [3, 3, 3, 3, 3]) == nil)
        #expect(Statistik.korrelation([1, 2, 3], [1, 2, 3]) == nil)   // zu wenige Paare
    }

    @Test func schmerzfreieTageUndSerie() {
        let reihe = [
            wert(tag(2026, 10, 1), 0), wert(tag(2026, 10, 2), 0), wert(tag(2026, 10, 3), 0),
            wert(tag(2026, 10, 4), 3),
            wert(tag(2026, 10, 6), 0), wert(tag(2026, 10, 7), 0)   // 5. fehlt → unbekannt, keine Fortsetzung
        ]
        #expect(Statistik.schmerzfreieTage(reihe) == 5)
        #expect(Statistik.laengsteSchmerzfreieSerie(reihe) == 3)
        #expect(Statistik.laengsteSchmerzfreieSerie([]) == 0)
    }

    @Test func haeufigkeitenSortierung() {
        let r = Statistik.haeufigkeiten(["b", "a", "b", "c", "a", "b", ""], limit: 2)
        #expect(r.map(\.name) == ["b", "a"])
        #expect(r.map(\.anzahl) == [3, 2])
    }
}

// MARK: - Trigger

struct TriggerAnalyseTests {
    @Test func faktorMitHoeheremSchmerz() {
        var tage: [TagesMerkmale] = []
        for t in 1...3 { tage.append(TagesMerkmale(tag: tag(2026, 10, t), schmerz: 8, faktoren: ["Stress"])) }
        for t in 4...6 { tage.append(TagesMerkmale(tag: tag(2026, 10, t), schmerz: 4, faktoren: [])) }
        let r = TriggerAnalyse.auswerten(tage: tage, minFaelle: 3)
        #expect(r.count == 1)
        #expect(r.first?.name == "Stress")
        #expect(r.first?.tageMit == 3)
        #expect(r.first?.tageOhne == 3)
        #expect(r.first?.differenz == 4)
        #expect(r.first?.konfidenz == .niedrig)
    }

    @Test func zuWenigFaelleWerdenNichtAusgewiesen() {
        var tage: [TagesMerkmale] = []
        for t in 1...3 { tage.append(TagesMerkmale(tag: tag(2026, 10, t), schmerz: 8, faktoren: ["Stress"])) }
        for t in 4...6 { tage.append(TagesMerkmale(tag: tag(2026, 10, t), schmerz: 4, faktoren: [])) }
        #expect(TriggerAnalyse.auswerten(tage: tage, minFaelle: 4).isEmpty)
    }

    @Test func verzoegerungFolgetag() {
        var tage: [TagesMerkmale] = []
        for t in 1...8 {
            let schmerz: Double = (2...4).contains(t) ? 8 : 3
            let faktoren: Set<String> = (1...3).contains(t) ? ["X"] : []
            tage.append(TagesMerkmale(tag: tag(2026, 10, t), schmerz: schmerz, faktoren: faktoren))
        }
        let r = TriggerAnalyse.auswerten(tage: tage, verzoegerungTage: 1, minFaelle: 3)
        #expect(r.first?.mittelMit == 8)
        #expect(r.first?.mittelOhne == 3)
    }

    @Test func tageOhneSchmerzwertZaehlenNicht() {
        var tage: [TagesMerkmale] = []
        for t in 1...3 { tage.append(TagesMerkmale(tag: tag(2026, 10, t), schmerz: nil, faktoren: ["Stress"])) }
        for t in 4...9 { tage.append(TagesMerkmale(tag: tag(2026, 10, t), schmerz: 4, faktoren: [])) }
        #expect(TriggerAnalyse.auswerten(tage: tage, minFaelle: 3).isEmpty)
    }
}

// MARK: - Gesundheitsregeln

struct GesundheitsregelnTests {
    @Test func uebergebrauchStufen() {
        let heute = tag(2026, 10, 30)
        let zehn = (0..<10).map { heute.addiere(tage: -$0) }
        #expect(Uebergebrauch.pruefe(einnahmeTage: zehn, heute: heute).stufe == .ueberschritten)
        #expect(Uebergebrauch.pruefe(einnahmeTage: Array(zehn.prefix(8)), heute: heute).stufe == .nahe)
        #expect(Uebergebrauch.pruefe(einnahmeTage: Array(zehn.prefix(7)), heute: heute).stufe == .unauffaellig)
    }

    @Test func uebergebrauchZaehltTageEinmalUndNurImFenster() {
        let heute = tag(2026, 10, 30)
        let tage = [heute, heute, heute.addiere(tage: -40)]
        let s = Uebergebrauch.pruefe(einnahmeTage: tage, heute: heute)
        #expect(s.tageMitAkutmedikation == 1)
    }

    @Test func wirksamkeitVorNachher() {
        let t0 = datum(2026, 10, 5, 10)
        let schmerz = [(datum: datum(2026, 10, 5, 9), staerke: 7), (datum: datum(2026, 10, 5, 12), staerke: 3)]
        let r = Wirksamkeit.auswerten(einnahmen: [t0], schmerz: schmerz)
        #expect(r == WirksamkeitsErgebnis(paare: 1, mittlereVeraenderung: -4, besserungsquote: 1))
    }

    @Test func wirksamkeitOhneNachherWertIstNil() {
        let t0 = datum(2026, 10, 5, 10)
        #expect(Wirksamkeit.auswerten(einnahmen: [t0], schmerz: [(datum: datum(2026, 10, 5, 9), staerke: 7)]) == nil)
    }

    @Test func schubErkennung() {
        let heute = tag(2026, 10, 31)
        var reihe: [TagesWert] = []
        for t in 1...28 { reihe.append(wert(tag(2026, 10, t), t % 2 == 0 ? 4 : 3)) }
        for t in 29...31 { reihe.append(wert(tag(2026, 10, t), 7)) }
        let hinweis = SchubErkennung.pruefe(reihe, heute: heute)
        #expect(hinweis != nil)
        #expect(abs((hinweis?.baselineMittelwert ?? 0) - 3.5) < 1e-9)

        var leicht = Array(reihe.prefix(28))
        for t in 29...31 { leicht.append(wert(tag(2026, 10, t), 4)) }
        #expect(SchubErkennung.pruefe(leicht, heute: heute) == nil)
        #expect(SchubErkennung.pruefe(Array(reihe.suffix(5)), heute: heute) == nil)   // Baseline zu dünn
    }

    @Test func schlafOhneDoppelzaehlung() {
        let a = SchlafSegment(start: datum(2026, 10, 4, 22), ende: datum(2026, 10, 5, 6))
        let b = SchlafSegment(start: datum(2026, 10, 4, 23), ende: datum(2026, 10, 5, 5))
        #expect(SchlafAggregator.stunden(aus: [a, b]) == 8)

        let c = SchlafSegment(start: datum(2026, 10, 5, 22), ende: datum(2026, 10, 6, 2))
        let d = SchlafSegment(start: datum(2026, 10, 6, 3), ende: datum(2026, 10, 6, 6))
        #expect(SchlafAggregator.stunden(aus: [c, d]) == 7)

        let ungueltig = SchlafSegment(start: datum(2026, 10, 5, 8), ende: datum(2026, 10, 5, 7))
        #expect(SchlafAggregator.stunden(aus: [ungueltig]) == 0)
        #expect(SchlafAggregator.stunden(aus: []) == 0)
    }
}

// MARK: - ListenFeld, Validierung, EintragArt

struct DomainHilfenTests {
    @Test func listenFeldRoundtripMitKommaImElement() {
        #expect(ListenFeld.parse("Stress, Wetter") == ["Stress", "Wetter"])
        #expect(ListenFeld.parse("").isEmpty)
        #expect(ListenFeld.join(["a", "a", "b"]) == "a, b")
        let gespeichert = ListenFeld.join(["Stress, beruflich", "Wetter"])
        #expect(gespeichert == "Stress – beruflich, Wetter")
        #expect(ListenFeld.parse(gespeichert).count == 2)
    }

    @Test func validierungBegrenztUndProtokolliert() {
        var k: [Korrektur] = []
        #expect(Validierung.begrenze(15, feld: "schmerz", bereich: Wertebereich.schmerz, korrekturen: &k) == 10)
        #expect(Validierung.begrenze(-2, feld: "schmerz", bereich: Wertebereich.schmerz, korrekturen: &k) == 0)
        #expect(Validierung.begrenze(5, feld: "schmerz", bereich: Wertebereich.schmerz, korrekturen: &k) == 5)
        #expect(k.count == 2)
        #expect(Validierung.begrenze(.nan, feld: "schlaf", bereich: Wertebereich.schlafStunden, korrekturen: &k) == 0)
    }

    @Test func zukunftWirdAufJetztGesetzt() {
        let jetzt = datum(2026, 10, 5, 12)
        var k: [Korrektur] = []
        #expect(Validierung.begrenzeZukunft(datum(2026, 10, 9), jetzt: jetzt, korrekturen: &k) == jetzt)
        #expect(Validierung.begrenzeZukunft(datum(2026, 10, 5, 12, 3), jetzt: jetzt, korrekturen: &k) == datum(2026, 10, 5, 12, 3))
    }

    @Test func blutzuckerPruefung() {
        #expect(throws: ValidierungsFehler.self) { try Validierung.pruefeBlutzucker(0) }
        #expect(throws: ValidierungsFehler.self) { try Validierung.pruefeBlutzucker(.infinity) }
        #expect(throws: Never.self) { try Validierung.pruefeBlutzucker(5.5) }
    }

    @Test func eintragArtLegacyRegel() {
        #expect(EintragArt.ausLegacy(koerperstelle: "Rheuma", istHautEintrag: false) == .rheuma)
        #expect(EintragArt.ausLegacy(koerperstelle: "Arm", istHautEintrag: true) == .haut)
        #expect(EintragArt.ausLegacy(koerperstelle: "Kopf", istHautEintrag: false) == .schmerz)
    }
}
