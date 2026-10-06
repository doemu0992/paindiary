import Foundation

/// CSV-Export aller Module für Arzt/Excel.
///
/// Format-Entscheidungen:
/// - Zeitpunkte als ISO 8601 **mit Zeitzonen-Offset** (maschinenlesbar, eindeutig); zusätzlich `Tag` und `Zeitzone`.
/// - UTF-8 mit BOM (Excel erkennt Umlaute), Dezimalpunkt, `\n` als Zeilenende.
/// - Schutz vor Formel-Injection (Zellen, die mit `= + - @` beginnen, werden mit `'` entschärft).
/// - Leere Zelle = nicht erfasst (nie „0" für fehlende Werte).
enum CSVExportService {

    struct Quellen {
        var eintraege: [PainEntry] = []
        var medikamente: [Dauermedikation] = []
        var logs: [EinnahmeLog] = []
        var migraene: [MigraeneEintrag] = []
        var blutzucker: [BlutzuckerEintrag] = []
        var wellness: [WellnessEintrag] = []
        var zyklus: [ZyklusEintrag] = []
    }

    // MARK: - Öffentliche API

    /// Kompatible Kurzform (nur Schmerz + Medikation).
    static func erstelleExport(
        eintraege: [PainEntry],
        medikamente: [Dauermedikation],
        logs: [EinnahmeLog]
    ) throws -> [URL] {
        try erstelleVollExport(quellen: Quellen(eintraege: eintraege, medikamente: medikamente, logs: logs))
    }

    /// Exportiert alle nicht leeren Module. `von`/`bis` begrenzen zeitbezogene Einträge (bis exklusiv).
    static func erstelleVollExport(quellen: Quellen, von: Date? = nil, bis: Date? = nil) throws -> [URL] {
        raeumeAltExporteAuf()
        let stamp = tagText(DayKey.heute())
        func imZeitraum(_ d: Date) -> Bool { (von.map { d >= $0 } ?? true) && (bis.map { d < $0 } ?? true) }

        var dateien: [(name: String, inhalt: String)] = []
        let schmerz = quellen.eintraege.filter { imZeitraum($0.datum) }.sorted { $0.datum < $1.datum }
        if !schmerz.isEmpty { dateien.append(("schmerzeintraege_\(stamp).csv", schmerzCSV(schmerz))) }
        let migraene = quellen.migraene.filter { imZeitraum($0.datum) }.sorted { $0.datum < $1.datum }
        if !migraene.isEmpty { dateien.append(("migraene_\(stamp).csv", migraeneCSV(migraene))) }
        let bz = quellen.blutzucker.filter { imZeitraum($0.datum) }.sorted { $0.datum < $1.datum }
        if !bz.isEmpty { dateien.append(("blutzucker_\(stamp).csv", blutzuckerCSV(bz))) }
        let wellness = quellen.wellness.filter { imZeitraum($0.datum) }.sorted { $0.datum < $1.datum }
        if !wellness.isEmpty { dateien.append(("wellness_\(stamp).csv", wellnessCSV(wellness))) }
        let zyklus = quellen.zyklus.filter { imZeitraum($0.datum) }.sorted { $0.datum < $1.datum }
        if !zyklus.isEmpty { dateien.append(("zyklus_\(stamp).csv", zyklusCSV(zyklus))) }
        if !quellen.medikamente.isEmpty { dateien.append(("medikamente_\(stamp).csv", medikamenteCSV(quellen.medikamente))) }
        let logs = quellen.logs.filter { imZeitraum($0.datum) }.sorted { $0.datum < $1.datum }
        if !logs.isEmpty { dateien.append(("einnahmelogs_\(stamp).csv", einnahmelogsCSV(logs))) }

        // Immer mindestens eine Datei liefern (leerer Export = Kopfzeile des Schmerztagebuchs)
        if dateien.isEmpty { dateien.append(("schmerzeintraege_\(stamp).csv", schmerzCSV([]))) }

        let ordner = exportOrdner
        try FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        return try dateien.map { datei in
            let url = ordner.appendingPathComponent(datei.name)
            var daten = Data([0xEF, 0xBB, 0xBF])   // UTF-8-BOM
            daten.append(Data(datei.inhalt.utf8))
            try daten.write(to: url, options: [.atomic, .completeFileProtection])
            return url
        }
    }

    /// Exportdateien enthalten Gesundheitsdaten und werden nach dem Teilen nicht mehr gebraucht.
    static func raeumeAltExporteAuf() {
        try? FileManager.default.removeItem(at: exportOrdner)
    }

