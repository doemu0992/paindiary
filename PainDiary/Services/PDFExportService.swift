import Foundation
#if os(iOS)
import UIKit

// MARK: - Plain data transfer objects (no SwiftData dependencies)

struct PDFPatientenDaten {
    var vorname: String = ""
    var nachname: String = ""
    var geburtsdatum: Date? = nil
    var versicherung: String = ""
    var versicherungsNummer: String = ""
    var blutgruppe: String = ""
    var diagnosen: [String] = []
    var allergien: [String] = []
    var aerzte: [PDFArzt] = []
    var notfallkontakte: [PDFNotfallKontakt] = []

    var vollerName: String { "\(vorname) \(nachname)".trimmingCharacters(in: .whitespaces) }

    static func aus(profil: Benutzerprofil?) -> PDFPatientenDaten {
        guard let p = profil else { return PDFPatientenDaten() }
        return PDFPatientenDaten(
            vorname: p.vorname,
            nachname: p.nachname,
            geburtsdatum: p.geburtsdatum,
            versicherung: p.versicherung,
            versicherungsNummer: p.versicherungsNummer,
            blutgruppe: p.blutgruppe,
            diagnosen: p.diagnosen.map { $0.bezeichnung }.filter { !$0.isEmpty },
            allergien: p.allergien.map { $0.substanz }.filter { !$0.isEmpty },
            aerzte: p.aerzte.map { PDFArzt(name: $0.name, fachgebiet: $0.fachgebiet, telefon: $0.telefon, istHausarzt: $0.istHausarzt) },
            notfallkontakte: p.notfallkontakte.map { PDFNotfallKontakt(name: $0.name, phone: $0.phone, beziehung: $0.beziehung) }
        )
    }
}

struct PDFArzt {
    var name: String; var fachgebiet: String; var telefon: String; var istHausarzt: Bool
}

struct PDFNotfallKontakt {
    var name: String; var phone: String; var beziehung: String
}

struct PDFMedikament {
    var name: String; var dosierung: String; var frequenz: String; var startDatum: Date; var aktiv: Bool

    static func aus(med: Dauermedikation) -> PDFMedikament {
        PDFMedikament(name: med.name, dosierung: med.dosierung, frequenz: med.frequenz,
                      startDatum: med.startDatum, aktiv: med.aktiv)
    }
}

struct PDFEintrag {
    var datum: Date; var schmerzstaerke: Int; var koerperstelle: String
    var schmerzart: String; var dauerMinuten: Int; var ausloeser: String
    var massnahmen: String; var notizen: String; var begleiterscheinungen: String

    static func aus(eintrag: PainEntry) -> PDFEintrag {
        PDFEintrag(datum: eintrag.datum, schmerzstaerke: eintrag.schmerzstaerke,
                   koerperstelle: eintrag.koerperstelle, schmerzart: eintrag.schmerzart,
                   dauerMinuten: eintrag.dauerMinuten, ausloeser: eintrag.ausloeser,
                   massnahmen: eintrag.massnahmen, notizen: eintrag.notizen,
                   begleiterscheinungen: eintrag.begleiterscheinungen)
    }
}

struct PDFMidas {
    var datum: Date; var score: Int; var gradText: String

    static func aus(m: MIDASBewertung) -> PDFMidas {
        PDFMidas(datum: m.datum, score: m.score, gradText: m.gradText)
    }
}

struct PDFZyklusEintrag {
    var datum: Date
    var istPeriode: Bool
    var blutungsfluss: String
    var symptome: [String]
    var ovulationstest: String
    var basaltemperatur: Double

    static func aus(e: ZyklusEintrag) -> PDFZyklusEintrag {
        PDFZyklusEintrag(
            datum: e.datum,
            istPeriode: e.istPeriode || e.typ == "Periode",
            blutungsfluss: e.blutungsfluss,
            symptome: e.symptome.components(separatedBy: ", ").filter { !$0.isEmpty },
            ovulationstest: e.ovulationstest,
            basaltemperatur: e.basaltemperatur
        )
    }
}

// MARK: - Export options

struct ExportOptionen {
    var zeitraum: ExportZeitraum = .dreissigTage
    var mitZusammenfassung: Bool = true
    var mitMedikamente: Bool = true
    var mitEintraege: Bool = true
    var mitZyklus: Bool = true
}

enum ExportZeitraum: String, CaseIterable {
    case dreissigTage = "30 Tage"
    case neunzigTage  = "90 Tage"
    case halbJahr     = "180 Tage"
    case alles        = "Alles"

