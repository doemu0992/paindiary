import Testing
import Foundation
import SwiftData
@testable import PainDiary

// MARK: - Hilfen

@MainActor
private func testContext() throws -> ModelContext {
    let schema = Schema(PersistenceController.alleTypen)
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    return ModelContext(try ModelContainer(for: schema, configurations: [config]))
}

private func zeit(_ j: Int, _ m: Int, _ t: Int, _ h: Int = 12, _ min: Int = 0, tz: String = "UTC") -> Date {
    var kal = Calendar(identifier: .gregorian)
    kal.timeZone = TimeZone(identifier: tz)!
    return kal.date(from: DateComponents(year: j, month: m, day: t, hour: h, minute: min))!
}

// MARK: - Modelle

@MainActor
struct ModellTests {
    @Test func neuerEintragTraegtZeitzoneUndLegacyArt() {
        let e = PainEntry(koerperstelle: "Kopf")
        #expect(e.timeZoneID == TimeZone.current.identifier)
        #expect(e.eintragsArt == .schmerz)
        #expect(e.stimmung == 0)          // nicht erfasst statt Fake-Wert 3
        #expect(e.stressLevel == 0)

        #expect(PainEntry(koerperstelle: "Rheuma").eintragsArt == .rheuma)
        let haut = PainEntry()
        haut.istHautEintrag = true
        #expect(haut.eintragsArt == .haut)
    }

    @Test func artSetterHaeltLegacyFelderKonsistent() {
        let e = PainEntry(koerperstelle: "Kopf")
        e.eintragsArt = .rheuma
        #expect(e.koerperstelle == "Rheuma")
        e.eintragsArt = .haut
        #expect(e.istHautEintrag)
        #expect(e.artRaw == "haut")
    }

    @Test func tagFolgtDerErfassungsZeitzone() {
        let e = PainEntry(datum: zeit(2026, 10, 5, 12))
        e.timeZoneID = "Pacific/Auckland"
        #expect(e.tag == DayKey(jahr: 2026, monat: 10, tag: 6))
        e.timeZoneID = "America/Los_Angeles"
        #expect(e.tag == DayKey(jahr: 2026, monat: 10, tag: 5))
        e.timeZoneID = "Ungueltig/Zone"       // fällt auf aktuelle Zeitzone zurück statt zu crashen
        _ = e.tag
    }

    @Test func einnahmeLogVerknuepfung() {
        let med = Dauermedikation(name: "Ibuprofen", dosierung: "400 mg")
        let neu = EinnahmeLog(medikamentName: "Ibuprofen", dosierung: "400 mg", medikamentID: med.notifID)
        #expect(neu.gehoertZu(med))
        // Nach Umbenennung bleibt die Zuordnung über die ID erhalten
        med.name = "Ibuprofen akut"
        #expect(neu.gehoertZu(med))
        // Altdaten ohne ID: Name + Dosierung
        let alt = EinnahmeLog(medikamentName: "Ibuprofen akut", dosierung: "400 mg")
        #expect(alt.gehoertZu(med))
        let fremd = EinnahmeLog(medikamentName: "X", dosierung: "1", medikamentID: "andere")
        #expect(!fremd.gehoertZu(med))
    }
}

// MARK: - Normalisierung

@MainActor
struct NormalisierungTests {
    @Test func begrenztUngueltigeWerte() {
        let e = PainEntry(schmerzstaerke: 15, stimmung: 9, schlafStunden: 30, stressLevel: -1, fatigue: 99)
        let k = Normalisierung.normalisiere(e)
        #expect(e.schmerzstaerke == 10)
        #expect(e.stimmung == 5)
        #expect(e.stressLevel == 0)
        #expect(e.fatigue == 10)
        #expect(e.schlafStunden == 24)
        #expect(k.count >= 5)
    }

    @Test func zukunftsdatumWirdAufJetztGesetzt() {
        let e = PainEntry(datum: Date().addingTimeInterval(7 * 86_400))
        Normalisierung.normalisiere(e)
        #expect(e.datum <= Date().addingTimeInterval(5))
    }

    @Test func migraeneEndeVorBeginnWirdVerworfen() {
        let a = MigraeneEintrag(datum: zeit(2026, 10, 5, 12))
        a.endZeit = zeit(2026, 10, 5, 10)
        Normalisierung.normalisiere(a)
        #expect(a.endZeit == nil)
    }

    @Test func blutzuckerAusserhalbMessbereichWirft() throws {
        let ctx = try testContext()
        #expect(throws: ValidierungsFehler.self) { try ctx.einfuegenValidiert(BlutzuckerEintrag(wert: 0)) }
        try ctx.einfuegenValidiert(BlutzuckerEintrag(wert: 5.5))
        #expect(try ctx.fetchCount(FetchDescriptor<BlutzuckerEintrag>()) == 1)
    }
}

