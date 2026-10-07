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

struct DiabetesUebersichtTests {
    let heute = tag(2026, 10, 7)

    private func punkt(_ t: DayKey, _ w: Double, _ zeit: String = "Nüchtern", ie: Double = 0) -> BlutzuckerMesspunkt {
        BlutzuckerMesspunkt(datum: datum(t), tag: t, wert: w, messZeitpunkt: zeit, insulinEinheiten: ie, bewertung: "")
    }

    @Test func leer() {
        let u = DiabetesUebersicht.berechne(punkte: [], heute: heute)
        #expect(u.zielAnteil30 == nil)
        #expect(u.letzteMessung == nil)
        #expect(u.insulinHeute == 0)
    }

    @Test func zielanteilHyposUndNuechternSchnitt() {
        let u = DiabetesUebersicht.berechne(punkte: [
            punkt(heute, 5.0),                        // Ziel
            punkt(heute, 3.5, "Vor dem Essen"),        // Hypo
            punkt(tag(2026, 10, 5), 9.0, "Nach dem Essen"),   // zu hoch
            punkt(tag(2026, 10, 4), 7.0),              // Ziel, nüchtern
            punkt(tag(2026, 7, 1), 12.0)               // außerhalb 30 Tage
        ], heute: heute)
        #expect(u.anzahl30 == 4)
        #expect(u.zielAnteil30 == 0.5)
        #expect(u.hypos30 == 1)
        #expect(u.nuechternSchnitt30 == 6.0)
    }

    @Test func grenzwerteGehoerenZumZielbereich() {
        let u = DiabetesUebersicht.berechne(punkte: [punkt(heute, 3.9), punkt(heute, 7.8)], heute: heute)
        #expect(u.zielAnteil30 == 1.0)
        #expect(u.hypos30 == 0)
    }

    @Test func insulinNurHeuteUndVerlaufSieben() {
        let u = DiabetesUebersicht.berechne(punkte: [
            punkt(heute, 5, ie: 4), punkt(heute, 6, ie: 2), punkt(tag(2026, 10, 6), 8, ie: 10),
            punkt(tag(2026, 9, 20), 5)
        ], heute: heute)
        #expect(u.insulinHeute == 6)
        #expect(u.verlauf7 == [8, 5.5])
    }
}

struct MigraeneUebersichtTests {
    let heute = tag(2026, 10, 7)

    private func punkt(_ t: DayKey, _ s: Int, dauer: Int = 0, ausloeser: [String] = [], akut: Bool = false) -> MigraeneMesspunkt {
        MigraeneMesspunkt(datum: datum(t), tag: t, staerke: s, dauerMinuten: dauer, ausloeser: ausloeser, nahmAkutmedikament: akut)
    }

    @Test func leer() {
        let u = MigraeneUebersicht.berechne(punkte: [], heute: heute)
        #expect(u.anzahl30 == 0)
        #expect(u.staerkeSchnitt30 == nil)
        #expect(u.letzterVorTagen == nil)
    }

    @Test func anfallstageSchnittDauerUndAusloeser() {
        let u = MigraeneUebersicht.berechne(punkte: [
            punkt(heute, 8, dauer: 120, ausloeser: ["Stress", "Wetter"], akut: true),
            punkt(heute, 6, dauer: 60, ausloeser: ["Stress"], akut: true),
            punkt(tag(2026, 10, 3), 4, ausloeser: ["Wetter"]),
            punkt(tag(2026, 7, 1), 10, ausloeser: ["Alkohol"])   // außerhalb 30 Tage
        ], heute: heute)
        #expect(u.anzahl30 == 3)
        #expect(u.anfallstage30 == 2)
        #expect(u.staerkeSchnitt30 == 6.0)
        #expect(u.dauerSchnittMinuten30 == 90.0)
        #expect(u.haeufigsterAusloeser == MigraeneUebersicht.Ausloeser(name: "Stress", anzahl: 2))
        #expect(u.akuttage30 == 1)   // zwei Einnahmen am selben Tag zählen einmal
        #expect(u.letzterVorTagen == 0)
    }
}