    static var exportOrdner: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("PainDiaryExport", isDirectory: true)
    }

    // MARK: - Schmerz

    static func schmerzCSV(_ eintraege: [PainEntry]) -> String {
        let kopf = ["Zeitpunkt", "Tag", "Zeitzone", "Typ", "Schmerzstärke", "Körperstelle", "Schmerzart",
                    "Dauer (min)", "Auslöser", "Begleiterscheinungen", "Massnahmen", "Notizen",
                    "Stimmung (1-5)", "Stress (1-5)", "Energie (1-5)", "Schlaf (h)", "Fatigue (0-10)",
                    "Morgensteifigkeit (min)", "Schub", "Gelenkstatus",
                    "Temperatur (°C)", "Wettercode", "Wind (km/h)", "Hautstellen", "Hautart", "Verlauf"]
        let zeilen = eintraege.map { e -> [String] in
            let art = e.eintragsArt
            return [
                iso(e.datum, e.zeitzone), tagText(e.tag), e.zeitzone.identifier, art.rawValue,
                art == .haut ? "" : "\(e.schmerzstaerke)",
                escape(e.koerperstelle), escape(e.schmerzart),
                zahl(e.dauerMinuten), escape(e.ausloeser), escape(e.begleiterscheinungen),
                escape(e.massnahmen), escape(e.notizen),
                zahl(e.stimmung), zahl(e.stressLevel), zahl(e.energielevel), dezimal(e.schlafStunden, stellen: 1),
                zahl(e.fatigue), zahl(e.morgensteifigkeit), e.istSchub ? "ja" : "",
                escape(e.gelenkStatus),
                e.wetterTemperatur.map { String(format: "%.1f", $0) } ?? "",
                e.wetterCode.map { "\($0)" } ?? "",
                e.wetterWind.map { String(format: "%.1f", $0) } ?? "",
                escape(e.hautStellen), escape(e.hautArt), escape(e.verlauf)
            ]
        }
        return tabelle(kopf, zeilen)
    }

    // MARK: - Migräne

    static func migraeneCSV(_ anfaelle: [MigraeneEintrag]) -> String {
        let kopf = ["Zeitpunkt", "Tag", "Zeitzone", "Ende", "Typ", "Stärke (1-10)", "Dauer (min)", "Seite", "Aura",
                    "Charakter", "Begleitsymptome", "Prodrom", "Postdrom", "Auslöser", "Akutmedikament",
                    "Wirksam", "Zyklusphase", "Stimmung (1-5)", "Stress (1-5)", "Energie (1-5)", "Schlaf (h)", "Notizen"]
        let zeilen = anfaelle.map { a -> [String] in
            [
                iso(a.datum, a.zeitzone), tagText(a.tag), a.zeitzone.identifier,
                a.endZeit.map { iso($0, a.zeitzone) } ?? "",
                escape(a.kopfschmerzTyp), zahl(a.staerke), zahl(a.dauer), escape(a.seite),
                a.hatAura ? "ja" : "nein",
                escape(a.charakter), escape(a.begleitsymptome), escape(a.prodromsymptome), escape(a.postdrom),
                escape(a.ausloeser), escape(a.akutmedikament), escape(a.medikamentWirksam), escape(a.zyklusPhase),
                zahl(a.stimmung), zahl(a.stressLevel), zahl(a.energielevel), dezimal(a.schlafStunden, stellen: 1),
                escape(a.notizen)
            ]
        }
        return tabelle(kopf, zeilen)
    }

    // MARK: - Blutzucker

    static func blutzuckerCSV(_ messungen: [BlutzuckerEintrag]) -> String {
        let kopf = ["Zeitpunkt", "Tag", "Zeitzone", "Blutzucker (mmol/L)", "Messzeitpunkt",
                    "Insulin (E)", "Insulintyp", "Kohlenhydrate (g)", "Notizen"]
        let zeilen = messungen.map { m -> [String] in
            [
                iso(m.datum, m.zeitzone), tagText(m.tag), m.zeitzone.identifier,
                dezimal(m.wert, stellen: 1), escape(m.messZeitpunkt),
                m.insulinEinheiten > 0 ? dezimal(m.insulinEinheiten, stellen: 1) : "",
                escape(m.insulinTyp), zahl(m.kohlenhydrate), escape(m.notizen)
            ]
        }
        return tabelle(kopf, zeilen)
    }

    // MARK: - Wellness

    static func wellnessCSV(_ eintraege: [WellnessEintrag]) -> String {
        let kopf = ["Tag", "Zeitzone", "Wasser (ml)", "Wasserziel (ml)", "Koffein (Tassen)", "Alkohol (Gläser)",
                    "Frühstück", "Mittag", "Abend", "Stimmung (1-5)", "Stress (1-5)", "Energie (1-5)", "Schlaf (h)", "Notizen"]
        let zeilen = eintraege.map { w -> [String] in
            [
                tagText(w.tag), w.zeitzone.identifier, "\(w.wasserMl)", "\(w.wasserZielMl)",
                "\(w.koffeinTassen)", "\(w.alkoholGlaeser)",
                w.fruehstueck ? "ja" : "nein", w.mittag ? "ja" : "nein", w.abend ? "ja" : "nein",
                zahl(w.stimmung), zahl(w.stressLevel), zahl(w.energielevel), dezimal(w.schlafStunden, stellen: 1),
                escape(w.notizen)
            ]
        }
        return tabelle(kopf, zeilen)
    }

    // MARK: - Zyklus

    static func zyklusCSV(_ eintraege: [ZyklusEintrag]) -> String {
        let kopf = ["Zeitpunkt", "Tag", "Zeitzone", "Periode", "Blutungsfluss", "Symptome", "Ovulationstest",
                    "Zervixschleim", "Basaltemperatur (°C)", "Notizen"]
        let zeilen = eintraege.map { z -> [String] in
            [
                iso(z.datum, z.zeitzone), tagText(z.tag), z.zeitzone.identifier,
                (z.istPeriode || z.typ == "Periode") ? "ja" : "", escape(z.blutungsfluss), escape(z.symptome),
                escape(z.ovulationstest), escape(z.zervixschleim),
                z.basaltemperatur > 0 ? dezimal(z.basaltemperatur, stellen: 2) : "", escape(z.notizen)
            ]
        }
        return tabelle(kopf, zeilen)
    }

    // MARK: - Medikamente

    static func medikamenteCSV(_ medikamente: [Dauermedikation]) -> String {
        let kopf = ["ID", "Name", "Typ", "Dosierung", "Frequenz", "Seit", "Aktiv", "Ende", "Hinweis",
                    "Vorrat", "Vorrat-Schwelle", "Ablaufdatum"]
        let zeilen = medikamente.map { m -> [String] in
            [
                escape(m.notifID), escape(m.name), escape(m.medikamentTyp), escape(m.dosierung), escape(m.frequenz),
                tagText(DayKey(m.startDatum)), m.aktiv ? "ja" : "nein",
                m.endDatum.map { tagText(DayKey($0)) } ?? "", escape(m.einnahmeHinweis),
                m.vorrat.map { "\($0)" } ?? "", "\(m.vorratSchwelle)",
                m.ablaufDatum.map { tagText(DayKey($0)) } ?? ""
            ]
        }
        return tabelle(kopf, zeilen)
    }

    static func einnahmelogsCSV(_ logs: [EinnahmeLog]) -> String {
        let kopf = ["Zeitpunkt", "Medikament", "Medikament-ID", "Dosierung", "Eingenommen", "Wirkung", "Notizen"]
        let zeilen = logs.map { l -> [String] in
            [
                iso(l.datum, .current), escape(l.medikamentName), escape(l.medikamentID), escape(l.dosierung),
                l.eingenommen ? "ja" : "nein", escape(l.wirkung), escape(l.notizen)
            ]
        }
        return tabelle(kopf, zeilen)
    }

    // MARK: - Bausteine

    nonisolated static func tabelle(_ kopf: [String], _ zeilen: [[String]]) -> String {
        ([kopf.map { escape($0) }] + zeilen).map { $0.joined(separator: ",") }.joined(separator: "\n")
    }

    /// RFC-4180-Quoting + Schutz vor Formel-Injection.
    nonisolated static func escape(_ s: String) -> String {
        var text = s
        if let erstes = text.unicodeScalars.first, ["=", "+", "-", "@", "\t", "\r"].contains(Character(erstes)) {
            text = "'" + text
        }
        guard text.contains(",") || text.contains("\"") || text.contains("\n") || text.contains("\r") else { return text }
        return "\"\(text.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    /// Kompatibilität mit bisherigem Namen.
    nonisolated static func csvEscape(_ s: String) -> String { escape(s) }

    /// ISO 8601 mit Offset in der angegebenen Zeitzone (z. B. 2026-10-05T14:30:00+02:00).
    static func iso(_ datum: Date, _ zone: TimeZone) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = zone
        return f.string(from: datum)
    }

    static func tagText(_ tag: DayKey) -> String {
        String(format: "%04d-%02d-%02d", tag.jahr, tag.monat, tag.tag)
    }

    /// Ganzzahl; 0 gilt als „nicht erfasst" → leere Zelle.
    private static func zahl(_ wert: Int) -> String { wert > 0 ? "\(wert)" : "" }

    private static func dezimal(_ wert: Double, stellen: Int) -> String {
        guard wert.isFinite, wert > 0 else { return "" }
        return String(format: "%.\(stellen)f", wert)
    }
}