// MARK: - Datenpflege

@MainActor
struct DatenPflegeTests {
    @Test func backfillSetztArtZeitzoneUndMedikamentenID() throws {
        let ctx = try testContext()
        let rheuma = PainEntry(koerperstelle: "Rheuma")
        rheuma.timeZoneID = ""
        ctx.insert(rheuma)

        let med = Dauermedikation(name: "MTX", dosierung: "15 mg")
        ctx.insert(med)
        let eindeutig = EinnahmeLog(medikamentName: "MTX", dosierung: "15 mg")
        ctx.insert(eindeutig)

        let bericht = DatenPflege.run(context: ctx, ignoriereVersion: true)
        #expect(rheuma.artRaw == "rheuma")
        #expect(!rheuma.timeZoneID.isEmpty)
        #expect(eindeutig.medikamentID == med.notifID)
        #expect(bericht.artGesetzt == 1)
        #expect(bericht.logsVerknuepft == 1)
    }

    @Test func mehrdeutigeLogsBleibenUnverknuepft() throws {
        let ctx = try testContext()
        ctx.insert(Dauermedikation(name: "A", dosierung: "1"))
        ctx.insert(Dauermedikation(name: "A", dosierung: "1"))
        let log = EinnahmeLog(medikamentName: "A", dosierung: "1")
        ctx.insert(log)
        DatenPflege.run(context: ctx, ignoriereVersion: true)
        #expect(log.medikamentID.isEmpty)
    }

    @Test func wellnessDuplikateDesselbenTagesWerdenZusammengefuehrt() throws {
        let ctx = try testContext()
        let a = WellnessEintrag(datum: zeit(2026, 10, 5, 8, tz: "Europe/Zurich"))
        a.timeZoneID = "Europe/Zurich"; a.wasserMl = 500; a.stimmung = 0; a.notizen = "morgens"
        let b = WellnessEintrag(datum: zeit(2026, 10, 5, 20, tz: "Europe/Zurich"))
        b.timeZoneID = "Europe/Zurich"; b.wasserMl = 1200; b.stimmung = 4; b.notizen = "abends"
        let anderer = WellnessEintrag(datum: zeit(2026, 10, 6, 8, tz: "Europe/Zurich"))
        anderer.timeZoneID = "Europe/Zurich"
        [a, b, anderer].forEach { ctx.insert($0) }
        try ctx.save()

        let entfernt = try DatenPflege.dedupliziereWellness(context: ctx)
        try ctx.save()
        let rest = try ctx.fetch(FetchDescriptor<WellnessEintrag>(sortBy: [SortDescriptor(\.datum)]))
        #expect(entfernt == 1)
        #expect(rest.count == 2)
        #expect(rest[0].wasserMl == 1200)
        #expect(rest[0].stimmung == 4)
        #expect(rest[0].notizen.contains("morgens") && rest[0].notizen.contains("abends"))
    }
}

// MARK: - Repository & Löschen

@MainActor
struct RepositoryTests {
    private func befuellen(_ ctx: ModelContext) {
        let a = PainEntry(datum: zeit(2026, 10, 1), schmerzstaerke: 3, koerperstelle: "Kopf", notizen: "Wetterumschwung")
        let b = PainEntry(datum: zeit(2026, 10, 3), schmerzstaerke: 6, koerperstelle: "Rücken")
        let c = PainEntry(datum: zeit(2026, 10, 5), schmerzstaerke: 4, koerperstelle: "Rheuma")
        [a, b, c].forEach { ctx.insert($0) }
    }

    @Test func zeitraumUndReihenfolge() throws {
        let ctx = try testContext(); befuellen(ctx)
        let repo = PainRepository(context: ctx)
        let alle = try repo.eintraege()
        #expect(alle.map(\.schmerzstaerke) == [4, 6, 3])    // neueste zuerst
        let teil = try repo.eintraege(von: zeit(2026, 10, 2), bis: zeit(2026, 10, 4))
        #expect(teil.count == 1 && teil[0].schmerzstaerke == 6)
    }

    @Test func artFilterUndLimit() throws {
        let ctx = try testContext(); befuellen(ctx)
        let repo = PainRepository(context: ctx)
        #expect(try repo.eintraege(art: .rheuma).count == 1)
        #expect(try repo.eintraege(art: .schmerz, limit: 1).count == 1)
        #expect(try repo.eintraege(limit: 2).count == 2)
    }

