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
    var geschlecht: String = ""
    var wohnort: String = ""
    var gewichtKg: Double? = nil
    var groesseCm: Double? = nil
    var bmiText: String {
        guard let kg = gewichtKg, let cm = groesseCm, cm > 0, kg > 0 else { return "" }
        let bmi = kg / ((cm / 100) * (cm / 100))
        let kat: String
        switch bmi {
        case ..<18.5: kat = "Untergewicht"
        case 18.5..<25: kat = "Normalgewicht"
        case 25..<30: kat = "Übergewicht"
        default: kat = "Adipositas"
        }
        return String(format: "%.1f (%@)", bmi, kat)
    }

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
            diagnosen: (p.diagnosen ?? []).map { $0.bezeichnung }.filter { !$0.isEmpty },
            allergien: (p.allergien ?? []).map { $0.substanz }.filter { !$0.isEmpty },
            aerzte: (p.aerzte ?? []).map { PDFArzt(name: $0.name, fachgebiet: $0.fachgebiet, telefon: $0.telefon, istHausarzt: $0.istHausarzt) },
            notfallkontakte: (p.notfallkontakte ?? []).map { PDFNotfallKontakt(name: $0.name, phone: $0.phone, beziehung: $0.beziehung) },
            geschlecht: p.geschlecht,
            wohnort: p.wohnort,
            gewichtKg: p.gewichtKg,
            groesseCm: p.groesseCm
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
    var name: String; var dosierung: String; var frequenz: String
    var startDatum: Date; var endDatum: Date?; var aktiv: Bool
    var einnahmeHinweis: String; var medikamentTyp: String
    var vorrat: Int?; var vorratSchwelle: Int
    var ablaufDatum: Date?

    static func aus(med: Dauermedikation) -> PDFMedikament {
        PDFMedikament(name: med.name, dosierung: med.dosierung, frequenz: med.frequenz,
                      startDatum: med.startDatum, endDatum: med.endDatum, aktiv: med.aktiv,
                      einnahmeHinweis: med.einnahmeHinweis, medikamentTyp: med.medikamentTyp,
                      vorrat: med.vorrat, vorratSchwelle: med.vorratSchwelle,
                      ablaufDatum: med.ablaufDatum)
    }
}

struct PDFEinnahmeLog {
    var datum: Date; var medikamentName: String; var dosierung: String
    var eingenommen: Bool; var wirkung: String; var notizen: String

    static func aus(log: EinnahmeLog) -> PDFEinnahmeLog {
        PDFEinnahmeLog(datum: log.datum, medikamentName: log.medikamentName,
                       dosierung: log.dosierung, eingenommen: log.eingenommen,
                       wirkung: log.wirkung, notizen: log.notizen)
    }
}

struct PDFEintrag {
    var datum: Date; var schmerzstaerke: Int; var koerperstelle: String
    var schmerzart: String; var dauerMinuten: Int; var ausloeser: String
    var massnahmen: String; var notizen: String; var begleiterscheinungen: String
    var stimmung: Int; var stressLevel: Int; var schlafStunden: Double
    var morgensteifigkeit: Int
    var istHautEintrag: Bool; var hautStellen: String; var hautArt: String; var verlauf: String
    var wetterTemperatur: Double?; var wetterCode: Int?; var wetterWind: Double?
    var istSchub: Bool = false
    var fatigue: Int = 0
    var gelenkStatus: String = ""

    static func aus(eintrag: PainEntry) -> PDFEintrag {
        PDFEintrag(datum: eintrag.datum, schmerzstaerke: eintrag.schmerzstaerke,
                   koerperstelle: eintrag.koerperstelle, schmerzart: eintrag.schmerzart,
                   dauerMinuten: eintrag.dauerMinuten, ausloeser: eintrag.ausloeser,
                   massnahmen: eintrag.massnahmen, notizen: eintrag.notizen,
                   begleiterscheinungen: eintrag.begleiterscheinungen,
                   stimmung: eintrag.stimmung, stressLevel: eintrag.stressLevel,
                   schlafStunden: eintrag.schlafStunden,
                   morgensteifigkeit: eintrag.morgensteifigkeit,
                   istHautEintrag: eintrag.istHautEintrag,
                   hautStellen: eintrag.hautStellen, hautArt: eintrag.hautArt,
                   verlauf: eintrag.verlauf,
                   wetterTemperatur: eintrag.wetterTemperatur,
                   wetterCode: eintrag.wetterCode, wetterWind: eintrag.wetterWind,
                   istSchub: eintrag.istSchub,
                   fatigue: eintrag.fatigue,
                   gelenkStatus: eintrag.gelenkStatus)
    }
}

struct PDFMidas {
    var datum: Date; var score: Int; var gradText: String
    var tageArbeitEingeschraenkt: Int; var tageArbeitGefehlt: Int
    var tageHaushaltEingeschraenkt: Int; var tageHaushaltGefehlt: Int
    var tageFreizeit: Int; var notizen: String

    static func aus(m: MIDASBewertung) -> PDFMidas {
        PDFMidas(datum: m.datum, score: m.score, gradText: m.gradText,
                 tageArbeitEingeschraenkt: m.tageArbeitEingeschraenkt,
                 tageArbeitGefehlt: m.tageArbeitGefehlt,
                 tageHaushaltEingeschraenkt: m.tageHaushaltEingeschraenkt,
                 tageHaushaltGefehlt: m.tageHaushaltGefehlt,
                 tageFreizeit: m.tageFreizeit,
                 notizen: m.notizen)
    }
}

struct PDFZyklusEintrag {
    var datum: Date
    var istPeriode: Bool
    var blutungsfluss: String
    var symptome: [String]
    var ovulationstest: String
    var basaltemperatur: Double
    var zervixschleim: String
    var notizen: String
    var sexuelleAktivitaet: String

    static func aus(e: ZyklusEintrag) -> PDFZyklusEintrag {
        PDFZyklusEintrag(
            datum: e.datum,
            istPeriode: e.istPeriode || e.typ == "Periode",
            blutungsfluss: e.blutungsfluss,
            symptome: e.symptome.components(separatedBy: ", ").filter { !$0.isEmpty },
            ovulationstest: e.ovulationstest,
            basaltemperatur: e.basaltemperatur,
            zervixschleim: e.zervixschleim,
            notizen: e.notizen,
            sexuelleAktivitaet: e.sexuelleAktivitaet
        )
    }
}

struct PDFHAQEintrag {
    var datum: Date
    var haqScore: Double
    var haqGradText: String
    var globalBewertung: Int
    var notizen: String

    static func aus(eintrag: HAQEintrag) -> PDFHAQEintrag {
        PDFHAQEintrag(datum: eintrag.datum, haqScore: eintrag.haqScore,
                      haqGradText: eintrag.haqGradText, globalBewertung: eintrag.globalBewertung,
                      notizen: eintrag.notizen)
    }
}

struct PDFLaborwert {
    var datum: Date
    var typ: String
    var wert: Double
    var einheit: String
    var referenzMin: Double?
    var referenzMax: Double?

    var istErhoeht: Bool? {
        guard let max = referenzMax else { return nil }
        return wert > max
    }
    var istErniedrigt: Bool? {
        guard let min = referenzMin else { return nil }
        return wert < min
    }

    static func aus(lw: Laborwert) -> PDFLaborwert {
        PDFLaborwert(datum: lw.datum, typ: lw.typ, wert: lw.wert, einheit: lw.einheit,
                     referenzMin: lw.referenzMin, referenzMax: lw.referenzMax)
    }
}

struct PDFNotfallAllergie {
    var substanz: String
    var reaktion: String
    var schwere: String
}

struct PDFErnaehrungsTag {
    let datum: Date
    let koffeinTassen: Int
    let alkoholGlaeser: Int
    let wasserMl: Int
    let hatFruehstueck: Bool
    let hatMittag: Bool
    let hatAbend: Bool

    static func lesen(start: Date?) -> [PDFErnaehrungsTag] {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let ud = UserDefaults.standard
        let kal = Calendar.current
        let ende = kal.startOfDay(for: Date())
        var von = start.map { kal.startOfDay(for: $0) } ?? kal.date(byAdding: .year, value: -1, to: ende)!
        var ergebnis: [PDFErnaehrungsTag] = []
        while von <= ende {
            let k = df.string(from: von)
            let koffein = ud.integer(forKey: "koffeinTassen_\(k)")
            let alkohol = ud.integer(forKey: "alkoholGlaeser_\(k)")
            let wasser  = ud.integer(forKey: "wasserMl_\(k)")
            let frueh   = ud.bool(forKey: "mahlzeitFruehstueck_\(k)")
            let mittag  = ud.bool(forKey: "mahlzeitMittag_\(k)")
            let abend   = ud.bool(forKey: "mahlzeitAbend_\(k)")
            if koffein > 0 || alkohol > 0 || wasser > 0 || frueh || mittag || abend {
                ergebnis.append(PDFErnaehrungsTag(datum: von, koffeinTassen: koffein,
                    alkoholGlaeser: alkohol, wasserMl: wasser,
                    hatFruehstueck: frueh, hatMittag: mittag, hatAbend: abend))
            }
            von = kal.date(byAdding: .day, value: 1, to: von)!
        }
        return ergebnis
    }
}

// MARK: - Export options

struct ExportOptionen {
    var zeitraum: ExportZeitraum = .dreissigTage
    var mitZusammenfassung: Bool = true
    var mitMedikamente: Bool = true
    var mitMedikamentDossier: Bool = true
    var mitEintraege: Bool = true
    var mitZyklus: Bool = true
    var mitErnaehrung: Bool = true
    var mitRheuma: Bool = true
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

class PDFExportService: @unchecked Sendable {
    static let shared = PDFExportService()

    private let W: CGFloat = 595
    private let H: CGFloat = 842
    private let rand: CGFloat = 48
    private var iw: CGFloat { W - rand * 2 }

