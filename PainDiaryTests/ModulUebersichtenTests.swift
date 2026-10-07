import Testing
import Foundation
@testable import PainDiary

private func tag(_ j: Int, _ m: Int, _ t: Int) -> DayKey { DayKey(jahr: j, monat: m, tag: t) }

private func datum(_ t: DayKey) -> Date {
    var kal = Calendar(identifier: .gregorian)
    kal.timeZone = .current
    return kal.date(from: DateComponents(year: t.jahr, month: t.monat, day: t.tag, hour: 12))!
}

struct HautUebersichtTests {
    let heute = tag(2026, 10, 7)

    private func punkt(_ t: DayKey, stellen: [String] = [], arten: [String] = []) -> HautMesspunkt {
        HautMesspunkt(datum: datum(t), tag: t, stellen: stellen, arten: arten)
    }

    @Test func leer() {
        let u = HautUebersicht.berechne(punkte: [], heute: heute)
        #expect(u.anzahl30 == 0)
        #expect(u.haeufigsteStelle == nil)
        #expect(u.letzterVorTagen == nil)
    }

    @Test func haeufigsteStelleArtUndIntensitaet() {
        let u = HautUebersicht.berechne(punkte: [
            punkt(heute, stellen: ["Arm links", "Rücken"], arten: ["Ekzem"]),
            punkt(tag(2026, 10, 5), stellen: ["Arm links"], arten: ["Ekzem", "Rötung"]),
            punkt(tag(2026, 8, 1), stellen: ["Bein rechts"], arten: ["Rötung"])   // älter als 30 Tage
        ], heute: heute)
        #expect(u.anzahl30 == 2)
        #expect(u.haeufigsteStelle == "Arm links")
        #expect(u.haeufigsteArt == "Ekzem")
        #expect(u.stellenIntensitaeten == ["Arm links": 1.0, "Rücken": 0.5])
        #expect(u.letzterVorTagen == 0)
    }

    @Test func gleichstandIstAlphabetisch() {
        let u = HautUebersicht.berechne(punkte: [punkt(heute, stellen: ["B", "A"])], heute: heute)
        #expect(u.topStellen.map(\.name) == ["A", "B"])
    }
}

struct RheumaUebersichtTests {
    let heute = tag(2026, 10, 7)

    private func punkt(_ t: DayKey, _ s: Int, schub: Bool = false, mg: Int = 0) -> RheumaMesspunkt {
        RheumaMesspunkt(datum: datum(t), tag: t, staerke: s, istSchub: schub, morgensteifigkeit: mg)
    }

    @Test func leer() {
        let u = RheumaUebersicht.berechne(punkte: [], heute: heute)
        #expect(u.schnitt30 == nil)
        #expect(u.steifigkeitSchnitt30 == nil)
        #expect(u.schuebe30 == 0)
    }

    @Test func schnittSchuebeUndSteifigkeitNurImMonat() {
        let u = RheumaUebersicht.berechne(punkte: [
            punkt(heute, 6, schub: true, mg: 60),
            punkt(tag(2026, 10, 1), 2, mg: 0),
            punkt(tag(2026, 10, 2), 4, mg: 30),
            punkt(tag(2026, 7, 1), 10, schub: true, mg: 90)   // außerhalb 30 Tage
        ], heute: heute)
        #expect(u.anzahl30 == 3)
        #expect(u.schnitt30 == 4.0)
        #expect(u.schuebe30 == 1)
        #expect(u.steifigkeitSchnitt30 == 45.0)
    }
}