    @Test func sucheUndLetzter() throws {
        let ctx = try testContext(); befuellen(ctx)
        let repo = PainRepository(context: ctx)
        #expect(try repo.suche("wetter").count == 1)
        #expect(try repo.suche("").count == 3)
        #expect(try repo.suche("gibtesnicht").isEmpty)
        #expect(try repo.letzter()?.schmerzstaerke == 4)
        #expect(try repo.anzahl(seit: zeit(2026, 10, 2)) == 2)
    }

    @Test func leereDatenbankIstKeinFehler() throws {
        let repo = PainRepository(context: try testContext())
        #expect(try repo.eintraege().isEmpty)
        #expect(try repo.letzter() == nil)
        #expect(try repo.datensaetze().isEmpty)
    }

    @Test func loeschserviceEntferntEintrag() throws {
        let ctx = try testContext(); befuellen(ctx)
        let repo = PainRepository(context: ctx)
        let ziel = try #require(try repo.letzter())
        EintragLoeschService(context: ctx).loesche(ziel)
        #expect(try repo.eintraege().count == 2)
    }
}

// MARK: - HeuteViewModel

@MainActor
struct HeuteViewModelTests {
    @Test func tagesschnittOhneRheumaUndHaut() {
        let jetzt = Date()
        let a = PainEntry(datum: jetzt, schmerzstaerke: 4, koerperstelle: "Kopf")
        let b = PainEntry(datum: jetzt, schmerzstaerke: 6, koerperstelle: "Rücken")
        let rheuma = PainEntry(datum: jetzt, schmerzstaerke: 9, koerperstelle: "Rheuma")
        let vm = HeuteViewModel()
        vm.aktualisiere(eintraege: [a, b, rheuma], jetzt: jetzt)
        #expect(vm.heuteSchnitt == 5)
        #expect(vm.heuteAnzahl == 2)
        #expect(vm.wocheDaten.count == 1)
    }

    @Test func leerZustand() {
        let vm = HeuteViewModel()
        vm.aktualisiere(eintraege: [])
        #expect(vm.heuteSchnitt == nil)
        #expect(vm.trendText == nil)
        #expect(vm.schubHinweis == nil)
        #expect(vm.uebergebrauch == nil)
    }
}

// MARK: - Export

@MainActor
struct ExportTests {
    @Test func csvEscapeSchuetztVorFormelInjection() {
        #expect(CSVExportService.escape("=SUM(A1)") == "'=SUM(A1)")
        #expect(CSVExportService.escape("@cmd") == "'@cmd")
        #expect(CSVExportService.escape("+1") == "'+1")
        #expect(CSVExportService.escape("a,b") == "\"a,b\"")
        #expect(CSVExportService.escape("sagt \"hi\"") == "\"sagt \"\"hi\"\"\"")
        #expect(CSVExportService.escape("Zeile1\nZeile2") == "\"Zeile1\nZeile2\"")
        #expect(CSVExportService.escape("normal") == "normal")
        #expect(CSVExportService.escape("") == "")
    }

    @Test func isoZeitpunktMitOffset() {
        let moment = zeit(2026, 10, 5, 12, 0, tz: "UTC")
        #expect(CSVExportService.iso(moment, TimeZone(identifier: "Europe/Zurich")!) == "2026-10-05T14:00:00+02:00")
        #expect(CSVExportService.iso(moment, TimeZone(identifier: "UTC")!) == "2026-10-05T12:00:00Z")
    }

    @Test func schmerzCSVSpaltenzahlUndLeereZellen() {
        let e = PainEntry(datum: zeit(2026, 10, 5), schmerzstaerke: 7, koerperstelle: "Kopf")
        e.wetterTemperatur = -3.5
        let csv = CSVExportService.schmerzCSV([e])
        let zeilen = csv.components(separatedBy: "\n")
        #expect(zeilen.count == 2)
        let kopf = zeilen[0].components(separatedBy: ",")
        let zelle = zeilen[1].components(separatedBy: ",")
        #expect(kopf.count == zelle.count)
        let idxStimmung = try! #require(kopf.firstIndex(of: "Stimmung (1-5)"))
        #expect(zelle[idxStimmung].isEmpty)           // nicht erfasst → leer, nicht „0"
        let idxTemp = try! #require(kopf.firstIndex(of: "Temperatur (°C)"))
        #expect(zelle[idxTemp] == "-3.5")             // negative Temperatur bleibt erhalten
    }

    @Test func leererExportLiefertTrotzdemEineDatei() throws {
        let urls = try CSVExportService.erstelleVollExport(quellen: .init())
        #expect(urls.count == 1)
        let daten = try Data(contentsOf: urls[0])
        #expect(Array(daten.prefix(3)) == [0xEF, 0xBB, 0xBF])   // UTF-8-BOM
        CSVExportService.raeumeAltExporteAuf()
    }
}

// MARK: - Backup