    private let blau     = UIColor(red: 0.13, green: 0.40, blue: 0.78, alpha: 1)
    private let hellBlau = UIColor(red: 0.88, green: 0.93, blue: 0.99, alpha: 1)
    private let lt = UITraitCollection(userInterfaceStyle: .light)
    private func c(_ color: UIColor) -> UIColor { color.resolvedColor(with: lt) }

    /// Must be called on the main thread. Copies all SwiftData objects into plain
    /// structs here, then dispatches PDF rendering to a background queue.
    @MainActor
    func erstellePDFAsync(
        eintraege: [PainEntry],
        medikamente: [Dauermedikation],
        einnahmeLogs: [EinnahmeLog] = [],
        midasBewertungen: [MIDASBewertung],
        zyklusEintraege: [ZyklusEintrag],
        haqEintraege: [HAQEintrag] = [],
        laborwerte: [Laborwert] = [],
        alleDiagnosen: [Diagnose] = [],
        profil: Benutzerprofil?,
        optionen: ExportOptionen,
        completion: @escaping @MainActor @Sendable (URL?) -> Void
    ) {
        // Copy all SwiftData objects into plain structs on main thread
        var patient = PDFPatientenDaten.aus(profil: profil)
        if !alleDiagnosen.isEmpty {
            let existing = Set(patient.diagnosen)
            let zusaetzliche = alleDiagnosen.map(\.bezeichnung).filter { !$0.isEmpty && !existing.contains($0) }
            patient.diagnosen = patient.diagnosen + zusaetzliche
        }
        let gefiltert: [PDFEintrag]
        if let start = optionen.zeitraum.startDatum() {
            gefiltert = eintraege.filter { $0.datum >= start }
                .sorted { $0.datum > $1.datum }
                .map(PDFEintrag.aus)
        } else {
            gefiltert = eintraege.sorted { $0.datum > $1.datum }.map(PDFEintrag.aus)
        }
        let meds      = medikamente.map(PDFMedikament.aus)
        let logs: [PDFEinnahmeLog]
        if let start = optionen.zeitraum.startDatum() {
            logs = einnahmeLogs.filter { $0.datum >= start }.sorted { $0.datum > $1.datum }.map(PDFEinnahmeLog.aus)
        } else {
            logs = einnahmeLogs.sorted { $0.datum > $1.datum }.map(PDFEinnahmeLog.aus)
        }
        let midas      = midasBewertungen.sorted { $0.datum > $1.datum }.map(PDFMidas.aus)
        let analyse    = ZyklusRechner.analyse(eintraege: zyklusEintraege)
        let zyklus     = zyklusEintraege.sorted { $0.datum > $1.datum }.map(PDFZyklusEintrag.aus)
        let ernaehrung = PDFErnaehrungsTag.lesen(start: optionen.zeitraum.startDatum())
        let haqPDF: [PDFHAQEintrag]
        if let start = optionen.zeitraum.startDatum() {
            haqPDF = haqEintraege.filter { $0.datum >= start }.sorted { $0.datum > $1.datum }.map(PDFHAQEintrag.aus)
        } else {
            haqPDF = haqEintraege.sorted { $0.datum > $1.datum }.map(PDFHAQEintrag.aus)
        }
        let labPDF: [PDFLaborwert]
        if let start = optionen.zeitraum.startDatum() {
            labPDF = laborwerte.filter { $0.datum >= start }.sorted { $0.datum > $1.datum }.map(PDFLaborwert.aus)
        } else {
            labPDF = laborwerte.sorted { $0.datum > $1.datum }.map(PDFLaborwert.aus)
        }

        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let url = self.renderPDF(patient: patient, eintraege: gefiltert,
                                     medikamente: meds, einnahmeLogs: logs, midas: midas,
                                     zyklus: zyklus, analyse: analyse, ernaehrung: ernaehrung,
                                     haqEintraege: haqPDF, laborwerte: labPDF, optionen: optionen)
            Task { @MainActor in completion(url) }
        }
    }

    // MARK: - Render

