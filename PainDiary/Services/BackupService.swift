import Foundation
import SwiftData

/// JSON-Backup der Gesundheitsdaten (Schmerz, Migräne, Medikation, Einnahmen, Blutzucker, Wellness, Zyklus)
/// mit Wiederherstellung (Import fügt hinzu und überspringt vorhandene Einträge → idempotent).
///
/// Nicht enthalten: Fotos (Hauteinträge), Arzt-/Profil-/Rheuma-Stammdaten. Diese sichert die
/// Datenbank-Kopie (`PersistenceController.snapshots()` / Datenbank-Dateien teilen).
@MainActor
enum BackupService {
    static let formatVersion = 1
    static let maxDateigroesse = 200 * 1024 * 1024

    enum BackupFehler: LocalizedError {
        case zuNeu(Int)
        case zuGross
        case ungueltig

        var errorDescription: String? {
            switch self {
            case .zuNeu(let v): return "Das Backup wurde mit einer neueren App-Version erstellt (Format \(v)). Bitte aktualisiere die App."
            case .zuGross: return "Die Backup-Datei ist zu groß."
            case .ungueltig: return "Die Datei ist kein gültiges PainDiary-Backup."
            }
        }
    }

    struct ImportBericht: Equatable {
        var hinzugefuegt = 0
        var uebersprungen = 0
    }

    // MARK: - Datei

    struct BackupDatei: Codable {
        var formatVersion: Int
        var erstelltAm: Date
        var appBuild: String
        var schmerz: [PainDTO] = []
        var migraene: [MigraeneDTO] = []
        var medikamente: [MedikamentDTO] = []
        var einnahmen: [EinnahmeDTO] = []
        var blutzucker: [BlutzuckerDTO] = []
        var wellness: [WellnessDTO] = []
        var zyklus: [ZyklusDTO] = []
    }

    // MARK: - Erstellen

