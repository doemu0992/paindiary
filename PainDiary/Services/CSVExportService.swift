import Foundation

enum CSVExportService {

    static func erstelleExport(
        eintraege: [PainEntry],
        medikamente: [Dauermedikation],
        logs: [EinnahmeLog]
    ) throws -> [URL] {
        let tmp = FileManager.default.temporaryDirectory
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        let stamp = formatter.string(from: Date())

        let files: [(name: String, inhalt: String)] = [
            ("schmerzeintraege_\(stamp).csv",  schmerzCSV(eintraege)),
            ("medikamente_\(stamp).csv",        medikamenteCSV(medikamente)),
            ("einnahmelogs_\(stamp).csv",        einnahmelogsCSV(logs))
        ]

        return try files.map { datei in
            let url = tmp.appendingPathComponent(datei.name)
            try datei.inhalt.write(to: url, atomically: true, encoding: .utf8)
            return url
        }
    }

    // MARK: - Schmerz-Einträge

    static func schmerzCSV(_ eintraege: [PainEntry]) -> String {
        let kopf = ["Datum", "Schmerzstärke", "Körperstelle", "Schmerzart",
                    "Dauer (min)", "Auslöser", "Begleiterscheinungen",
                    "Massnahmen", "Notizen", "Stimmung", "Schlaf (h)",
                    "Stress", "Temperatur (°C)", "Wettercode", "Wind (km/h)",
                    "Hauteintrag", "Hautstellen", "Hautart", "Verlauf"]

        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short

        let zeilen = eintraege.map { e -> String in
            [
                df.string(from: e.datum),
                e.istHautEintrag ? "" : "\(e.schmerzstaerke)",
                csvEscape(e.koerperstelle),
                csvEscape(e.schmerzart),
                e.dauerMinuten > 0 ? "\(e.dauerMinuten)" : "",
                csvEscape(e.ausloeser),
                csvEscape(e.begleiterscheinungen),
                csvEscape(e.massnahmen),
                csvEscape(e.notizen),
                "\(e.stimmung)",
                e.schlafStunden > 0 ? String(format: "%.1f", e.schlafStunden) : "",
                "\(e.stressLevel)",
                e.wetterTemperatur.map { String(format: "%.1f", $0) } ?? "",
                e.wetterCode.map { "\($0)" } ?? "",
                e.wetterWind.map { String(format: "%.1f", $0) } ?? "",
                e.istHautEintrag ? "ja" : "nein",
                csvEscape(e.hautStellen),
                csvEscape(e.hautArt),
                csvEscape(e.verlauf)
            ].joined(separator: ",")
        }

        return ([kopf.joined(separator: ",")] + zeilen).joined(separator: "\n")
    }

    // MARK: - Medikamente

    static func medikamenteCSV(_ medikamente: [Dauermedikation]) -> String {
        let kopf = ["Name", "Typ", "Dosierung", "Frequenz", "Seit",
                    "Aktiv", "Ende", "Hinweis", "Vorrat", "Vorrat-Schwelle", "Ablaufdatum"]

        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .none

        let zeilen = medikamente.map { m -> String in
            [
                csvEscape(m.name),
                csvEscape(m.medikamentTyp),
                csvEscape(m.dosierung),
                csvEscape(m.frequenz),
                df.string(from: m.startDatum),
                m.aktiv ? "ja" : "nein",
                m.endDatum.map { df.string(from: $0) } ?? "",
                csvEscape(m.einnahmeHinweis),
                m.vorrat.map { "\($0)" } ?? "",
                "\(m.vorratSchwelle)",
                m.ablaufDatum.map { df.string(from: $0) } ?? ""
            ].joined(separator: ",")
        }

        return ([kopf.joined(separator: ",")] + zeilen).joined(separator: "\n")
    }

    // MARK: - Einnahme-Logs

    static func einnahmelogsCSV(_ logs: [EinnahmeLog]) -> String {
        let kopf = ["Datum", "Medikament", "Dosierung", "Eingenommen", "Notizen", "Wirkung"]

        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short

        let zeilen = logs.map { l -> String in
            [
                df.string(from: l.datum),
                csvEscape(l.medikamentName),
                csvEscape(l.dosierung),
                l.eingenommen ? "ja" : "nein",
                csvEscape(l.notizen),
                csvEscape(l.wirkung)
            ].joined(separator: ",")
        }

        return ([kopf.joined(separator: ",")] + zeilen).joined(separator: "\n")
    }

    // MARK: - Hilfsmethoden

    static func csvEscape(_ s: String) -> String {
        guard s.contains(",") || s.contains("\"") || s.contains("\n") else { return s }
        return "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