    func startDatum() -> Date? {
        let cal = Calendar.current
        switch self {
        case .dreissigTage: return cal.date(byAdding: .day, value: -30, to: Date())
        case .neunzigTage:  return cal.date(byAdding: .day, value: -90, to: Date())
        case .halbJahr:     return cal.date(byAdding: .day, value: -180, to: Date())
        case .alles:        return nil
        }
    }
}

// MARK: - PDF service

class PDFExportService {
    static let shared = PDFExportService()

    private let W: CGFloat = 595
    private let H: CGFloat = 842
    private let rand: CGFloat = 48
    private var iw: CGFloat { W - rand * 2 }

    private let blau     = UIColor(red: 0.13, green: 0.40, blue: 0.78, alpha: 1)
    private let hellBlau = UIColor(red: 0.88, green: 0.93, blue: 0.99, alpha: 1)

    /// Call from main thread. All SwiftData objects are copied into plain structs here,
    /// then PDF rendering runs on a background queue.
    func erstellePDFAsync(
        eintraege: [PainEntry],
        medikamente: [Dauermedikation],
        midasBewertungen: [MIDASBewertung],
        zyklusEintraege: [ZyklusEintrag],
        profil: Benutzerprofil?,
        optionen: ExportOptionen,
        completion: @escaping (URL?) -> Void
    ) {
        // Copy all SwiftData objects into plain structs on main thread
        let patient  = PDFPatientenDaten.aus(profil: profil)
        let gefiltert: [PDFEintrag]
        if let start = optionen.zeitraum.startDatum() {
            gefiltert = eintraege.filter { $0.datum >= start }
                .sorted { $0.datum > $1.datum }
                .map(PDFEintrag.aus)
        } else {
            gefiltert = eintraege.sorted { $0.datum > $1.datum }.map(PDFEintrag.aus)
        }
        let meds     = medikamente.map(PDFMedikament.aus)
        let midas    = midasBewertungen.sorted { $0.datum > $1.datum }.map(PDFMidas.aus)
        let analyse  = ZyklusRechner.analyse(eintraege: zyklusEintraege)
        let zyklus   = zyklusEintraege.sorted { $0.datum > $1.datum }.map(PDFZyklusEintrag.aus)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { completion(nil); return }
            let url = self.renderPDF(patient: patient, eintraege: gefiltert,
                                     medikamente: meds, midas: midas,
                                     zyklus: zyklus, analyse: analyse, optionen: optionen)
            DispatchQueue.main.async { completion(url) }
        }
    }

    // MARK: - Render

    private func renderPDF(
        patient: PDFPatientenDaten,
        eintraege: [PDFEintrag],
        medikamente: [PDFMedikament],
        midas: [PDFMidas],
        zyklus: [PDFZyklusEintrag],
        analyse: ZyklusAnalyse,
        optionen: ExportOptionen
    ) -> URL? {
        let dateiname = "Schmerztagebuch_\(fmt(Date())).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(dateiname)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: W, height: H))

        do {
            try renderer.writePDF(to: url) { ctx in
                var seite = 1
                ctx.beginPage()
                deckblatt(ctx: ctx.cgContext, patient: patient, optionen: optionen, anzahl: eintraege.count)

                if optionen.mitZusammenfassung && !eintraege.isEmpty {
                    seite += 1; ctx.beginPage()
                    zusammenfassung(ctx: ctx.cgContext, eintraege: eintraege, midas: midas, seite: seite)
                }

                if optionen.mitMedikamente && !medikamente.isEmpty {
                    seite += 1; ctx.beginPage()
                    medikamenteSeite(ctx: ctx.cgContext, medikamente: medikamente, seite: seite)
                }

                if optionen.mitZyklus && !zyklus.isEmpty {
                    seite += 1; ctx.beginPage()
                    zyklusSeite(ctx: ctx.cgContext, eintraege: zyklus, analyse: analyse, seite: seite)
                }

                if optionen.mitEintraege && !eintraege.isEmpty {
                    seite += 1
                    eintraegeSeiten(ctx: ctx, eintraege: eintraege, startSeite: seite)
                }
            }
            return url
        } catch { return nil }
    }

    // MARK: - Page 1: Cover

    private func deckblatt(ctx: CGContext, patient: PDFPatientenDaten, optionen: ExportOptionen, anzahl: Int) {
        // Blue header
        ctx.setFillColor(blau.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: W, height: 180))
        draw("PainDiary", at: CGPoint(x: rand, y: 52),
             font: .systemFont(ofSize: 28, weight: .bold), color: .white)
        draw("Medizinischer Bericht", at: CGPoint(x: rand, y: 88),
             font: .systemFont(ofSize: 16), color: UIColor.white.withAlphaComponent(0.85))
        drawRight("Erstellt am \(fmtLang(Date()))", rightX: W - rand, y: 88,
                  font: .systemFont(ofSize: 11), color: UIColor.white.withAlphaComponent(0.75))

        var y: CGFloat = 210

        // Patient info box
        let infoRows: [(String, String)] = [
            patient.vollerName.isEmpty ? nil : ("Name", patient.vollerName),
            patient.geburtsdatum.map { ("Geburtsdatum", fmt($0)) },
            patient.versicherung.isEmpty ? nil : ("Krankenkasse", patient.versicherung),
            patient.versicherungsNummer.isEmpty ? nil : ("Vers.-Nr.", patient.versicherungsNummer),
            patient.blutgruppe == "Unbekannt" || patient.blutgruppe.isEmpty ? nil : ("Blutgruppe", patient.blutgruppe),
        ].compactMap { $0 }

        let boxH = max(70, CGFloat(infoRows.count) * 18 + 40)
        infoBox(ctx: ctx, x: rand, y: y, w: iw, h: boxH, titel: "Patienteninformationen", rows: infoRows)
        y += boxH + 12

        // Diagnoses
        if !patient.diagnosen.isEmpty {
            let dRows = patient.diagnosen.map { ("", $0) }
            infoBox(ctx: ctx, x: rand, y: y, w: iw * 0.55 - 6, h: CGFloat(dRows.count) * 18 + 40,
                    titel: "Diagnosen", rows: dRows, valueBold: false)
        }

        // Allergies
        if !patient.allergien.isEmpty {
            let aRows = patient.allergien.map { ("", $0) }
            infoBox(ctx: ctx, x: rand + iw * 0.55 + 6, y: y, w: iw * 0.45 - 6,
                    h: CGFloat(aRows.count) * 18 + 40, titel: "Allergien / Unverträglichkeiten",
                    rows: aRows, valueBold: false)
        }

        if !patient.diagnosen.isEmpty || !patient.allergien.isEmpty {
            y += max(CGFloat(patient.diagnosen.count), CGFloat(patient.allergien.count)) * 18 + 52
        }

        // Doctors
        if !patient.aerzte.isEmpty {
            let aRows: [(String, String)] = patient.aerzte.map {
                let label = $0.istHausarzt ? "Hausarzt" : $0.fachgebiet
                let value = $0.telefon.isEmpty ? $0.name : "\($0.name) · \($0.telefon)"
                return (label, value)
            }
            let bH = CGFloat(aRows.count) * 18 + 40
            infoBox(ctx: ctx, x: rand, y: y, w: iw * 0.55 - 6, h: bH, titel: "Behandelnde Ärzte", rows: aRows)
            if !patient.notfallkontakte.isEmpty {
                let nRows: [(String, String)] = patient.notfallkontakte.map {
                    ($0.beziehung, "\($0.name) · \($0.phone)")
                }
                infoBox(ctx: ctx, x: rand + iw * 0.55 + 6, y: y, w: iw * 0.45 - 6,
                        h: bH, titel: "Notfallkontakte", rows: nRows)
            }
            y += bH + 12
        } else if !patient.notfallkontakte.isEmpty {
            let nRows: [(String, String)] = patient.notfallkontakte.map {
                ($0.beziehung, "\($0.name) · \($0.phone)")
            }
            let bH = CGFloat(nRows.count) * 18 + 40
            infoBox(ctx: ctx, x: rand, y: y, w: iw, h: bH, titel: "Notfallkontakte", rows: nRows)
            y += bH + 12
        }

        // Timeframe box
        let tfH: CGFloat = 70
        roundedRect(ctx: ctx, rect: CGRect(x: rand, y: y, width: iw, height: tfH),
                    corner: 10, fill: UIColor(white: 0.97, alpha: 1), stroke: UIColor(white: 0.85, alpha: 1))
        draw("Berichtszeitraum: \(optionen.zeitraum.rawValue)",
             at: CGPoint(x: rand + 16, y: y + 12), font: .systemFont(ofSize: 12, weight: .semibold), color: .label)
        draw("\(anzahl) Einträge im gewählten Zeitraum",
             at: CGPoint(x: rand + 16, y: y + 34), font: .systemFont(ofSize: 11), color: .secondaryLabel)

        fusszeile(ctx: ctx, seite: 1)
    }

    // MARK: - Page 2: Summary

    private func zusammenfassung(ctx: CGContext, eintraege: [PDFEintrag], midas: [PDFMidas], seite: Int) {
        seitenKopf(ctx: ctx, titel: "Zusammenfassung", seite: 2)
        var y: CGFloat = rand + 52

        let avg = eintraege.map { Double($0.schmerzstaerke) }.reduce(0, +) / Double(eintraege.count)
        let maxVal = eintraege.map(\.schmerzstaerke).max() ?? 0
        let tage = Set(eintraege.map { Calendar.current.startOfDay(for: $0.datum) }).count
        let letzterMidas = midas.first

        let boxW = (iw - 12) / 4
        statBox(ctx: ctx, x: rand,                       y: y, w: boxW, h: 72, titel: "Ø Schmerzstärke",
                wert: String(format: "%.1f/10", avg), farbe: .systemOrange)
        statBox(ctx: ctx, x: rand + boxW + 4,             y: y, w: boxW, h: 72, titel: "Höchstwert",
                wert: "\(maxVal)/10", farbe: .systemRed)
        statBox(ctx: ctx, x: rand + (boxW + 4) * 2,       y: y, w: boxW, h: 72, titel: "Tage mit Schmerz",
                wert: "\(tage)", farbe: .systemBlue)
        statBox(ctx: ctx, x: rand + (boxW + 4) * 3,       y: y, w: boxW, h: 72, titel: "MIDAS Score",
                wert: letzterMidas.map { "\($0.score)" } ?? "–", farbe: .systemPurple)
        y += 88

        if let m = letzterMidas {
            draw("MIDAS: \(m.gradText)  (Bewertung vom \(fmt(m.datum)))",
                 at: CGPoint(x: rand, y: y), font: .systemFont(ofSize: 11), color: .secondaryLabel)
            y += 22
        }

        trennlinie(ctx: ctx, y: y); y += 14
        draw("Schmerzverteilung", at: CGPoint(x: rand, y: y),
             font: .systemFont(ofSize: 13, weight: .semibold), color: .label)
        y += 20

        let buckets = schmerzBuckets(eintraege: eintraege)
        let maxCount = max(1, buckets.values.max() ?? 1)
        let barH: CGFloat = 16
        let labelW: CGFloat = 44
        let barMaxW = iw - labelW - 44

        for level in stride(from: 10, through: 1, by: -1) {
            let count = buckets[level] ?? 0
            let barW = count > 0 ? max(4, CGFloat(count) / CGFloat(maxCount) * barMaxW) : 0
            draw("\(level)/10", at: CGPoint(x: rand, y: y + 2),
                 font: .systemFont(ofSize: 9), color: .secondaryLabel)
            if barW > 0 {
                ctx.setFillColor(schmerzFarbe(level).withAlphaComponent(0.75).cgColor)
                ctx.fill(CGRect(x: rand + labelW, y: y + 1, width: barW, height: barH - 3))
            }
            draw("\(count)", at: CGPoint(x: rand + labelW + barW + 4, y: y + 2),
                 font: .systemFont(ofSize: 9), color: .secondaryLabel)
            y += barH
        }
        y += 10

        trennlinie(ctx: ctx, y: y); y += 14
        draw("Häufige Auslöser", at: CGPoint(x: rand, y: y),
             font: .systemFont(ofSize: 13, weight: .semibold), color: .label)
        y += 20

        for (i, (name, count)) in ausloeserHaeufigkeit(eintraege: eintraege).prefix(5).enumerated() {
            draw("\(i+1). \(name)", at: CGPoint(x: rand, y: y),
                 font: .systemFont(ofSize: 11), color: .label)
            drawRight("\(count)×", rightX: W - rand, y: y,
                      font: .systemFont(ofSize: 11), color: .secondaryLabel)
            y += 18
        }

        y += 8
        trennlinie(ctx: ctx, y: y); y += 14
        draw("Häufigste Schmerzregionen", at: CGPoint(x: rand, y: y),
             font: .systemFont(ofSize: 13, weight: .semibold), color: .label)
        y += 20

        for (i, (name, count)) in regionenHaeufigkeit(eintraege: eintraege).prefix(5).enumerated() {
            draw("\(i+1). \(name)", at: CGPoint(x: rand, y: y),
                 font: .systemFont(ofSize: 11), color: .label)
            drawRight("\(count)×", rightX: W - rand, y: y,
                      font: .systemFont(ofSize: 11), color: .secondaryLabel)
            y += 18
        }

        fusszeile(ctx: ctx, seite: seite)
    }

    // MARK: - Page 3: Medications

    private func medikamenteSeite(ctx: CGContext, medikamente: [PDFMedikament], seite: Int) {
        seitenKopf(ctx: ctx, titel: "Medikamente", seite: 3)
        var y: CGFloat = rand + 52

        let aktive  = medikamente.filter { $0.aktiv }
        let inaktive = medikamente.filter { !$0.aktiv }

        if !aktive.isEmpty {
            draw("Aktuelle Medikation", at: CGPoint(x: rand, y: y),
                 font: .systemFont(ofSize: 13, weight: .semibold), color: .label)
            y += 20

            let cols: [CGFloat] = [rand, rand + 180, rand + 300, rand + 400]
            tabellenKopf(ctx: ctx, y: y, cols: cols, headers: ["Medikament", "Dosierung", "Frequenz", "Seit"])
            y += 26

            for med in aktive {
                if y > H - rand - 30 { break }
                tabellenZeile(ctx: ctx, y: y, cols: cols,
                              werte: [med.name, med.dosierung, med.frequenz, fmt(med.startDatum)],
                              fett: [true, false, false, false])
                y += 20
                trennlinie(ctx: ctx, y: y - 1, alpha: 0.12)
            }
            y += 16
        }

        if !inaktive.isEmpty {
            trennlinie(ctx: ctx, y: y); y += 16
            draw("Frühere Medikation", at: CGPoint(x: rand, y: y),
                 font: .systemFont(ofSize: 13, weight: .semibold), color: .secondaryLabel)
            y += 20

            for med in inaktive {
                if y > H - rand - 20 { break }
                draw("• \(med.name)", at: CGPoint(x: rand + 8, y: y),
                     font: .systemFont(ofSize: 11), color: .secondaryLabel)
                if !med.dosierung.isEmpty {
                    draw(med.dosierung, at: CGPoint(x: rand + 200, y: y),
                         font: .systemFont(ofSize: 11), color: .secondaryLabel)
                }
                y += 18
            }
        }

        fusszeile(ctx: ctx, seite: seite)
    }

    // MARK: - Zyklus page

    private func zyklusSeite(ctx: CGContext, eintraege: [PDFZyklusEintrag], analyse: ZyklusAnalyse, seite: Int) {
        seitenKopf(ctx: ctx, titel: "Zyklusübersicht", seite: seite)
        var y: CGFloat = rand + 52

        // Stat boxes
        let boxW = (iw - 8) / 4
        statBox(ctx: ctx, x: rand,                 y: y, w: boxW, h: 72,
                titel: "Ø Zykluslänge",   wert: String(format: "%.0f Tage", analyse.zykluslaenge),   farbe: .systemPink)
        statBox(ctx: ctx, x: rand + boxW + 3,       y: y, w: boxW, h: 72,
                titel: "Ø Periodendauer", wert: String(format: "%.0f Tage", analyse.periodendauer),  farbe: .systemRed)
        statBox(ctx: ctx, x: rand + (boxW + 3) * 2, y: y, w: boxW, h: 72,
                titel: "Variation",       wert: String(format: "±%.1f Tage", analyse.variation),     farbe: .systemOrange)
        statBox(ctx: ctx, x: rand + (boxW + 3) * 3, y: y, w: boxW, h: 72,
                titel: "Zyklen erfasst",  wert: "\(analyse.zyklusStarts.count)",                     farbe: .systemPurple)
        y += 88

        // Predictions box
        let predRows: [(String, String)] = [
            analyse.naechstePeriodeStart.map { ("Nächste Periode (erwartet)", fmt($0)) },
            analyse.vorhergesagteOvulation.map { ("Nächster Eisprung (erwartet)", fmt($0)) },
            analyse.vorhergesagteOvulation.flatMap { ov -> (String, String)? in
                let kal = Calendar.current
                guard let start = kal.date(byAdding: .day, value: -5, to: ov),
                      let end   = kal.date(byAdding: .day, value: 1, to: ov) else { return nil }
                return ("Fruchtbares Fenster", "\(fmt(start)) – \(fmt(end))")
            }
        ].compactMap { $0 }

        if !predRows.isEmpty {
            let ph = CGFloat(predRows.count) * 18 + 40
            infoBox(ctx: ctx, x: rand, y: y, w: iw, h: ph, titel: "Aktuelle Vorhersagen", rows: predRows)
            y += ph + 14
        }

        // Cycle starts table
        trennlinie(ctx: ctx, y: y); y += 14
        draw("Zyklushistorie", at: CGPoint(x: rand, y: y),
             font: .systemFont(ofSize: 13, weight: .semibold), color: .label)
        y += 20

        let cols: [CGFloat] = [rand, rand + 140, rand + 240, rand + 340]
        tabellenKopf(ctx: ctx, y: y, cols: cols, headers: ["Zyklusbeginn", "Länge", "Periodendauer", "Eis. Vorhersage"])
        y += 26

        let kal = Calendar.current
        for (i, start) in analyse.zyklusStarts.reversed().enumerated() {
            if y > H - rand - 30 { break }
            let laenge: String
            if i < analyse.zyklusStarts.count - 1 {
                let next = analyse.zyklusStarts.reversed()[i + 1]
                let d = kal.dateComponents([.day], from: start, to: next).day ?? 0
                laenge = "\(d) Tage"
            } else {
                laenge = "laufend"
            }
            let periodDauer: Int = {
                var n = 0; var check = start
                while eintraege.contains(where: { $0.istPeriode && kal.isDate($0.datum, inSameDayAs: check) }) {
                    n += 1
                    check = kal.date(byAdding: .day, value: 1, to: check) ?? check
                }
                return n
            }()
            let eisprung = kal.date(byAdding: .day, value: Int(analyse.zykluslaenge) - 14, to: start)
            tabellenZeile(ctx: ctx, y: y, cols: cols,
                          werte: [fmt(start), laenge,
                                  periodDauer > 0 ? "\(periodDauer) Tage" : "–",
                                  eisprung.map { fmt($0) } ?? "–"],
                          fett: [true, false, false, false])
            y += 20
            trennlinie(ctx: ctx, y: y - 1, alpha: 0.1)
        }
        y += 10

        // Symptom frequency
        trennlinie(ctx: ctx, y: y); y += 14
        draw("Häufige Symptome", at: CGPoint(x: rand, y: y),
             font: .systemFont(ofSize: 13, weight: .semibold), color: .label)
        y += 20

        let symptomMap = eintraege.flatMap(\.symptome)
            .reduce(into: [:]) { $0[$1, default: 0] += 1 }
        let sortiert = symptomMap.sorted { $0.value > $1.value }
        let maxS = max(1, sortiert.first?.value ?? 1)

        for (symptom, count) in sortiert.prefix(8) {
            if y > H - rand - 30 { break }
            let barW = CGFloat(count) / CGFloat(maxS) * (iw - 140)
            draw(symptom, at: CGPoint(x: rand, y: y + 2),
                 font: .systemFont(ofSize: 10), color: .label)
            ctx.setFillColor(UIColor.systemPink.withAlphaComponent(0.5).cgColor)
            ctx.fill(CGRect(x: rand + 130, y: y + 2, width: barW, height: 12))
            draw("\(count)×", at: CGPoint(x: rand + 130 + barW + 4, y: y + 2),
                 font: .systemFont(ofSize: 9), color: .secondaryLabel)
            y += 18
        }

        fusszeile(ctx: ctx, seite: seite)
    }

    // MARK: - Entries pages

    private func eintraegeSeiten(ctx: UIGraphicsPDFRendererContext, eintraege: [PDFEintrag], startSeite: Int) {
        var seite = startSeite
        ctx.beginPage()
        seitenKopf(ctx: ctx.cgContext, titel: "Schmerzeinträge", seite: seite)
        var y: CGFloat = rand + 52

        let cols: [CGFloat] = [rand, rand + 72, rand + 162, rand + 262, rand + 322, rand + 378]
        tabellenKopf(ctx: ctx.cgContext, y: y, cols: cols,
                     headers: ["Datum", "Stärke", "Körperstelle", "Auslöser", "Dauer", "Art"])
        y += 26

        for eintrag in eintraege {
            let hatSubzeile = !eintrag.massnahmen.isEmpty || !eintrag.notizen.isEmpty
            let zeilenH: CGFloat = hatSubzeile ? 32 : 20

            if y + zeilenH > H - rand - 20 {
                fusszeile(ctx: ctx.cgContext, seite: seite)
                ctx.beginPage(); seite += 1
                seitenKopf(ctx: ctx.cgContext, titel: "Schmerzeinträge (Forts.)", seite: seite)
                y = rand + 52
                tabellenKopf(ctx: ctx.cgContext, y: y, cols: cols,
                             headers: ["Datum", "Stärke", "Körperstelle", "Auslöser", "Dauer", "Art"])
                y += 26
            }

            let dauer = eintrag.dauerMinuten > 0 ? dauerText(eintrag.dauerMinuten) : "–"
            let koerper = eintrag.koerperstelle.components(separatedBy: ", ").first ?? eintrag.koerperstelle
            tabellenZeile(ctx: ctx.cgContext, y: y, cols: cols,
                          werte: [fmtKurz(eintrag.datum), "\(eintrag.schmerzstaerke)/10",
                                  koerper, String(eintrag.ausloeser.prefix(22)),
                                  dauer, String(eintrag.schmerzart.prefix(16))],
                          fett: [false, true, false, false, false, false])

            if hatSubzeile {
                y += 14
                let sub = [
                    eintrag.massnahmen.isEmpty ? nil : "Massnahmen: \(String(eintrag.massnahmen.prefix(50)))",
                    eintrag.notizen.isEmpty    ? nil : "Notiz: \(String(eintrag.notizen.prefix(60)))"
                ].compactMap { $0 }.joined(separator: "   ")
                draw(sub, at: CGPoint(x: cols[2], y: y),
                     font: .systemFont(ofSize: 8.5), color: .secondaryLabel)
                y += 18
            } else {
                y += 20
            }
            trennlinie(ctx: ctx.cgContext, y: y - 1, alpha: 0.1)
        }

        fusszeile(ctx: ctx.cgContext, seite: seite)
    }

    // MARK: - Drawing helpers

    private func infoBox(ctx: CGContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat,
                         titel: String, rows: [(String, String)], valueBold: Bool = true) {
        roundedRect(ctx: ctx, rect: CGRect(x: x, y: y, width: w, height: h),
                    corner: 10, fill: hellBlau, stroke: blau.withAlphaComponent(0.25))
        draw(titel, at: CGPoint(x: x + 12, y: y + 10),
             font: .systemFont(ofSize: 10, weight: .semibold), color: blau)
        var ry = y + 28
        let lf = UIFont.systemFont(ofSize: 9.5, weight: .medium)
        let vf = UIFont.systemFont(ofSize: 9.5, weight: valueBold ? .medium : .regular)
        for (label, value) in rows {
            if !label.isEmpty {
                draw(label, at: CGPoint(x: x + 12, y: ry), font: lf, color: .secondaryLabel)
                draw(value, at: CGPoint(x: x + 90, y: ry), font: vf, color: .label)
            } else {
                draw("•  \(value)", at: CGPoint(x: x + 12, y: ry), font: vf, color: .label)
            }
            ry += 18
        }
    }

    private func seitenKopf(ctx: CGContext, titel: String, seite: Int) {
        ctx.setFillColor(blau.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: W, height: 40))
        draw("PainDiary  ·  ", at: CGPoint(x: rand, y: 11),
             font: .systemFont(ofSize: 11, weight: .regular), color: UIColor.white.withAlphaComponent(0.65))
        draw(titel, at: CGPoint(x: rand + 80, y: 11),
             font: .systemFont(ofSize: 12, weight: .bold), color: .white)
    }

    private func fusszeile(ctx: CGContext, seite: Int) {
        trennlinie(ctx: ctx, y: H - 30, alpha: 0.2)
        draw("PainDiary – Vertraulicher Patientenbericht",
             at: CGPoint(x: rand, y: H - 24), font: .systemFont(ofSize: 8), color: .tertiaryLabel)
        drawRight("Seite \(seite)", rightX: W - rand, y: H - 24,
                  font: .systemFont(ofSize: 8), color: .tertiaryLabel)
    }

    private func tabellenKopf(ctx: CGContext, y: CGFloat, cols: [CGFloat], headers: [String]) {
        ctx.setFillColor(hellBlau.cgColor)
        ctx.fill(CGRect(x: rand, y: y, width: iw, height: 20))
        for (i, h) in headers.enumerated() {
            draw(h, at: CGPoint(x: cols[i] + 4, y: y + 5),
                 font: .systemFont(ofSize: 9, weight: .semibold), color: blau)
        }
    }

    private func tabellenZeile(ctx: CGContext, y: CGFloat, cols: [CGFloat],
                                werte: [String], fett: [Bool]) {
        for (i, w) in werte.enumerated() {
            let x = cols[i]
            let maxW = i + 1 < cols.count ? cols[i+1] - x - 6 : W - rand - x - 4
            let font: UIFont = (i < fett.count && fett[i]) ? .systemFont(ofSize: 10, weight: .semibold)
                                                            : .systemFont(ofSize: 10)
            drawClamped(w, at: CGPoint(x: x + 4, y: y + 4), font: font, color: .label, maxW: maxW)
        }
    }

    private func statBox(ctx: CGContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat,
                         titel: String, wert: String, farbe: UIColor) {
        roundedRect(ctx: ctx, rect: CGRect(x: x, y: y, width: w, height: h),
                    corner: 8, fill: farbe.withAlphaComponent(0.1), stroke: farbe.withAlphaComponent(0.3))
        draw(wert, at: CGPoint(x: x + 8, y: y + 8),
             font: .systemFont(ofSize: 18, weight: .bold), color: farbe)
        draw(titel, at: CGPoint(x: x + 8, y: y + 34),
             font: .systemFont(ofSize: 8), color: .secondaryLabel)
    }

    private func roundedRect(ctx: CGContext, rect: CGRect, corner: CGFloat,
                              fill: UIColor, stroke: UIColor) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: corner)
        ctx.saveGState()
        ctx.addPath(path.cgPath); ctx.setFillColor(fill.cgColor); ctx.fillPath()
        ctx.addPath(path.cgPath); ctx.setStrokeColor(stroke.cgColor)
        ctx.setLineWidth(0.5); ctx.strokePath()
        ctx.restoreGState()
    }

    private func trennlinie(ctx: CGContext, y: CGFloat, alpha: CGFloat = 0.3) {
        ctx.setStrokeColor(UIColor.separator.withAlphaComponent(alpha).cgColor)
        ctx.setLineWidth(0.5)
        ctx.move(to: CGPoint(x: rand, y: y))
        ctx.addLine(to: CGPoint(x: W - rand, y: y))
        ctx.strokePath()
    }

    private func draw(_ text: String, at point: CGPoint, font: UIFont, color: UIColor) {
        (text as NSString).draw(at: point, withAttributes: [.font: font, .foregroundColor: color])
    }

    private func drawRight(_ text: String, rightX: CGFloat, y: CGFloat, font: UIFont, color: UIColor) {
        let attr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let sz = (text as NSString).size(withAttributes: attr)
        (text as NSString).draw(at: CGPoint(x: rightX - sz.width, y: y), withAttributes: attr)
    }

    private func drawClamped(_ text: String, at p: CGPoint, font: UIFont, color: UIColor, maxW: CGFloat) {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        (text as NSString).draw(in: CGRect(x: p.x, y: p.y, width: maxW, height: 14),
                                withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: style])
    }

    // MARK: - Data helpers

    private func schmerzBuckets(eintraege: [PDFEintrag]) -> [Int: Int] {
        eintraege.reduce(into: [:]) { $0[$1.schmerzstaerke, default: 0] += 1 }
    }

    private func ausloeserHaeufigkeit(eintraege: [PDFEintrag]) -> [(String, Int)] {
        var map: [String: Int] = [:]
        for e in eintraege where !e.ausloeser.isEmpty {
            e.ausloeser.components(separatedBy: ", ")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .forEach { map[$0, default: 0] += 1 }
        }
        return map.sorted { $0.value > $1.value }
    }

    private func regionenHaeufigkeit(eintraege: [PDFEintrag]) -> [(String, Int)] {
        var map: [String: Int] = [:]
        for e in eintraege where !e.koerperstelle.isEmpty {
            e.koerperstelle.components(separatedBy: ", ")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .forEach { map[$0, default: 0] += 1 }
        }
        return map.sorted { $0.value > $1.value }
    }

    private func schmerzFarbe(_ level: Int) -> UIColor {
        switch level {
        case 1...3: return .systemGreen
        case 4...5: return .systemYellow
        case 6...7: return .systemOrange
        case 8...9: return .systemRed
        default:    return UIColor(red: 0.6, green: 0, blue: 0, alpha: 1)
        }
    }

    private func dauerText(_ min: Int) -> String {
        min < 60 ? "\(min) min" : "\(min/60)h\(min%60 == 0 ? "" : " \(min%60)m")"
    }

    private func fmt(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "dd.MM.yyyy"; return f.string(from: d)
    }
    private func fmtKurz(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "dd.MM.yy"; return f.string(from: d)
    }
    private func fmtLang(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "de_CH")
        f.dateStyle = .long; return f.string(from: d)
    }
}
#endif