    static func erstelleBackup(context: ModelContext) throws -> URL {
        var datei = BackupDatei(
            formatVersion: formatVersion, erstelltAm: Date(),
            appBuild: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "")
        datei.schmerz = try context.fetch(FetchDescriptor<PainEntry>(sortBy: [SortDescriptor(\.datum)])).map(PainDTO.init)
        datei.migraene = try context.fetch(FetchDescriptor<MigraeneEintrag>(sortBy: [SortDescriptor(\.datum)])).map(MigraeneDTO.init)
        datei.medikamente = try context.fetch(FetchDescriptor<Dauermedikation>()).map(MedikamentDTO.init)
        datei.einnahmen = try context.fetch(FetchDescriptor<EinnahmeLog>(sortBy: [SortDescriptor(\.datum)])).map(EinnahmeDTO.init)
        datei.blutzucker = try context.fetch(FetchDescriptor<BlutzuckerEintrag>(sortBy: [SortDescriptor(\.datum)])).map(BlutzuckerDTO.init)
        datei.wellness = try context.fetch(FetchDescriptor<WellnessEintrag>(sortBy: [SortDescriptor(\.datum)])).map(WellnessDTO.init)
        datei.zyklus = try context.fetch(FetchDescriptor<ZyklusEintrag>(sortBy: [SortDescriptor(\.datum)])).map(ZyklusDTO.init)

        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        let daten = try enc.encode(datei)

        let ordner = FileManager.default.temporaryDirectory.appendingPathComponent("PainDiaryBackup", isDirectory: true)
        try? FileManager.default.removeItem(at: ordner)
        try FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        let name = "PainDiary-Backup-\(CSVExportService.tagText(DayKey.heute())).json"
        let url = ordner.appendingPathComponent(name)
        try daten.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    // MARK: - Wiederherstellen

    static func importiere(url: URL, context: ModelContext) throws -> ImportBericht {
        let zugriff = url.startAccessingSecurityScopedResource()
        defer { if zugriff { url.stopAccessingSecurityScopedResource() } }

        let attribute = try? FileManager.default.attributesOfItem(atPath: url.path)
        if let groesse = attribute?[.size] as? Int, groesse > maxDateigroesse { throw BackupFehler.zuGross }
        let daten = try Data(contentsOf: url)
        return try importiere(daten: daten, context: context)
    }

    static func importiere(daten: Data, context: ModelContext) throws -> ImportBericht {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        guard let datei = try? dec.decode(BackupDatei.self, from: daten) else { throw BackupFehler.ungueltig }
        guard datei.formatVersion <= formatVersion else { throw BackupFehler.zuNeu(datei.formatVersion) }

        var bericht = ImportBericht()
        func sek(_ d: Date) -> Int { Int(d.timeIntervalSince1970.rounded()) }

        // Schmerz
        let vorhandenSchmerz = Set(try context.fetch(FetchDescriptor<PainEntry>()).map { "\(sek($0.datum))|\($0.schmerzstaerke)|\($0.koerperstelle)|\($0.eintragsArt.rawValue)" })
        for dto in datei.schmerz {
            let e = dto.modell()
            let key = "\(sek(e.datum))|\(e.schmerzstaerke)|\(e.koerperstelle)|\(e.eintragsArt.rawValue)"
            if vorhandenSchmerz.contains(key) { bericht.uebersprungen += 1; continue }
            Normalisierung.normalisiere(e)
            context.insert(e); bericht.hinzugefuegt += 1
        }
        // Migräne
        let vorhandenMigraene = Set(try context.fetch(FetchDescriptor<MigraeneEintrag>()).map { "\(sek($0.datum))|\($0.staerke)" })
        for dto in datei.migraene {
            let a = dto.modell()
            if vorhandenMigraene.contains("\(sek(a.datum))|\(a.staerke)") { bericht.uebersprungen += 1; continue }
            Normalisierung.normalisiere(a)
            context.insert(a); bericht.hinzugefuegt += 1
        }
        // Medikamente (eindeutig über notifID)
        let vorhandenMeds = Set(try context.fetch(FetchDescriptor<Dauermedikation>()).map(\.notifID))
        for dto in datei.medikamente {
            if vorhandenMeds.contains(dto.notifID) { bericht.uebersprungen += 1; continue }
            context.insert(dto.modell()); bericht.hinzugefuegt += 1
        }
        // Einnahmen
        let vorhandenLogs = Set(try context.fetch(FetchDescriptor<EinnahmeLog>()).map { "\(sek($0.datum))|\($0.medikamentName)|\($0.dosierung)" })
        for dto in datei.einnahmen {
            if vorhandenLogs.contains("\(sek(dto.datum))|\(dto.medikamentName)|\(dto.dosierung)") { bericht.uebersprungen += 1; continue }
            context.insert(dto.modell()); bericht.hinzugefuegt += 1
        }
        // Blutzucker
        let vorhandenBZ = Set(try context.fetch(FetchDescriptor<BlutzuckerEintrag>()).map { "\(sek($0.datum))|\($0.wert)" })
        for dto in datei.blutzucker {
            if vorhandenBZ.contains("\(sek(dto.datum))|\(dto.wert)") { bericht.uebersprungen += 1; continue }
            guard (try? Validierung.pruefeBlutzucker(dto.wert)) != nil else { bericht.uebersprungen += 1; continue }
            context.insert(dto.modell()); bericht.hinzugefuegt += 1
        }
        // Wellness (ein Eintrag pro Tag)
        let vorhandenWellness = Set(try context.fetch(FetchDescriptor<WellnessEintrag>()).map { $0.tag })
        for dto in datei.wellness {
            let w = dto.modell()
            if vorhandenWellness.contains(w.tag) { bericht.uebersprungen += 1; continue }
            context.insert(w); bericht.hinzugefuegt += 1
        }
        // Zyklus
        let vorhandenZyklus = Set(try context.fetch(FetchDescriptor<ZyklusEintrag>()).map { "\(sek($0.datum))|\($0.typ)|\($0.istPeriode)" })
        for dto in datei.zyklus {
            if vorhandenZyklus.contains("\(sek(dto.datum))|\(dto.typ)|\(dto.istPeriode)") { bericht.uebersprungen += 1; continue }
            context.insert(dto.modell()); bericht.hinzugefuegt += 1
        }

        try context.save()
        return bericht
    }
}

// MARK: - DTOs

extension BackupService {

