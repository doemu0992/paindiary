import Testing
import Foundation
@testable import PainDiary

private func tag(_ j: Int, _ m: Int, _ t: Int) -> DayKey { DayKey(jahr: j, monat: m, tag: t) }

private func punkt(_ t: DayKey, _ staerke: Int, schub: Bool = false, orte: [String] = [], stunde: Int = 12) -> SchmerzMesspunkt {
    var kal = Calendar(identifier: .gregorian)
    kal.timeZone = .current
    let d = kal.date(from: DateComponents(year: t.jahr, month: t.monat, day: t.tag, hour: stunde))!
    return SchmerzMesspunkt(datum: d, tag: t, staerke: staerke, istSchub: schub, orte: orte)
}

struct SchmerzUebersichtTests {
    let heute = tag(2026, 10, 7)

    @Test func leereDatenErgebenLeereUebersicht() {
        let u = SchmerzUebersicht.berechne(punkte: [], heute: heute)
        #expect(u.heuteSchnitt == nil)
        #expect(u.heuteAnzahl == 0)
        #expect(u.letzterEintrag == nil)
        #expect(u.topOrte.isEmpty)
        #expect(u.ortIntensitaeten.isEmpty)
        #expect(u.letzterSchub == nil)
    }

    @Test func heuteSchnittUndAnzahl() {
        let u = SchmerzUebersicht.berechne(punkte: [punkt(heute, 4), punkt(heute, 7), punkt(tag(2026, 10, 6), 2)], heute: heute)
        #expect(u.heuteSchnitt == 5.5)
        #expect(u.heuteAnzahl == 2)
    }

    @Test func staerksterSchmerzNurLetzteSiebenTage() {
        let u = SchmerzUebersicht.berechne(
            punkte: [punkt(tag(2026, 9, 30), 10), punkt(tag(2026, 10, 3), 8), punkt(heute, 3)],
            heute: heute
        )
        #expect(u.staerkster7Tage == 8)   // 30.9. liegt außerhalb der 7 Tage
        #expect(u.verlauf7 == [8, 3])
    }

    @Test func letzterSchubMitTagesabstand() {
        let u = SchmerzUebersicht.berechne(
            punkte: [punkt(tag(2026, 10, 1), 6, schub: true), punkt(tag(2026, 10, 4), 4, schub: true), punkt(heute, 3)],
            heute: heute
        )
        #expect(u.letzterSchub?.staerke == 4)
        #expect(u.letzterSchub?.vorTagen == 3)
    }

    @Test func haeufigsteOrteNormalisiertUndSortiert() {
        let u = SchmerzUebersicht.berechne(
            punkte: [
                punkt(heute, 5, orte: ["Knie links"]),
                punkt(tag(2026, 10, 6), 5, orte: ["Knie links", "Kopf"]),
                punkt(tag(2026, 10, 5), 5, orte: ["Kopf"]),
                punkt(tag(2026, 10, 4), 5, orte: ["Knie links"]),
                punkt(tag(2026, 8, 1), 5, orte: ["Rücken"])   // älter als 30 Tage
            ],
            heute: heute
        )
        #expect(u.haeufigsterOrt == SchmerzUebersicht.Ort(name: "Knie links", anzahl: 3))
        #expect(u.topOrte.map(\.name) == ["Knie links", "Kopf"])
        #expect(u.ortIntensitaeten["Knie links"] == 1.0)
        #expect(u.ortIntensitaeten["Kopf"] == 2.0 / 3.0)
        #expect(u.ortIntensitaeten["Rücken"] == nil)
    }

    @Test func ortWirdJeEintragGezaehlt() {
        let u = SchmerzUebersicht.berechne(
            punkte: [punkt(heute, 5, orte: ["Kopf"], stunde: 8), punkt(heute, 6, orte: ["Kopf"], stunde: 20)],
            heute: heute
        )
        #expect(u.haeufigsterOrt?.anzahl == 2)   // je Eintrag, wie in der Analyse
    }

    @Test func trendTextRichtung() {
        var u = SchmerzUebersicht()
        u.trend = TrendErgebnis(aktuell: 5, vorher: 4.2)
        #expect(u.trendText == "↑ 0.8 zur Vorwoche")
        u.trend = TrendErgebnis(aktuell: 4, vorher: 4.01)
        #expect(u.trendText == "= wie letzte Woche")
        u.trend = nil
        #expect(u.trendText == nil)
    }
}