@MainActor
struct BackupTests {
    @Test func roundtripUndIdempotenterImport() throws {
        let quelle = try testContext()
        let e = PainEntry(datum: zeit(2026, 10, 5), schmerzstaerke: 6, koerperstelle: "Kopf", ausloeser: "Stress")
        quelle.insert(e)
        quelle.insert(MigraeneEintrag(datum: zeit(2026, 10, 4), staerke: 8))
        let med = Dauermedikation(name: "Sumatriptan", dosierung: "50 mg")
        quelle.insert(med)
        quelle.insert(EinnahmeLog(datum: zeit(2026, 10, 4, 13), medikamentName: "Sumatriptan", dosierung: "50 mg", medikamentID: med.notifID))
        quelle.insert(BlutzuckerEintrag(datum: zeit(2026, 10, 3), wert: 6.2))
        let w = WellnessEintrag(datum: zeit(2026, 10, 2)); w.wasserMl = 1500
        quelle.insert(w)
        let z = ZyklusEintrag(datum: zeit(2026, 10, 1)); z.istPeriode = true
        quelle.insert(z)
        try quelle.save()

        let url = try BackupService.erstelleBackup(context: quelle)
        let daten = try Data(contentsOf: url)

        let ziel = try testContext()
        let erster = try BackupService.importiere(daten: daten, context: ziel)
        #expect(erster.hinzugefuegt == 7)
        #expect(erster.uebersprungen == 0)
        let kopie = try #require(try ziel.fetch(FetchDescriptor<PainEntry>()).first)
        #expect(kopie.schmerzstaerke == 6 && kopie.ausloeser == "Stress")
        #expect(try ziel.fetch(FetchDescriptor<EinnahmeLog>()).first?.medikamentID == med.notifID)

        let zweiter = try BackupService.importiere(daten: daten, context: ziel)
        #expect(zweiter.hinzugefuegt == 0)
        #expect(zweiter.uebersprungen == 7)
        #expect(try ziel.fetchCount(FetchDescriptor<PainEntry>()) == 1)
    }

    @Test func ungueltigeDateiWirdAbgelehnt() throws {
        let ctx = try testContext()
        #expect(throws: BackupService.BackupFehler.self) {
            try BackupService.importiere(daten: Data("kein json".utf8), context: ctx)
        }
    }

    @Test func neuereFormatVersionWirdAbgelehnt() throws {
        let ctx = try testContext()
        let json = #"{"formatVersion": 999, "erstelltAm": "2026-10-05T12:00:00Z", "appBuild": "1", "schmerz": [], "migraene": [], "medikamente": [], "einnahmen": [], "blutzucker": [], "wellness": [], "zyklus": []}"#
        #expect(throws: BackupService.BackupFehler.self) {
            try BackupService.importiere(daten: Data(json.utf8), context: ctx)
        }
    }
}

// MARK: - Arzt-Zusammenfassung

struct ArztZusammenfassungTests {
    @Test func kennzahlenUndTopListen() {
        func d(_ t: Int, _ s: Int, _ ort: [String], _ aus: [String] = []) -> SchmerzDatensatz {
            SchmerzDatensatz(tag: DayKey(jahr: 2026, monat: 10, tag: t), staerke: s, koerperstellen: ort, ausloeser: aus)
        }
        let daten = [d(1, 0, []), d(2, 4, ["Kopf"], ["Stress"]), d(3, 8, ["Kopf", "Nacken"], ["Stress", "Wetter"]), d(20, 9, ["Knie"])]
        let z = ArztZusammenfassung.erstelle(datensaetze: daten,
                                             von: DayKey(jahr: 2026, monat: 10, tag: 1),
                                             bis: DayKey(jahr: 2026, monat: 10, tag: 7))
        #expect(z.eintraege == 3)                 // Tag 20 liegt außerhalb
        #expect(z.erfassteTage == 3)
        #expect(z.maximaleStaerke == 8)
        #expect(z.schmerzfreieTage == 1)
        #expect(abs((z.mittlereStaerke ?? 0) - 4) < 1e-9)
        #expect(z.topKoerperstellen.first == HaeufigerEintrag(name: "Kopf", anzahl: 2))
        #expect(z.topAusloeser.first == HaeufigerEintrag(name: "Stress", anzahl: 2))
    }

    @Test func leererZeitraum() {
        let z = ArztZusammenfassung.erstelle(datensaetze: [], von: DayKey(jahr: 2026, monat: 10, tag: 1), bis: DayKey(jahr: 2026, monat: 10, tag: 7))
        #expect(z.eintraege == 0)
        #expect(z.mittlereStaerke == nil)
        #expect(z.maximaleStaerke == nil)
        #expect(z.trend == nil)
    }
}