    struct PainDTO: Codable {
        var datum: Date; var schmerzstaerke: Int; var koerperstelle: String; var schmerzart: String
        var dauerMinuten: Int; var ausloeser: String; var begleiterscheinungen: String; var massnahmen: String
        var notizen: String; var stimmung: Int; var schlafStunden: Double; var stressLevel: Int
        var morgensteifigkeit: Int; var istSchub: Bool; var fatigue: Int; var energielevel: Int
        var gelenkStatus: String; var wetterTemperatur: Double?; var wetterCode: Int?; var wetterWind: Double?
        var istHautEintrag: Bool; var hautStellen: String; var hautArt: String; var fotoDateiname: String
        var verlauf: String; var artRaw: String; var timeZoneID: String

        init(_ e: PainEntry) {
            datum = e.datum; schmerzstaerke = e.schmerzstaerke; koerperstelle = e.koerperstelle; schmerzart = e.schmerzart
            dauerMinuten = e.dauerMinuten; ausloeser = e.ausloeser; begleiterscheinungen = e.begleiterscheinungen
            massnahmen = e.massnahmen; notizen = e.notizen; stimmung = e.stimmung; schlafStunden = e.schlafStunden
            stressLevel = e.stressLevel; morgensteifigkeit = e.morgensteifigkeit; istSchub = e.istSchub
            fatigue = e.fatigue; energielevel = e.energielevel; gelenkStatus = e.gelenkStatus
            wetterTemperatur = e.wetterTemperatur; wetterCode = e.wetterCode; wetterWind = e.wetterWind
            istHautEintrag = e.istHautEintrag; hautStellen = e.hautStellen; hautArt = e.hautArt
            fotoDateiname = e.fotoDateiname; verlauf = e.verlauf; artRaw = e.artRaw; timeZoneID = e.timeZoneID
        }

        func modell() -> PainEntry {
            let e = PainEntry(
                datum: datum, schmerzstaerke: schmerzstaerke, koerperstelle: koerperstelle, schmerzart: schmerzart,
                dauerMinuten: dauerMinuten, ausloeser: ausloeser, begleiterscheinungen: begleiterscheinungen,
                massnahmen: massnahmen, notizen: notizen, stimmung: stimmung, schlafStunden: schlafStunden,
                stressLevel: stressLevel, morgensteifigkeit: morgensteifigkeit, istSchub: istSchub,
                fatigue: fatigue, energielevel: energielevel, gelenkStatus: gelenkStatus,
                wetterTemperatur: wetterTemperatur, wetterCode: wetterCode, wetterWind: wetterWind,
                hautStellen: hautStellen, hautArt: hautArt, fotoDateiname: fotoDateiname, verlauf: verlauf)
            e.istHautEintrag = istHautEintrag
            e.artRaw = artRaw
            e.timeZoneID = timeZoneID.isEmpty ? TimeZone.current.identifier : timeZoneID
            return e
        }
    }

    struct MigraeneDTO: Codable {
        var datum: Date; var dauer: Int; var staerke: Int; var seite: String; var charakter: String
        var begleitsymptome: String; var hatAura: Bool; var ausloeser: String; var akutmedikament: String
        var medikamentWirksam: String; var notizen: String
        var wetterTemperatur: Double?; var wetterCode: Int?; var wetterWind: Double?
        var kopfschmerzTyp: String; var prodromsymptome: String; var postdrom: String; var endZeit: Date?
        var zyklusPhase: String; var schlafStunden: Double; var stimmung: Int; var stressLevel: Int
        var fatigue: Int; var energielevel: Int; var timeZoneID: String

        init(_ a: MigraeneEintrag) {
            datum = a.datum; dauer = a.dauer; staerke = a.staerke; seite = a.seite; charakter = a.charakter
            begleitsymptome = a.begleitsymptome; hatAura = a.hatAura; ausloeser = a.ausloeser
            akutmedikament = a.akutmedikament; medikamentWirksam = a.medikamentWirksam; notizen = a.notizen
            wetterTemperatur = a.wetterTemperatur; wetterCode = a.wetterCode; wetterWind = a.wetterWind
            kopfschmerzTyp = a.kopfschmerzTyp; prodromsymptome = a.prodromsymptome; postdrom = a.postdrom
            endZeit = a.endZeit; zyklusPhase = a.zyklusPhase; schlafStunden = a.schlafStunden
            stimmung = a.stimmung; stressLevel = a.stressLevel; fatigue = a.fatigue
            energielevel = a.energielevel; timeZoneID = a.timeZoneID
        }