    private func renderPDF(
        patient: PDFPatientenDaten,
        eintraege: [PDFEintrag],
        medikamente: [PDFMedikament],
        einnahmeLogs: [PDFEinnahmeLog] = [],
        midas: [PDFMidas],
        zyklus: [PDFZyklusEintrag],
        analyse: ZyklusAnalyse,
        ernaehrung: [PDFErnaehrungsTag],
        haqEintraege: [PDFHAQEintrag] = [],
        laborwerte: [PDFLaborwert] = [],
        optionen: ExportOptionen
    ) -> URL? {
        let dateiname = "Schmerztagebuch_\(fmt(Date())).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(dateiname)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: W, height: H))

        var renderFehler: Error? = nil
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
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

                    if optionen.mitMedikamentDossier && (!medikamente.isEmpty || !einnahmeLogs.isEmpty) {
                        seite = medikamentDossierSeiten(ctx: ctx, medikamente: medikamente,
                                                        einnahmeLogs: einnahmeLogs, eintraege: eintraege,
                                                        startSeite: seite + 1)
                    }

                    if optionen.mitRheuma && (!haqEintraege.isEmpty || !laborwerte.isEmpty) {
                        seite += 1; ctx.beginPage()
                        rheumaSeite(ctx: ctx.cgContext, haqEintraege: haqEintraege,
                                    laborwerte: laborwerte, painEintraege: eintraege, seite: seite)
                    }

                    if optionen.mitZyklus && !zyklus.isEmpty {
                        seite += 1; ctx.beginPage()
                        zyklusSeite(ctx: ctx.cgContext, zyklusEintraege: zyklus,
                                    schmerzEintraege: eintraege, analyse: analyse, seite: seite)
                    }

                    if optionen.mitErnaehrung && !ernaehrung.isEmpty {
                        seite += 1; ctx.beginPage()
                        ernaehrungSeite(ctx: ctx.cgContext, daten: ernaehrung, seite: seite)
                    }

                    if optionen.mitEintraege && !eintraege.isEmpty {
                        seite += 1
                        eintraegeSeiten(ctx: ctx, eintraege: eintraege, startSeite: seite)
                    }
                }
            } catch {
                renderFehler = error
            }
        }
        return renderFehler == nil ? url : nil
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
            patient.geschlecht.isEmpty || patient.geschlecht == "Nicht angegeben" ? nil : ("Geschlecht", patient.geschlecht),
            patient.wohnort.isEmpty ? nil : ("Wohnort", patient.wohnort),
            patient.versicherung.isEmpty ? nil : ("Krankenkasse", patient.versicherung),
            patient.versicherungsNummer.isEmpty ? nil : ("Vers.-Nr.", patient.versicherungsNummer),
            patient.blutgruppe == "Unbekannt" || patient.blutgruppe.isEmpty ? nil : ("Blutgruppe", patient.blutgruppe),
            patient.bmiText.isEmpty ? nil : ("BMI", patient.bmiText),
            (patient.gewichtKg != nil && patient.groesseCm != nil) ? ("Körpermasse", String(format: "%.0f kg, %.0f cm", patient.gewichtKg!, patient.groesseCm!)) : nil,
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
        let schube = eintraege.filter(\.istSchub).count
        let letzterMidas = midas.first

        let boxW = (iw - 16) / 5
        statBox(ctx: ctx, x: rand,                       y: y, w: boxW, h: 72, titel: "Ø Schmerzstärke",
                wert: String(format: "%.1f/10", avg), farbe: .systemOrange)
        statBox(ctx: ctx, x: rand + (boxW + 4),           y: y, w: boxW, h: 72, titel: "Höchstwert",
                wert: "\(maxVal)/10", farbe: .systemRed)
        statBox(ctx: ctx, x: rand + (boxW + 4) * 2,       y: y, w: boxW, h: 72, titel: "Tage mit Schmerz",
                wert: "\(tage)", farbe: .systemBlue)
        statBox(ctx: ctx, x: rand + (boxW + 4) * 3,       y: y, w: boxW, h: 72, titel: "Schübe / Flares",
                wert: "\(schube)", farbe: schube > 0 ? .systemRed : .systemGreen)
        statBox(ctx: ctx, x: rand + (boxW + 4) * 4,       y: y, w: boxW, h: 72, titel: "MIDAS Score",
                wert: letzterMidas.map { "\($0.score)" } ?? "–", farbe: .systemPurple)
        y += 88

        if let m = letzterMidas {
            trennlinie(ctx: ctx, y: y); y += 12
            draw("MIDAS-Bewertung", at: CGPoint(x: rand, y: y),
                 font: .systemFont(ofSize: 13, weight: .semibold), color: .label)
            draw("vom \(fmt(m.datum))", at: CGPoint(x: rand + 140, y: y + 2),
                 font: .systemFont(ofSize: 10), color: .secondaryLabel)
            drawRight("Score: \(m.score) – \(m.gradText)", rightX: W - rand, y: y,
                      font: .systemFont(ofSize: 11, weight: .medium), color: .systemPurple)
            y += 20
            let midasZeilen: [(String, Int)] = [
                ("Tage Arbeit/Schule eingeschränkt", m.tageArbeitEingeschraenkt),
                ("Tage Arbeit/Schule gefehlt", m.tageArbeitGefehlt),
                ("Tage Haushalt eingeschränkt", m.tageHaushaltEingeschraenkt),
                ("Tage Haushalt gefehlt", m.tageHaushaltGefehlt),
                ("Tage Freizeit beeinträchtigt", m.tageFreizeit),
            ]
            for (label, tage) in midasZeilen {
                draw("• \(label):", at: CGPoint(x: rand + 8, y: y),
                     font: .systemFont(ofSize: 10), color: .secondaryLabel)
                drawRight("\(tage) Tage", rightX: W - rand, y: y,
                          font: .systemFont(ofSize: 10, weight: .medium), color: .label)
                y += 16
            }
            if !m.notizen.isEmpty {
                draw("Notiz: \(m.notizen)", at: CGPoint(x: rand + 8, y: y),
                     font: .systemFont(ofSize: 9), color: .secondaryLabel)
                y += 16
            }
            y += 6
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

        // Wohlbefinden-Durchschnitte
        let mitStimmung = eintraege.filter { $0.stimmung > 0 }
        let mitStress = eintraege.filter { $0.stressLevel > 0 }
        let mitSchlaf = eintraege.filter { $0.schlafStunden > 0 }
        let mitMorgensteifigkeit = eintraege.filter { $0.morgensteifigkeit > 0 }
        if !mitStimmung.isEmpty || !mitStress.isEmpty || !mitSchlaf.isEmpty || !mitMorgensteifigkeit.isEmpty {
            y += 8
            trennlinie(ctx: ctx, y: y); y += 14
            draw("Wohlbefinden (Durchschnitte)", at: CGPoint(x: rand, y: y),
                 font: .systemFont(ofSize: 13, weight: .semibold), color: .label)
            y += 20
            let wbCols: [CGFloat] = [rand, rand + 180, rand + 320]
            if !mitStimmung.isEmpty {
                let avgS = Double(mitStimmung.map(\.stimmung).reduce(0,+)) / Double(mitStimmung.count)
                draw("Stimmung:", at: CGPoint(x: wbCols[0], y: y), font: .systemFont(ofSize: 10), color: .secondaryLabel)
                draw(String(format: "Ø %.1f / 5", avgS), at: CGPoint(x: wbCols[1], y: y), font: .systemFont(ofSize: 10, weight: .medium), color: .label)
            }
            if !mitStress.isEmpty {
                let avgStr = Double(mitStress.map(\.stressLevel).reduce(0,+)) / Double(mitStress.count)
                draw("Stresslevel:", at: CGPoint(x: wbCols[0] + (mitStimmung.isEmpty ? 0 : 220), y: y), font: .systemFont(ofSize: 10), color: .secondaryLabel)
                draw(String(format: "Ø %.1f / 5", avgStr), at: CGPoint(x: wbCols[0] + (mitStimmung.isEmpty ? 0 : 220) + 80, y: y), font: .systemFont(ofSize: 10, weight: .medium), color: .label)
            }
            y += 16
            if !mitSchlaf.isEmpty {
                let avgSch = mitSchlaf.map(\.schlafStunden).reduce(0,+) / Double(mitSchlaf.count)
                draw("Schlaf:", at: CGPoint(x: wbCols[0], y: y), font: .systemFont(ofSize: 10), color: .secondaryLabel)
                draw(String(format: "Ø %.1f Stunden", avgSch), at: CGPoint(x: wbCols[1], y: y), font: .systemFont(ofSize: 10, weight: .medium), color: .label)
                y += 16
            }
            if !mitMorgensteifigkeit.isEmpty {
                let avgM = Double(mitMorgensteifigkeit.map(\.morgensteifigkeit).reduce(0,+)) / Double(mitMorgensteifigkeit.count)
                draw("Morgensteifigkeit:", at: CGPoint(x: wbCols[0], y: y), font: .systemFont(ofSize: 10), color: .secondaryLabel)
                draw(String(format: "Ø %.0f Min", avgM), at: CGPoint(x: wbCols[1], y: y), font: .systemFont(ofSize: 10, weight: .medium), color: .label)
                y += 16
            }
        }

        // Häufige Schmerzarten
        let schmerzartListe = schmerzartHaeufigkeit(eintraege: eintraege)
        if !schmerzartListe.isEmpty {
            y += 8
            trennlinie(ctx: ctx, y: y); y += 14
            draw("Häufige Schmerzarten", at: CGPoint(x: rand, y: y),
                 font: .systemFont(ofSize: 13, weight: .semibold), color: .label)
            y += 20
            for (i, (name, count)) in schmerzartListe.prefix(5).enumerated() {
                draw("\(i+1). \(name)", at: CGPoint(x: rand, y: y),
                     font: .systemFont(ofSize: 11), color: .label)
                drawRight("\(count)×", rightX: W - rand, y: y,
                          font: .systemFont(ofSize: 11), color: .secondaryLabel)
                y += 18
            }
        }

        // Häufige Begleiterscheinungen
        let begleitListe = begleitHaeufigkeit(eintraege: eintraege)
        if !begleitListe.isEmpty {
            y += 8
            trennlinie(ctx: ctx, y: y); y += 14
            draw("Häufige Begleiterscheinungen", at: CGPoint(x: rand, y: y),
                 font: .systemFont(ofSize: 13, weight: .semibold), color: .label)
            y += 20
            for (i, (name, count)) in begleitListe.prefix(5).enumerated() {
                draw("\(i+1). \(name)", at: CGPoint(x: rand, y: y),
                     font: .systemFont(ofSize: 11), color: .label)
                drawRight("\(count)×", rightX: W - rand, y: y,
                          font: .systemFont(ofSize: 11), color: .secondaryLabel)
                y += 18
            }
        }

        // Häufige Massnahmen
        let massnahmenListe = massnahmenHaeufigkeit(eintraege: eintraege)
        if !massnahmenListe.isEmpty {
            y += 8
            trennlinie(ctx: ctx, y: y); y += 14
            draw("Angewandte Massnahmen", at: CGPoint(x: rand, y: y),
                 font: .systemFont(ofSize: 13, weight: .semibold), color: .label)
            y += 20
            for (i, (name, count)) in massnahmenListe.prefix(5).enumerated() {
                draw("\(i+1). \(name)", at: CGPoint(x: rand, y: y),
                     font: .systemFont(ofSize: 11), color: .label)
                drawRight("\(count)×", rightX: W - rand, y: y,
                          font: .systemFont(ofSize: 11), color: .secondaryLabel)
                y += 18
            }
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

            let cols: [CGFloat] = [rand, rand + 175, rand + 290, rand + 380]
            tabellenKopf(ctx: ctx, y: y, cols: cols, headers: ["Medikament", "Dosierung", "Frequenz", "Seit"])
            y += 26

            for med in aktive {
                if y > H - rand - 30 { break }
                tabellenZeile(ctx: ctx, y: y, cols: cols,
                              werte: [med.name, med.dosierung, med.frequenz, fmt(med.startDatum)],
                              fett: [true, false, false, false])
                y += 14
                // Sub-row: typ / hinweis / ablauf / vorrat
                var extras: [String] = []
                if !med.medikamentTyp.isEmpty { extras.append(med.medikamentTyp) }
                if !med.einnahmeHinweis.isEmpty   { extras.append("⚑ \(med.einnahmeHinweis)") }
                if let ablauf = med.ablaufDatum {
                    let tage = Calendar.current.dateComponents([.day], from: Date(), to: ablauf).day ?? 0
                    extras.append(tage <= 14 ? "⚠ Ablauf: \(fmt(ablauf)) (\(tage) Tage)" : "Ablauf: \(fmt(ablauf))")
                }
                if let vorrat = med.vorrat {
                    extras.append(vorrat <= med.vorratSchwelle ? "⚠ Vorrat: \(vorrat) Stück" : "Vorrat: \(vorrat) Stück")
                }
                if !extras.isEmpty {
                    draw(extras.joined(separator: "   "),
                         at: CGPoint(x: cols[1] + 4, y: y),
                         font: .systemFont(ofSize: 8.5),
                         color: extras.contains(where: { $0.hasPrefix("⚠") }) ? .systemOrange : .secondaryLabel)
                    y += 13
                }
                trennlinie(ctx: ctx, y: y, alpha: 0.12)
                y += 4
            }
            y += 12
        }

        if !inaktive.isEmpty {
            trennlinie(ctx: ctx, y: y); y += 16
            draw("Frühere Medikation", at: CGPoint(x: rand, y: y),
                 font: .systemFont(ofSize: 13, weight: .semibold), color: .secondaryLabel)
            y += 20

            let inaktCols: [CGFloat] = [rand, rand + 180, rand + 300, rand + 400]
            tabellenKopf(ctx: ctx, y: y, cols: inaktCols, headers: ["Medikament", "Dosierung", "Seit", "Abgesetzt"])
            y += 26

            for med in inaktive {
                if y > H - rand - 20 { break }
                tabellenZeile(ctx: ctx, y: y, cols: inaktCols,
                              werte: [med.name, med.dosierung, fmt(med.startDatum),
                                      med.endDatum.map { fmt($0) } ?? "–"],
                              fett: [false, false, false, false])
                y += 18
                trennlinie(ctx: ctx, y: y - 1, alpha: 0.08)
            }
        }

        fusszeile(ctx: ctx, seite: seite)
    }

    // MARK: - Medication Dossier page (Feature F)

    @discardableResult
    private func medikamentDossierSeiten(
        ctx: UIGraphicsPDFRendererContext,
        medikamente: [PDFMedikament],
        einnahmeLogs: [PDFEinnahmeLog],
        eintraege: [PDFEintrag],
        startSeite: Int
    ) -> Int {
        var seite = startSeite
        let gc = ctx.cgContext
        ctx.beginPage()
        seitenKopf(ctx: gc, titel: "Medikamenten-Dossier", seite: seite)
        var y: CGFloat = rand + 52

        func newPage() {
            fusszeile(ctx: gc, seite: seite)
            seite += 1
            ctx.beginPage()
            seitenKopf(ctx: gc, titel: "Medikamenten-Dossier (Forts.)", seite: seite)
            y = rand + 52
        }

        let kal = Calendar.current
        let heute = kal.startOfDay(for: Date())
        let aktive = medikamente.filter { $0.aktiv }

        // --- Einnahmetreue ---
        if !aktive.isEmpty {
            draw("Einnahmetreue (letzte 30 Tage)", at: CGPoint(x: rand, y: y),
                 font: .systemFont(ofSize: 13, weight: .semibold), color: .black)
            y += 20
            let cols: [CGFloat] = [rand, rand + 160, rand + 270, rand + 355, rand + 430]
            tabellenKopf(ctx: gc, y: y, cols: cols,
                         headers: ["Medikament", "Dosierung", "Hinweis", "Treue", "Einnahmen"])
            y += 26
            for med in aktive {
                if y + 20 > H - rand - 30 {
                    newPage()
                    tabellenKopf(ctx: gc, y: y, cols: cols,
                                 headers: ["Medikament", "Dosierung", "Hinweis", "Treue", "Einnahmen"])
                    y += 26
                }
                let fensterStart = kal.date(byAdding: .day, value: -30, to: heute)!
                let tageSeitStart = max(1, kal.dateComponents([.day],
                    from: kal.startOfDay(for: med.startDatum), to: heute).day ?? 1)
                let fensterTage = min(30, tageSeitStart)
                let einnahmenImFenster = einnahmeLogs.filter {
                    $0.medikamentName == med.name && $0.dosierung == med.dosierung &&
                    $0.eingenommen && $0.datum >= fensterStart
                }
                let einnahmenTage = Set(einnahmenImFenster.map { kal.startOfDay(for: $0.datum) }).count
                let treue = fensterTage > 0 ? min(100, Int(Double(einnahmenTage) / Double(fensterTage) * 100)) : 0
                let hinweis = med.einnahmeHinweis.isEmpty ? "–" : med.einnahmeHinweis
                tabellenZeile(ctx: gc, y: y, cols: cols,
                              werte: [med.name, med.dosierung, hinweis, "\(treue)%", "\(einnahmenTage) Tage"],
                              fett: [true, false, false, true, false])
                y += 20
                trennlinie(ctx: gc, y: y - 1, alpha: 0.12)
            }
            y += 12
        }

        // --- Einnahme-Protokoll (alle Logs) ---
        if !einnahmeLogs.isEmpty {
            if y + 60 > H - rand - 30 { newPage() }
            trennlinie(ctx: gc, y: y); y += 14
            draw("Einnahme-Protokoll", at: CGPoint(x: rand, y: y),
                 font: .systemFont(ofSize: 13, weight: .semibold), color: .black)
            y += 20
            let logCols: [CGFloat] = [rand, rand + 85, rand + 280, rand + 360, rand + 420]
            tabellenKopf(ctx: gc, y: y, cols: logCols,
                         headers: ["Datum", "Medikament / Dosierung", "Eingenommen", "Wirkung", "Notizen"])
            y += 26
            for log in einnahmeLogs {
                if y + 20 > H - rand - 30 {
                    newPage()
                    tabellenKopf(ctx: gc, y: y, cols: logCols,
                                 headers: ["Datum", "Medikament / Dosierung", "Eingenommen", "Wirkung", "Notizen"])
                    y += 26
                }
                let status = log.eingenommen ? "✓ Ja" : "✗ Nein"
                let statusFarbe: UIColor = log.eingenommen
                    ? UIColor(red: 0.17, green: 0.70, blue: 0.37, alpha: 1)
                    : UIColor(red: 0.96, green: 0.23, blue: 0.19, alpha: 1)
                let medName = log.dosierung.isEmpty ? log.medikamentName : "\(log.medikamentName) \(log.dosierung)"
                let wirkungText: String = {
                    switch log.wirkung {
                    case "gut":       return "Gut"
                    case "teilweise": return "Teilw."
                    case "nicht":     return "Nicht"
                    default:          return log.wirkung.isEmpty ? "–" : log.wirkung
                    }
                }()
                let notizKurz = log.notizen.isEmpty ? "–" : String(log.notizen.prefix(25))
                draw(fmtKurz(log.datum), at: CGPoint(x: logCols[0] + 4, y: y + 4),
                     font: .systemFont(ofSize: 9.5), color: .black)
                drawClamped(medName, at: CGPoint(x: logCols[1] + 4, y: y + 4),
                            font: .systemFont(ofSize: 9.5, weight: .medium), color: .black,
                            maxW: logCols[2] - logCols[1] - 8)
                draw(status, at: CGPoint(x: logCols[2] + 4, y: y + 4),
                     font: .systemFont(ofSize: 9.5, weight: .semibold), color: statusFarbe)
                draw(wirkungText, at: CGPoint(x: logCols[3] + 4, y: y + 4),
                     font: .systemFont(ofSize: 9.5), color: .black)
                drawClamped(notizKurz, at: CGPoint(x: logCols[4] + 4, y: y + 4),
                            font: .systemFont(ofSize: 9), color: UIColor(white: 0.45, alpha: 1),
                            maxW: W - rand - logCols[4] - 8)
                y += 20
                trennlinie(ctx: gc, y: y - 1, alpha: 0.12)
            }
            y += 8
        }

        // --- Wirksamkeit ---
        let bewertet = einnahmeLogs.filter { !$0.wirkung.isEmpty }
        if !bewertet.isEmpty {
            if y + 60 > H - rand - 30 { newPage() }
            trennlinie(ctx: gc, y: y); y += 14
            draw("Wirksamkeit Bedarfsmedikation", at: CGPoint(x: rand, y: y),
                 font: .systemFont(ofSize: 13, weight: .semibold), color: .black)
            y += 20
            let grouped = Dictionary(grouping: bewertet) { "\($0.medikamentName)|\($0.dosierung)" }
            for (_, logs) in grouped.sorted(by: { $0.key < $1.key }) {
                if y + 22 > H - rand - 30 { newPage() }
                guard let erster = logs.first else { continue }
                let name = erster.dosierung.isEmpty ? erster.medikamentName : "\(erster.medikamentName) \(erster.dosierung)"
                let gut = logs.filter { $0.wirkung == "gut" }.count
                let teilw = logs.filter { $0.wirkung == "teilweise" }.count
                let nicht = logs.filter { $0.wirkung == "nicht" }.count
                let gesamt = gut + teilw + nicht
                let gutPct = gesamt > 0 ? Int(Double(gut) / Double(gesamt) * 100) : 0
                draw(name, at: CGPoint(x: rand, y: y),
                     font: .systemFont(ofSize: 11, weight: .semibold), color: .black)
                let barMaxW: CGFloat = iw - 220
                let barStart: CGFloat = rand + 200
                let gutW   = barMaxW * CGFloat(gut)   / CGFloat(max(1, gesamt))
                let teilwW = barMaxW * CGFloat(teilw)  / CGFloat(max(1, gesamt))
                let nichtW = barMaxW * CGFloat(nicht)  / CGFloat(max(1, gesamt))
                gc.setFillColor(UIColor(red: 0.17, green: 0.70, blue: 0.37, alpha: 0.65).cgColor)
                gc.fill(CGRect(x: barStart, y: y + 2, width: gutW, height: 12))
                gc.setFillColor(UIColor(red: 1.00, green: 0.60, blue: 0.00, alpha: 0.65).cgColor)
                gc.fill(CGRect(x: barStart + gutW, y: y + 2, width: teilwW, height: 12))
                gc.setFillColor(UIColor(red: 0.96, green: 0.23, blue: 0.19, alpha: 0.65).cgColor)
                gc.fill(CGRect(x: barStart + gutW + teilwW, y: y + 2, width: nichtW, height: 12))
                draw("\(gutPct)% gut  (\(gut)/\(teilw)/\(nicht))",
                     at: CGPoint(x: barStart + barMaxW + 6, y: y + 2),
                     font: .systemFont(ofSize: 9), color: UIColor(white: 0.45, alpha: 1))
                y += 22
            }
        }

        // --- Wochenverlauf Bedarfsmedikation ---
        let bedarfsMeds = medikamente.filter { $0.frequenz == "Bei Bedarf" || $0.frequenz.isEmpty }
        let bedarfsLogs = einnahmeLogs.filter { log in
            bedarfsMeds.contains { $0.name == log.medikamentName } && log.eingenommen
        }
        if !bedarfsLogs.isEmpty {
            if y + 160 > H - rand - 30 { newPage() }
            trennlinie(ctx: gc, y: y); y += 14
            draw("Bedarfsmedikation – Wochenverlauf (letzte 8 Wochen)", at: CGPoint(x: rand, y: y),
                 font: .systemFont(ofSize: 13, weight: .semibold), color: .black)
            y += 20
            let wochen = (0..<8).reversed().map { wocheVor -> (label: String, anzahl: Int) in
                guard let wocheEnde = kal.date(byAdding: .weekOfYear, value: -wocheVor, to: heute),
                      let wocheStart = kal.date(byAdding: .day, value: -6, to: wocheEnde) else {
                    return ("?", 0)
                }
                let n = bedarfsLogs.filter { $0.datum >= wocheStart && $0.datum <= wocheEnde }.count
                return (wocheVor == 0 ? "Diese Woche" : "−\(wocheVor)W", n)
            }
            let maxAnzahl = max(1, wochen.map(\.anzahl).max() ?? 1)
            let barMaxW: CGFloat = iw - 80
            let barH: CGFloat = 14
            for (label, anzahl) in wochen {
                if y + barH + 2 > H - rand - 30 { break }
                let bw = CGFloat(anzahl) / CGFloat(maxAnzahl) * barMaxW
                draw(label, at: CGPoint(x: rand, y: y), font: .systemFont(ofSize: 9),
                     color: UIColor(white: 0.45, alpha: 1))
                let barFarbe = anzahl > 2
                    ? UIColor(red: 1.00, green: 0.60, blue: 0.00, alpha: 0.55)
                    : UIColor(red: 0.00, green: 0.48, blue: 1.00, alpha: 0.55)
                if bw > 0 {
                    gc.setFillColor(barFarbe.cgColor)
                    gc.fill(CGRect(x: rand + 72, y: y + 1, width: bw, height: barH - 3))
                }
                let anzahlFarbe = anzahl > 2
                    ? UIColor(red: 1.00, green: 0.60, blue: 0.00, alpha: 1)
                    : UIColor(white: 0.45, alpha: 1)
                draw("\(anzahl)×", at: CGPoint(x: rand + 72 + bw + 4, y: y),
                     font: .systemFont(ofSize: 9, weight: anzahl > 2 ? .bold : .regular),
                     color: anzahlFarbe)
                y += barH + 2
            }
            draw("⚠︎ Grenze: >2.5× pro Woche = Übergebrauchsrisiko (MOH)",
                 at: CGPoint(x: rand, y: y + 2), font: .systemFont(ofSize: 8),
                 color: UIColor(red: 1.00, green: 0.60, blue: 0.00, alpha: 1))
            y += 16
        }

        // --- Einnahme-Notizen ---
        let notizLogs = einnahmeLogs.filter { !$0.notizen.isEmpty }
        if !notizLogs.isEmpty {
            if y + 60 > H - rand - 30 { newPage() }
            trennlinie(ctx: gc, y: y); y += 14
            draw("Einnahme-Notizen", at: CGPoint(x: rand, y: y),
                 font: .systemFont(ofSize: 13, weight: .semibold), color: .black)
            y += 20
            for log in notizLogs {
                if y + 34 > H - rand - 30 { newPage() }
                let kopf = "\(fmtKurz(log.datum))  \(log.medikamentName)\(log.dosierung.isEmpty ? "" : " \(log.dosierung)")"
                draw(kopf, at: CGPoint(x: rand, y: y),
                     font: .systemFont(ofSize: 10, weight: .semibold), color: .black)
                y += 14
                let notizText = log.notizen.replacingOccurrences(of: "\n", with: " ")
                drawClamped(notizText, at: CGPoint(x: rand + 10, y: y),
                            font: .systemFont(ofSize: 9.5), color: UIColor(white: 0.3, alpha: 1),
                            maxW: iw - 10)
                y += 14
                trennlinie(ctx: gc, y: y, alpha: 0.08)
                y += 6
            }
        }

        fusszeile(ctx: gc, seite: seite)
        return seite
    }

    // MARK: - Zyklus page

    private func zyklusSeite(ctx: CGContext, zyklusEintraege: [PDFZyklusEintrag],
                              schmerzEintraege: [PDFEintrag], analyse: ZyklusAnalyse, seite: Int) {
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
                while zyklusEintraege.contains(where: { $0.istPeriode && kal.isDate($0.datum, inSameDayAs: check) }) {
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

        let symptomMap = zyklusEintraege.flatMap(\.symptome)
            .reduce(into: [:]) { $0[$1, default: 0] += 1 }
        let sortiert = symptomMap.sorted { $0.value > $1.value }
        let maxS = max(1, sortiert.first?.value ?? 1)

        for (symptom, count) in sortiert.prefix(8) {
            if y > H - rand - 30 { break }
            let barW = CGFloat(count) / CGFloat(maxS) * (iw - 140)
            draw(symptom, at: CGPoint(x: rand, y: y + 2),
                 font: .systemFont(ofSize: 10), color: .label)
            ctx.setFillColor(c(.systemPink).withAlphaComponent(0.5).cgColor)
            ctx.fill(CGRect(x: rand + 130, y: y + 2, width: barW, height: 12))
            draw("\(count)×", at: CGPoint(x: rand + 130 + barW + 4, y: y + 2),
                 font: .systemFont(ofSize: 9), color: .secondaryLabel)
            y += 18
        }

        // Zervixschleim-Häufigkeit
        let zervixMap = zyklusEintraege.map(\.zervixschleim)
            .filter { !$0.isEmpty && $0 != "Nicht erfasst" && $0 != "Keine Angabe" }
            .reduce(into: [:]) { $0[$1, default: 0] += 1 }
        if !zervixMap.isEmpty {
            y += 8
            draw("Zervixschleim", at: CGPoint(x: rand, y: y),
                 font: .systemFont(ofSize: 11, weight: .semibold), color: .secondaryLabel)
            y += 16
            for (typ, count) in zervixMap.sorted(by: { $0.value > $1.value }) {
                if y > H - rand - 40 { break }
                draw("• \(typ): \(count)×", at: CGPoint(x: rand + 12, y: y),
                     font: .systemFont(ofSize: 10), color: .label)
                y += 15
            }
        }

        // Schmerz-Zyklus-Korrelation
        if !schmerzEintraege.isEmpty && !analyse.zyklusStarts.isEmpty {
            trennlinie(ctx: ctx, y: y); y += 14
            draw("Schmerz nach Zyklusphase", at: CGPoint(x: rand, y: y),
                 font: .systemFont(ofSize: 13, weight: .semibold), color: .label)
            y += 20

            let phasen: [(String, UIColor)] = [
                ("Menstruation", .systemRed),
                ("Follikulär", .systemGreen),
                ("Eisprung", .systemTeal),
                ("Lutealphase", .systemPurple)
            ]

            var phaseScores: [String: [Int]] = [:]
            for eintrag in schmerzEintraege {
                if let phase = zyklusphase(fuer: eintrag.datum, analyse: analyse) {
                    phaseScores[phase, default: []].append(eintrag.schmerzstaerke)
                }
            }

            let barMaxW: CGFloat = iw - 180

            for (name, farbe) in phasen {
                guard let vals = phaseScores[name], !vals.isEmpty else { continue }
                if y > H - rand - 40 { break }
                let avg = Double(vals.reduce(0, +)) / Double(vals.count)
                let barW = CGFloat(avg / 10.0) * barMaxW
                draw(name, at: CGPoint(x: rand, y: y + 2),
                     font: .systemFont(ofSize: 10), color: .label)
                ctx.setFillColor(farbe.withAlphaComponent(0.6).cgColor)
                ctx.fill(CGRect(x: rand + 120, y: y + 2, width: barW, height: 13))
                draw(String(format: "Ø %.1f/10  (%d Eintr.)", avg, vals.count),
                     at: CGPoint(x: rand + 120 + barW + 6, y: y + 2),
                     font: .systemFont(ofSize: 9), color: .secondaryLabel)
                y += 19
            }
            y += 4
        }

        fusszeile(ctx: ctx, seite: seite)
    }

    // MARK: - Ernährung page

    private func ernaehrungSeite(ctx: CGContext, daten: [PDFErnaehrungsTag], seite: Int) {
        seitenKopf(ctx: ctx, titel: "Ernährung & Hydration", seite: seite)
        var y: CGFloat = rand + 52

        let tage = daten.count
        let avgKoffein = tage > 0 ? Double(daten.map(\.koffeinTassen).reduce(0,+)) / Double(tage) : 0.0
        let avgAlkohol = tage > 0 ? Double(daten.map(\.alkoholGlaeser).reduce(0,+)) / Double(tage) : 0.0
        let avgWasser  = tage > 0 ? Double(daten.map(\.wasserMl).reduce(0,+)) / Double(tage) : 0.0

        let boxW = (iw - 12) / 4
        statBox(ctx: ctx, x: rand,                  y: y, w: boxW, h: 72, titel: "Ø Koffein/Tag",
                wert: String(format: "%.1f Tassen", avgKoffein), farbe: UIColor(red: 0.4, green: 0.25, blue: 0.1, alpha: 1))
        statBox(ctx: ctx, x: rand + boxW + 4,        y: y, w: boxW, h: 72, titel: "Ø Alkohol/Tag",
                wert: String(format: "%.1f Gläser", avgAlkohol), farbe: .systemPurple)
        statBox(ctx: ctx, x: rand + (boxW + 4) * 2,  y: y, w: boxW, h: 72, titel: "Ø Wasser/Tag",
                wert: String(format: "%.0f ml", avgWasser), farbe: .systemTeal)
        statBox(ctx: ctx, x: rand + (boxW + 4) * 3,  y: y, w: boxW, h: 72, titel: "Tage erfasst",
                wert: "\(tage)", farbe: .systemGreen)
        y += 88

        // Mahlzeiten adherence
        trennlinie(ctx: ctx, y: y); y += 14
        draw("Mahlzeiten-Regelmässigkeit", at: CGPoint(x: rand, y: y),
             font: .systemFont(ofSize: 13, weight: .semibold), color: .label)
        y += 20
        let labelW: CGFloat = 96
        let barMaxW = iw - labelW - 44
        for (name, count) in [("Frühstück", daten.filter(\.hatFruehstueck).count),
                               ("Mittagessen", daten.filter(\.hatMittag).count),
                               ("Abendessen", daten.filter(\.hatAbend).count)] {
            let pct = tage > 0 ? Int(Double(count) / Double(tage) * 100) : 0
            draw(name, at: CGPoint(x: rand, y: y), font: .systemFont(ofSize: 11), color: .label)
            let bw = CGFloat(pct) / 100.0 * barMaxW
            ctx.setFillColor(blau.withAlphaComponent(0.55).cgColor)
            ctx.fill(CGRect(x: rand + labelW, y: y + 3, width: max(0, bw), height: 11))
            draw("\(pct)% (\(count) Tage)", at: CGPoint(x: rand + labelW + max(0, bw) + 6, y: y),
                 font: .systemFont(ofSize: 9), color: .secondaryLabel)
            y += 22
        }
        y += 10

        // Daily table
        trennlinie(ctx: ctx, y: y); y += 14
        draw("Tagesübersicht (neueste zuerst)", at: CGPoint(x: rand, y: y),
             font: .systemFont(ofSize: 13, weight: .semibold), color: .label)
        y += 20

        let cols: [CGFloat] = [rand, rand + 70, rand + 155, rand + 240, rand + 330]
        tabellenKopf(ctx: ctx, y: y, cols: cols,
                     headers: ["Datum", "Koffein", "Alkohol", "Wasser", "Mahlzeiten"])
        y += 22

        for tag in daten.reversed().prefix(30) {
            if y > H - rand - 30 { break }
            let mahlz = [tag.hatFruehstueck ? "Früh" : nil,
                         tag.hatMittag ? "Mittag" : nil,
                         tag.hatAbend ? "Abend" : nil].compactMap { $0 }.joined(separator: ", ")
            tabellenZeile(ctx: ctx, y: y, cols: cols, werte: [
                fmtKurz(tag.datum),
                tag.koffeinTassen > 0 ? "\(tag.koffeinTassen) Tassen" : "–",
                tag.alkoholGlaeser > 0 ? "\(tag.alkoholGlaeser) Gläser" : "–",
                tag.wasserMl > 0 ? "\(tag.wasserMl) ml" : "–",
                mahlz.isEmpty ? "–" : mahlz
            ], fett: [false, false, false, false, false])
            y += 16
            trennlinie(ctx: ctx, y: y, alpha: 0.08)
            y += 3
        }

        fusszeile(ctx: ctx, seite: seite)
    }

    // MARK: - Rheuma page

    private func rheumaSeite(ctx: CGContext, haqEintraege: [PDFHAQEintrag],
                              laborwerte: [PDFLaborwert], painEintraege: [PDFEintrag], seite: Int) {
        seitenKopf(ctx: ctx, titel: "Rheuma & Gelenke", seite: seite)
        var y: CGFloat = rand + 52

        let schube = painEintraege.filter(\.istSchub).count
        let mitGelenk = painEintraege.filter { !$0.gelenkStatus.isEmpty }
        let avgTJC = mitGelenk.isEmpty ? 0 : mitGelenk.map { e -> Int in
            let g = GelenkStatusCoder.decode(e.gelenkStatus)
            return g.filter { $0.value == .schmerzhaft || $0.value == .beides }.count
        }.reduce(0, +) / mitGelenk.count
        let avgSJC = mitGelenk.isEmpty ? 0 : mitGelenk.map { e -> Int in
            let g = GelenkStatusCoder.decode(e.gelenkStatus)
            return g.filter { $0.value == .geschwollen || $0.value == .beides }.count
        }.reduce(0, +) / mitGelenk.count

        let boxW = (iw - 8) / 3
        statBox(ctx: ctx, x: rand,              y: y, w: boxW, h: 72, titel: "Schübe im Zeitraum",
                wert: "\(schube)", farbe: schube > 0 ? .systemRed : .systemGreen)
        statBox(ctx: ctx, x: rand + boxW + 4,   y: y, w: boxW, h: 72, titel: "Ø Druckschmerzhafte Gelenke",
                wert: mitGelenk.isEmpty ? "–" : "\(avgTJC)", farbe: .systemOrange)
        statBox(ctx: ctx, x: rand + (boxW+4)*2, y: y, w: boxW, h: 72, titel: "Ø Geschwollene Gelenke",
                wert: mitGelenk.isEmpty ? "–" : "\(avgSJC)", farbe: .systemPurple)
        y += 88

        // HAQ history
        if !haqEintraege.isEmpty {
            trennlinie(ctx: ctx, y: y); y += 14
            draw("HAQ-DI Verlauf", at: CGPoint(x: rand, y: y),
                 font: .systemFont(ofSize: 13, weight: .semibold), color: .label)
            y += 20

            let cols: [CGFloat] = [rand, rand + 90, rand + 230, rand + 360]
            tabellenKopf(ctx: ctx, y: y, cols: cols,
                         headers: ["Datum", "HAQ-DI Score", "Grad", "Globales Befinden"])
            y += 26

            for e in haqEintraege.prefix(12) {
                if y > H - rand - 30 { break }
                let scoreText = String(format: "%.2f", e.haqScore)
                let globalText = e.globalBewertung > 0 ? "\(e.globalBewertung)/100" : "–"
                let scoreColor: UIColor = e.haqScore < 0.5 ? .systemGreen
                    : e.haqScore < 1.5 ? .systemOrange : .systemRed
                tabellenZeile(ctx: ctx, y: y, cols: cols,
                              werte: [fmt(e.datum), scoreText, e.haqGradText, globalText],
                              fett: [false, true, false, false])
                if e.haqScore > 0 {
                    let bw = CGFloat(e.haqScore / 3.0) * (iw - 100)
                    ctx.setFillColor(scoreColor.withAlphaComponent(0.3).cgColor)
                    ctx.fill(CGRect(x: cols[1] + 4, y: y + 12, width: bw, height: 5))
                }
                y += 22
                trennlinie(ctx: ctx, y: y - 2, alpha: 0.08)
            }
            y += 10
        }

        // Laborwerte
        if !laborwerte.isEmpty {
            if y + 60 > H - rand - 30 { y = H }
            trennlinie(ctx: ctx, y: y); y += 14
            draw("Laborwerte", at: CGPoint(x: rand, y: y),
                 font: .systemFont(ofSize: 13, weight: .semibold), color: .label)
            y += 20

            let labCols: [CGFloat] = [rand, rand + 80, rand + 200, rand + 290, rand + 380]
            tabellenKopf(ctx: ctx, y: y, cols: labCols,
                         headers: ["Datum", "Parameter", "Wert", "Einheit", "Referenz"])
            y += 26

            for lw in laborwerte.prefix(20) {
                if y > H - rand - 30 { break }
                let refText: String
                if let rMin = lw.referenzMin, let rMax = lw.referenzMax {
                    refText = "\(String(format: "%.1f", rMin))–\(String(format: "%.1f", rMax))"
                } else if let rMax = lw.referenzMax {
                    refText = "< \(String(format: "%.1f", rMax))"
                } else {
                    refText = "–"
                }
                let abweichung = lw.istErhoeht == true ? " ↑" : (lw.istErniedrigt == true ? " ↓" : "")
                let wertFarbe: UIColor = lw.istErhoeht == true || lw.istErniedrigt == true
                    ? .systemOrange : .label
                tabellenZeile(ctx: ctx, y: y, cols: labCols,
                              werte: [fmt(lw.datum), lw.typ,
                                      String(format: "%.1f", lw.wert) + abweichung,
                                      lw.einheit, refText],
                              fett: [false, false, true, false, false])
                if lw.istErhoeht == true || lw.istErniedrigt == true {
                    let x = labCols[2] + 4
                    let wertW = CGFloat(50)
                    ctx.setFillColor(wertFarbe.withAlphaComponent(0.12).cgColor)
                    ctx.fill(CGRect(x: x - 2, y: y, width: wertW, height: 16))
                }
                y += 18
                trennlinie(ctx: ctx, y: y - 1, alpha: 0.08)
            }
            y += 10
        }

        // Schub trend
        if schube > 0 && painEintraege.count >= 5 {
            if y + 40 > H - rand - 30 { y = H }
            trennlinie(ctx: ctx, y: y); y += 14
            draw("Schub-Auslöser Analyse", at: CGPoint(x: rand, y: y),
                 font: .systemFont(ofSize: 13, weight: .semibold), color: .label)
            y += 20

            let schubEintraege = painEintraege.filter(\.istSchub)
            let keineSchubEintraege = painEintraege.filter { !$0.istSchub }

            let avgStressSchub = schubEintraege.filter { $0.stressLevel > 0 }.map { Double($0.stressLevel) }
            let avgStressKein  = keineSchubEintraege.filter { $0.stressLevel > 0 }.map { Double($0.stressLevel) }
            let avgSchlafSchub = schubEintraege.filter { $0.schlafStunden > 0 }.map { $0.schlafStunden }
            let avgSchlafKein  = keineSchubEintraege.filter { $0.schlafStunden > 0 }.map { $0.schlafStunden }

            func avg(_ vals: [Double]) -> Double { vals.isEmpty ? 0 : vals.reduce(0,+)/Double(vals.count) }

            let vergleiche: [(String, Double, Double)] = [
                ("Stress (Ø)", avg(avgStressSchub), avg(avgStressKein)),
                ("Schlaf h (Ø)", avg(avgSchlafSchub), avg(avgSchlafKein)),
            ].filter { $0.1 > 0 || $0.2 > 0 }

            for (label, schubWert, keinWert) in vergleiche {
                if y > H - rand - 30 { break }
                draw(label, at: CGPoint(x: rand, y: y), font: .systemFont(ofSize: 10), color: .secondaryLabel)
                draw("Schub: \(String(format: "%.1f", schubWert))",
                     at: CGPoint(x: rand + 130, y: y),
                     font: .systemFont(ofSize: 10, weight: .medium),
                     color: .systemRed)
                draw("Kein Schub: \(String(format: "%.1f", keinWert))",
                     at: CGPoint(x: rand + 260, y: y),
                     font: .systemFont(ofSize: 10, weight: .medium),
                     color: .systemGreen)
                y += 16
            }
        }

        fusszeile(ctx: ctx, seite: seite)
    }

    // MARK: - Entries pages

    private func eintraegeSeiten(ctx: UIGraphicsPDFRendererContext, eintraege: [PDFEintrag], startSeite: Int) {
        var seite = startSeite
        ctx.beginPage()
        seitenKopf(ctx: ctx.cgContext, titel: "Einträge", seite: seite)
        var y: CGFloat = rand + 52

        // col widths: Datum 72 | Stärke 68 | Körperstelle 140 | Auslöser 80 | Dauer 55 | Art rest
        let cols: [CGFloat] = [rand, rand + 72, rand + 140, rand + 280, rand + 360, rand + 415]
        let headers = ["Datum", "Stärke", "Körperstelle / Hautstelle", "Auslöser", "Dauer", "Art / Typ"]
        tabellenKopf(ctx: ctx.cgContext, y: y, cols: cols, headers: headers)
        y += 26

        for eintrag in eintraege {
            let quelleStellen = eintrag.istHautEintrag ? eintrag.hautStellen : eintrag.koerperstelle
            let koerperstellen = quelleStellen.components(separatedBy: ", ").filter { !$0.isEmpty }
            let mehrereStellen = koerperstellen.count > 1

            // Build sub-rows
            var subZeilen: [(text: String, farbe: UIColor)] = []
            if mehrereStellen {
                subZeilen.append((
                    "Alle Stellen: \(koerperstellen.joined(separator: ", "))",
                    UIColor.systemOrange.withAlphaComponent(0.8)
                ))
            }
            if !eintrag.begleiterscheinungen.isEmpty {
                subZeilen.append(("Begleit.: \(String(eintrag.begleiterscheinungen.prefix(60)))", .secondaryLabel))
            }
            if !eintrag.massnahmen.isEmpty {
                subZeilen.append(("Massnahmen: \(String(eintrag.massnahmen.prefix(60)))", .secondaryLabel))
            }
            if eintrag.istSchub {
                subZeilen.append(("⚡ Rheuma-Schub / Flare", UIColor.systemRed.withAlphaComponent(0.8)))
            }
            if !eintrag.gelenkStatus.isEmpty {
                let gelenke = GelenkStatusCoder.decode(eintrag.gelenkStatus)
                let schmerz = gelenke.filter { $0.value == .schmerzhaft || $0.value == .beides }.count
                let geschwollen = gelenke.filter { $0.value == .geschwollen || $0.value == .beides }.count
                if schmerz > 0 || geschwollen > 0 {
                    subZeilen.append(("Gelenke: \(schmerz) schmerzhaft, \(geschwollen) geschwollen",
                                      UIColor.systemPurple.withAlphaComponent(0.75)))
                }
            }
            let wbTeile: [String] = [
                eintrag.stimmung > 0 ? "Stimmung: \(eintrag.stimmung)/5" : nil,
                eintrag.stressLevel > 0 ? "Stress: \(eintrag.stressLevel)/5" : nil,
                eintrag.schlafStunden > 0 ? String(format: "Schlaf: %.1fh", eintrag.schlafStunden) : nil,
                eintrag.morgensteifigkeit > 0 ? "Morgensteifigkeit: \(eintrag.morgensteifigkeit) Min" : nil,
                eintrag.fatigue > 0 ? "Fatigue: \(eintrag.fatigue)/10" : nil,
            ].compactMap { $0 }
            if !wbTeile.isEmpty {
                subZeilen.append((wbTeile.joined(separator: "   "), UIColor.systemBlue.withAlphaComponent(0.7)))
            }
            if let temp = eintrag.wetterTemperatur {
                var wParts = [String(format: "%.0f°C", temp)]
                if let wind = eintrag.wetterWind { wParts.append(String(format: "Wind %.0f km/h", wind)) }
                subZeilen.append(("Wetter: \(wParts.joined(separator: ", "))", .secondaryLabel))
            }
            if eintrag.istHautEintrag && !eintrag.verlauf.isEmpty {
                subZeilen.append(("Verlauf: \(eintrag.verlauf)", .secondaryLabel))
            }
            if !eintrag.notizen.isEmpty {
                subZeilen.append(("Notiz: \(String(eintrag.notizen.prefix(70)))", .secondaryLabel))
            }

            let zeilenH: CGFloat = 20 + CGFloat(subZeilen.count) * 13

            if y + zeilenH > H - rand - 20 {
                fusszeile(ctx: ctx.cgContext, seite: seite)
                ctx.beginPage(); seite += 1
                seitenKopf(ctx: ctx.cgContext, titel: "Einträge (Forts.)", seite: seite)
                y = rand + 52
                tabellenKopf(ctx: ctx.cgContext, y: y, cols: cols, headers: headers)
                y += 26
            }

            let dauer = eintrag.dauerMinuten > 0 ? dauerText(eintrag.dauerMinuten) : "–"
            let staerkeText = eintrag.istHautEintrag ? "Haut" : "\(eintrag.schmerzstaerke)/10"
            let artText = eintrag.istHautEintrag
                ? String(eintrag.hautArt.prefix(18))
                : String(eintrag.schmerzart.prefix(18))
            let ersteStelle = koerperstellen.first ?? ""
            let stelleAnzeige = mehrereStellen ? "\(ersteStelle) +\(koerperstellen.count - 1)" : ersteStelle

            tabellenZeile(ctx: ctx.cgContext, y: y, cols: cols,
                          werte: [fmtKurz(eintrag.datum), staerkeText,
                                  stelleAnzeige, String(eintrag.ausloeser.prefix(24)),
                                  dauer, artText],
                          fett: [false, true, false, false, false, false])
            y += 14

            for sub in subZeilen {
                draw(sub.text, at: CGPoint(x: cols[2], y: y),
                     font: .systemFont(ofSize: 8.5), color: sub.farbe)
                y += 13
            }
            trennlinie(ctx: ctx.cgContext, y: y, alpha: 0.1)
            y += 4
        }

        fusszeile(ctx: ctx.cgContext, seite: seite)
    }

    // MARK: - Medication summary (called from EinnahmeLogView)

    /// Copies SwiftData objects on the main thread, then renders on a background thread.
    @MainActor
    func erstelleMedikamentenZusammenfassung(
        medikamente: [Dauermedikation],
        logs: [EinnahmeLog],
        profil: Benutzerprofil? = nil,
        completion: @escaping @MainActor @Sendable (URL?) -> Void
    ) {
        let patient  = PDFPatientenDaten.aus(profil: profil)
        let meds     = medikamente.map(PDFMedikament.aus)
        let pdfLogs  = logs.sorted { $0.datum > $1.datum }.map(PDFEinnahmeLog.aus)
        let optionen = ExportOptionen(
            zeitraum: .dreissigTage, mitZusammenfassung: false,
            mitMedikamente: true, mitMedikamentDossier: true,
            mitEintraege: false, mitZyklus: false, mitErnaehrung: false, mitRheuma: false
        )
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let url = self.renderPDF(patient: patient, eintraege: [], medikamente: meds,
                                     einnahmeLogs: pdfLogs, midas: [], zyklus: [],
                                     analyse: ZyklusRechner.analyse(eintraege: []),
                                     ernaehrung: [], optionen: optionen)
            Task { @MainActor in completion(url) }
        }
    }

    // MARK: - Notfallausweis PDF

    @MainActor
    func erstelleNotfallausweisAsync(
        profil: Benutzerprofil?,
        diagnosen: [Diagnose],
        allergien: [Allergie],
        medikamente: [Dauermedikation],
        istImmunSuppr: Bool,
        completion: @escaping @MainActor @Sendable (URL?) -> Void
    ) {
        var patient = PDFPatientenDaten.aus(profil: profil)
        let diagnosenTexte = diagnosen.filter { $0.aktiv }.map(\.bezeichnung).filter { !$0.isEmpty }
        let existing = Set(patient.diagnosen)
        patient.diagnosen = patient.diagnosen + diagnosenTexte.filter { !existing.contains($0) }
        let pdfAllergien = allergien.map { PDFNotfallAllergie(substanz: $0.substanz, reaktion: $0.reaktion, schwere: $0.schwere) }
        let pdfMeds = medikamente.filter { $0.aktiv }.map(PDFMedikament.aus)

        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let url = self.renderNotfallausweis(patient: patient, allergien: pdfAllergien,
                                                medikamente: pdfMeds, istImmunSuppr: istImmunSuppr)
            Task { @MainActor in completion(url) }
        }
    }

    private func renderNotfallausweis(
        patient: PDFPatientenDaten,
        allergien: [PDFNotfallAllergie],
        medikamente: [PDFMedikament],
        istImmunSuppr: Bool
    ) -> URL? {
        let dateiname = "Notfallausweis_\(fmt(Date())).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(dateiname)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: W, height: H))
        var renderFehler: Error? = nil
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            do {
                try renderer.writePDF(to: url) { ctx in
                    ctx.beginPage()
                    notfallausweisSeite(ctx: ctx.cgContext, patient: patient, allergien: allergien,
                                        medikamente: medikamente, istImmunSuppr: istImmunSuppr)
                }
            } catch { renderFehler = error }
        }
        return renderFehler == nil ? url : nil
    }

    private func notfallausweisSeite(ctx: CGContext, patient: PDFPatientenDaten,
                                      allergien: [PDFNotfallAllergie],
                                      medikamente: [PDFMedikament],
                                      istImmunSuppr: Bool) {
        let rot = UIColor(red: 0.82, green: 0.08, blue: 0.08, alpha: 1)

        // Red header band
        ctx.setFillColor(rot.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: W, height: 130))

        draw("MEDIZINISCHER NOTFALLAUSWEIS", at: CGPoint(x: rand, y: 18),
             font: .systemFont(ofSize: 17, weight: .bold), color: .white)
        draw("MEDICAL EMERGENCY CARD", at: CGPoint(x: rand, y: 42),
             font: .systemFont(ofSize: 10), color: UIColor.white.withAlphaComponent(0.72))

        var hy: CGFloat = 68
        let name = patient.vollerName
        if !name.isEmpty {
            draw(name, at: CGPoint(x: rand, y: hy),
                 font: .systemFont(ofSize: 15, weight: .semibold), color: .white)
            hy += 22
        }
        var headerParts: [String] = []
        if let geb = patient.geburtsdatum { headerParts.append("Geb. \(fmt(geb))") }
        if !patient.blutgruppe.isEmpty && patient.blutgruppe != "Unbekannt" {
            headerParts.append("Blutgruppe \(patient.blutgruppe)")
        }
        if !patient.versicherung.isEmpty { headerParts.append(patient.versicherung) }
        if !patient.versicherungsNummer.isEmpty { headerParts.append("Nr. \(patient.versicherungsNummer)") }
        if !headerParts.isEmpty {
            draw(headerParts.joined(separator: "   ·   "), at: CGPoint(x: rand, y: hy),
                 font: .systemFont(ofSize: 10), color: UIColor.white.withAlphaComponent(0.85))
        }

        var y: CGFloat = 146

        // Immunsuppressiva warning
        if istImmunSuppr {
            let warn = UIColor(red: 0.88, green: 0.48, blue: 0.0, alpha: 1)
            roundedRect(ctx: ctx, rect: CGRect(x: rand, y: y, width: iw, height: 38),
                        corner: 6, fill: warn.withAlphaComponent(0.08), stroke: warn.withAlphaComponent(0.45))
            draw("⚠  IMMUNSUPPRESSIVA — Kein lebend-attenuierter Impfstoff verabreichen (MMR, Varizellen, Gelbfieber)",
                 at: CGPoint(x: rand + 10, y: y + 13),
                 font: .systemFont(ofSize: 9.5, weight: .semibold), color: warn)
            y += 50
        }

        // Two-column layout: left=Diagnosen, right=Allergien
        let lw = iw * 0.55 - 6
        let rx = rand + iw * 0.55 + 6
        let rw = iw * 0.45 - 6
        var ly = y
        var ry = y

        if !patient.diagnosen.isEmpty {
            draw("DIAGNOSEN", at: CGPoint(x: rand, y: ly),
                 font: .systemFont(ofSize: 9, weight: .bold), color: UIColor(red: 0.55, green: 0.0, blue: 0.0, alpha: 1))
            ly += 14
            for d in patient.diagnosen.prefix(10) {
                drawClamped("• \(d)", at: CGPoint(x: rand + 4, y: ly),
                            font: .systemFont(ofSize: 10), color: .label, maxW: lw - 8)
                ly += 14
            }
            ly += 6
        }

        if !allergien.isEmpty {
            draw("ALLERGIEN / UNVERTRÄGLICHKEITEN", at: CGPoint(x: rx, y: ry),
                 font: .systemFont(ofSize: 9, weight: .bold), color: UIColor(red: 0.72, green: 0.28, blue: 0.0, alpha: 1))
            ry += 14
            for a in allergien.prefix(8) {
                let marker: String
                let farbe: UIColor
                switch a.schwere {
                case "Lebensbedrohlich": marker = " !!!"; farbe = .systemRed
                case "Schwer":          marker = " !!";  farbe = .systemOrange
                case "Mittel":          marker = " !";   farbe = UIColor(red: 0.65, green: 0.45, blue: 0.0, alpha: 1)
                default:                marker = "";     farbe = .label
                }
                drawClamped("• \(a.substanz)\(marker)", at: CGPoint(x: rx + 4, y: ry),
                            font: .systemFont(ofSize: 10, weight: marker.isEmpty ? .regular : .semibold),
                            color: farbe, maxW: rw - 8)
                ry += 14
                if !a.reaktion.isEmpty {
                    drawClamped("  \(a.reaktion)", at: CGPoint(x: rx + 4, y: ry),
                                font: .systemFont(ofSize: 8.5), color: .secondaryLabel, maxW: rw - 8)
                    ry += 12
                }
            }
            ry += 6
        }

        y = max(ly, ry)

        // Dauermedikation
        if !medikamente.isEmpty {
            trennlinie(ctx: ctx, y: y - 2, alpha: 0.18)
            y += 6
            draw("DAUERMEDIKATION", at: CGPoint(x: rand, y: y),
                 font: .systemFont(ofSize: 9, weight: .bold), color: UIColor(red: 0.1, green: 0.38, blue: 0.74, alpha: 1))
            y += 14
            for med in medikamente.prefix(12) {
                var zeile = med.name
                if !med.dosierung.isEmpty { zeile += " \(med.dosierung)" }
                if !med.frequenz.isEmpty { zeile += " – \(med.frequenz)" }
                drawClamped("• \(zeile)", at: CGPoint(x: rand + 4, y: y),
                            font: .systemFont(ofSize: 10), color: .label, maxW: iw - 8)
                y += 14
            }
            y += 6
        }

        // Ärzte
        if !patient.aerzte.isEmpty {
            trennlinie(ctx: ctx, y: y - 2, alpha: 0.18)
            y += 6
            draw("BEHANDELNDE ÄRZTE", at: CGPoint(x: rand, y: y),
                 font: .systemFont(ofSize: 9, weight: .bold), color: blau)
            y += 14
            for arzt in patient.aerzte.prefix(6) {
                var zeile = arzt.name.isEmpty ? arzt.fachgebiet : arzt.name
                if arzt.istHausarzt { zeile += " (Hausarzt)" }
                else if !arzt.fachgebiet.isEmpty { zeile += " (\(arzt.fachgebiet))" }
                if !arzt.telefon.isEmpty { zeile += "  ·  Tel. \(arzt.telefon)" }
                drawClamped("• \(zeile)", at: CGPoint(x: rand + 4, y: y),
                            font: .systemFont(ofSize: 10), color: .label, maxW: iw - 8)
                y += 14
            }
            y += 6
        }

        // Notfallkontakte
        if !patient.notfallkontakte.isEmpty {
            trennlinie(ctx: ctx, y: y - 2, alpha: 0.18)
            y += 6
            draw("NOTFALLKONTAKTE", at: CGPoint(x: rand, y: y),
                 font: .systemFont(ofSize: 9, weight: .bold), color: UIColor(red: 0.0, green: 0.52, blue: 0.22, alpha: 1))
            y += 14
            for k in patient.notfallkontakte.prefix(5) {
                var zeile = k.name
                if !k.beziehung.isEmpty { zeile += " (\(k.beziehung))" }
                if !k.phone.isEmpty { zeile += "  —  Tel. \(k.phone)" }
                drawClamped("• \(zeile)", at: CGPoint(x: rand + 4, y: y),
                            font: .systemFont(ofSize: 10), color: .label, maxW: iw - 8)
                y += 14
            }
        }

        // Footer
        trennlinie(ctx: ctx, y: H - 50, alpha: 0.2)
        draw("Erstellt mit PainDiary am \(fmtLang(Date()))",
             at: CGPoint(x: rand, y: H - 40),
             font: .systemFont(ofSize: 8), color: .tertiaryLabel)
        drawRight("Vertraulich – Nur für medizinisches Personal", rightX: W - rand, y: H - 40,
                  font: .systemFont(ofSize: 8), color: .tertiaryLabel)
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
        ctx.addPath(path.cgPath); ctx.setFillColor(c(fill).cgColor); ctx.fillPath()
        ctx.addPath(path.cgPath); ctx.setStrokeColor(c(stroke).cgColor)
        ctx.setLineWidth(0.5); ctx.strokePath()
        ctx.restoreGState()
    }

    private func trennlinie(ctx: CGContext, y: CGFloat, alpha: CGFloat = 0.3) {
        ctx.setStrokeColor(c(UIColor.separator).withAlphaComponent(alpha).cgColor)
        ctx.setLineWidth(0.5)
        ctx.move(to: CGPoint(x: rand, y: y))
        ctx.addLine(to: CGPoint(x: W - rand, y: y))
        ctx.strokePath()
    }

    private func draw(_ text: String, at point: CGPoint, font: UIFont, color: UIColor) {
        (text as NSString).draw(at: point, withAttributes: [.font: font, .foregroundColor: c(color)])
    }

    private func drawRight(_ text: String, rightX: CGFloat, y: CGFloat, font: UIFont, color: UIColor) {
        let attr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: c(color)]
        let sz = (text as NSString).size(withAttributes: attr)
        (text as NSString).draw(at: CGPoint(x: rightX - sz.width, y: y), withAttributes: attr)
    }

    private func drawClamped(_ text: String, at p: CGPoint, font: UIFont, color: UIColor, maxW: CGFloat) {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        (text as NSString).draw(in: CGRect(x: p.x, y: p.y, width: maxW, height: 14),
                                withAttributes: [.font: font, .foregroundColor: c(color), .paragraphStyle: style])
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

    private func schmerzartHaeufigkeit(eintraege: [PDFEintrag]) -> [(String, Int)] {
        var map: [String: Int] = [:]
        for e in eintraege where !e.schmerzart.isEmpty {
            e.schmerzart.components(separatedBy: ", ")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .forEach { map[$0, default: 0] += 1 }
        }
        return map.sorted { $0.value > $1.value }
    }

    private func begleitHaeufigkeit(eintraege: [PDFEintrag]) -> [(String, Int)] {
        var map: [String: Int] = [:]
        for e in eintraege where !e.begleiterscheinungen.isEmpty {
            e.begleiterscheinungen.components(separatedBy: ", ")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .forEach { map[$0, default: 0] += 1 }
        }
        return map.sorted { $0.value > $1.value }
    }

    private func massnahmenHaeufigkeit(eintraege: [PDFEintrag]) -> [(String, Int)] {
        var map: [String: Int] = [:]
        for e in eintraege where !e.massnahmen.isEmpty {
            e.massnahmen.components(separatedBy: ", ")
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

    private func zyklusphase(fuer datum: Date, analyse: ZyklusAnalyse) -> String? {
        let kal = Calendar.current
        let tag = kal.startOfDay(for: datum)
        guard let start = analyse.zyklusStarts
            .map({ kal.startOfDay(for: $0) })
            .filter({ $0 <= tag })
            .max() else { return nil }

        let zyklusTag = (kal.dateComponents([.day], from: start, to: tag).day ?? 0) + 1
        let periodTage = max(1, Int(analyse.periodendauer))
        let ovTag = max(periodTage + 4, Int(analyse.zykluslaenge) - 14)

        if zyklusTag <= periodTage { return "Menstruation" }
        if zyklusTag >= ovTag - 2 && zyklusTag <= ovTag + 1 { return "Eisprung" }
        if zyklusTag > periodTage && zyklusTag < ovTag - 2 { return "Follikulär" }
        return "Lutealphase"
    }
}
#endif