        func modell() -> MigraeneEintrag {
            let a = MigraeneEintrag(
                datum: datum, dauer: dauer, staerke: staerke, seite: seite, charakter: charakter,
                begleitsymptome: begleitsymptome, hatAura: hatAura, ausloeser: ausloeser,
                akutmedikament: akutmedikament, medikamentWirksam: medikamentWirksam, notizen: notizen,
                wetterTemperatur: wetterTemperatur, wetterCode: wetterCode, wetterWind: wetterWind)
            a.kopfschmerzTyp = kopfschmerzTyp; a.prodromsymptome = prodromsymptome; a.postdrom = postdrom
            a.endZeit = endZeit; a.zyklusPhase = zyklusPhase; a.schlafStunden = schlafStunden
            a.stimmung = stimmung; a.stressLevel = stressLevel; a.fatigue = fatigue; a.energielevel = energielevel
            a.timeZoneID = timeZoneID.isEmpty ? TimeZone.current.identifier : timeZoneID
            return a
        }
    }

    struct MedikamentDTO: Codable {
        var notifID: String; var name: String; var dosierung: String; var frequenz: String
        var startDatum: Date; var aktiv: Bool; var endDatum: Date?; var erinnerungAktiv: Bool
        var erinnerungsZeiten: String; var wirkungsAbfrageStunden: Int; var medikamentTyp: String
        var einnahmeHinweis: String; var vorrat: Int?; var vorratSchwelle: Int; var ablaufDatum: Date?

        init(_ m: Dauermedikation) {
            notifID = m.notifID; name = m.name; dosierung = m.dosierung; frequenz = m.frequenz
            startDatum = m.startDatum; aktiv = m.aktiv; endDatum = m.endDatum; erinnerungAktiv = m.erinnerungAktiv
            erinnerungsZeiten = m.erinnerungsZeiten; wirkungsAbfrageStunden = m.wirkungsAbfrageStunden
            medikamentTyp = m.medikamentTyp; einnahmeHinweis = m.einnahmeHinweis; vorrat = m.vorrat
            vorratSchwelle = m.vorratSchwelle; ablaufDatum = m.ablaufDatum
        }

        func modell() -> Dauermedikation {
            let m = Dauermedikation(name: name, dosierung: dosierung, frequenz: frequenz, startDatum: startDatum, aktiv: aktiv)
            m.notifID = notifID; m.endDatum = endDatum; m.erinnerungAktiv = erinnerungAktiv
            m.erinnerungsZeiten = erinnerungsZeiten; m.wirkungsAbfrageStunden = wirkungsAbfrageStunden
            m.medikamentTyp = medikamentTyp; m.einnahmeHinweis = einnahmeHinweis; m.vorrat = vorrat
            m.vorratSchwelle = vorratSchwelle; m.ablaufDatum = ablaufDatum
            return m
        }
    }

    struct EinnahmeDTO: Codable {
        var datum: Date; var medikamentName: String; var dosierung: String; var eingenommen: Bool
        var notizen: String; var wirkung: String; var medikamentID: String

        init(_ l: EinnahmeLog) {
            datum = l.datum; medikamentName = l.medikamentName; dosierung = l.dosierung
            eingenommen = l.eingenommen; notizen = l.notizen; wirkung = l.wirkung; medikamentID = l.medikamentID
        }

        func modell() -> EinnahmeLog {
            let l = EinnahmeLog(datum: datum, medikamentName: medikamentName, dosierung: dosierung,
                                eingenommen: eingenommen, notizen: notizen, medikamentID: medikamentID)
            l.wirkung = wirkung
            return l
        }
    }

    struct BlutzuckerDTO: Codable {
        var datum: Date; var wert: Double; var messZeitpunkt: String; var insulinEinheiten: Double
        var insulinTyp: String; var kohlenhydrate: Int; var notizen: String; var timeZoneID: String

        init(_ m: BlutzuckerEintrag) {
            datum = m.datum; wert = m.wert; messZeitpunkt = m.messZeitpunkt; insulinEinheiten = m.insulinEinheiten
            insulinTyp = m.insulinTyp; kohlenhydrate = m.kohlenhydrate; notizen = m.notizen; timeZoneID = m.timeZoneID
        }

        func modell() -> BlutzuckerEintrag {
            let m = BlutzuckerEintrag(datum: datum, wert: wert, messZeitpunkt: messZeitpunkt,
                                      insulinEinheiten: insulinEinheiten, insulinTyp: insulinTyp,
                                      kohlenhydrate: kohlenhydrate, notizen: notizen)
            m.timeZoneID = timeZoneID.isEmpty ? TimeZone.current.identifier : timeZoneID
            return m
        }
    }

    struct WellnessDTO: Codable {
        var datum: Date; var wasserMl: Int; var wasserZielMl: Int; var koffeinTassen: Int; var alkoholGlaeser: Int
        var fruehstueck: Bool; var mittag: Bool; var abend: Bool; var stimmung: Int; var stressLevel: Int
        var energielevel: Int; var schlafStunden: Double; var notizen: String; var timeZoneID: String

        init(_ w: WellnessEintrag) {
            datum = w.datum; wasserMl = w.wasserMl; wasserZielMl = w.wasserZielMl; koffeinTassen = w.koffeinTassen
            alkoholGlaeser = w.alkoholGlaeser; fruehstueck = w.fruehstueck; mittag = w.mittag; abend = w.abend
            stimmung = w.stimmung; stressLevel = w.stressLevel; energielevel = w.energielevel
            schlafStunden = w.schlafStunden; notizen = w.notizen; timeZoneID = w.timeZoneID
        }

        func modell() -> WellnessEintrag {
            let w = WellnessEintrag(datum: datum)
            w.wasserMl = wasserMl; w.wasserZielMl = wasserZielMl; w.koffeinTassen = koffeinTassen
            w.alkoholGlaeser = alkoholGlaeser; w.fruehstueck = fruehstueck; w.mittag = mittag; w.abend = abend
            w.stimmung = stimmung; w.stressLevel = stressLevel; w.energielevel = energielevel
            w.schlafStunden = schlafStunden; w.notizen = notizen
            w.timeZoneID = timeZoneID.isEmpty ? TimeZone.current.identifier : timeZoneID
            return w
        }
    }

    struct ZyklusDTO: Codable {
        var datum: Date; var typ: String; var notizen: String; var istPeriode: Bool; var blutungsfluss: String
        var nurHalberTag: Bool; var symptome: String; var ovulationstest: String; var zervixschleim: String
        var basaltemperatur: Double; var sexuelleAktivitaet: String; var timeZoneID: String

        init(_ z: ZyklusEintrag) {
            datum = z.datum; typ = z.typ; notizen = z.notizen; istPeriode = z.istPeriode
            blutungsfluss = z.blutungsfluss; nurHalberTag = z.nurHalberTag; symptome = z.symptome
            ovulationstest = z.ovulationstest; zervixschleim = z.zervixschleim
            basaltemperatur = z.basaltemperatur; sexuelleAktivitaet = z.sexuelleAktivitaet; timeZoneID = z.timeZoneID
        }

        func modell() -> ZyklusEintrag {
            let z = ZyklusEintrag(datum: datum)
            z.typ = typ; z.notizen = notizen; z.istPeriode = istPeriode; z.blutungsfluss = blutungsfluss
            z.nurHalberTag = nurHalberTag; z.symptome = symptome; z.ovulationstest = ovulationstest
            z.zervixschleim = zervixschleim; z.basaltemperatur = basaltemperatur
            z.sexuelleAktivitaet = sexuelleAktivitaet
            z.timeZoneID = timeZoneID.isEmpty ? TimeZone.current.identifier : timeZoneID
            return z
        }
    }
}
