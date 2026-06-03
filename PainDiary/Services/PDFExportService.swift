import Foundation
#if os(iOS)
import UIKit

struct ExportOptionen {
    var zeitraum: ExportZeitraum = .dreissigTage
    var mitZusammenfassung: Bool = true
    var mitMedikamente: Bool = true
    var mitEintraege: Bool = true
    var mitMIDAS: Bool = true
}

enum ExportZeitraum: String, CaseIterable {
    case dreissigTage  = "30 Tage"
    case neunzigTage   = "90 Tage"
    case halbJahr      = "180 Tage"
    case alles         = "Alles"

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

class PDFExportService {
    static let shared = PDFExportService()

    private let W: CGFloat = 595
    private let H: CGFloat = 842
    private let rand: CGFloat = 48
    private var iw: CGFloat { W - rand * 2 }

    private let blau = UIColor(red: 0.13, green: 0.40, blue: 0.78, alpha: 1)
    private let hellBlau = UIColor(red: 0.88, green: 0.93, blue: 0.99, alpha: 1)

    func erstellePDF(
        eintraege: [PainEntry],
        medikamente: [Dauermedikation],
        midasBewertungen: [MIDASBewertung],
        profil: Benutzerprofil?,
        optionen: ExportOptionen = ExportOptionen()
    ) -> URL? {
        let gefiltert: [PainEntry]
        if let start = optionen.zeitraum.startDatum() {
            gefiltert = eintraege.filter { $0.datum >= start }.sorted { $0.datum > $1.datum }
        } else {
            gefiltert = eintraege.sorted { $0.datum > $1.datum }
        }

        let dateiname = "Schmerztagebuch_\(fmt(Date())).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(dateiname)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: W, height: H))

        do {
            try renderer.writePDF(to: url) { ctx in
                // Page 1: Cover
                ctx.beginPage()
                deckblatt(ctx: ctx.cgContext, profil: profil, optionen: optionen, anzahl: gefiltert.count)

                // Page 2: Summary
                if optionen.mitZusammenfassung && !gefiltert.isEmpty {
                    ctx.beginPage()
                    zusammenfassung(ctx: ctx.cgContext, eintraege: gefiltert, midas: midasBewertungen, seite: 2)
                }

                // Page 3: Medications
                if optionen.mitMedikamente && !medikamente.isEmpty {
                    ctx.beginPage()
                    medikamenteSeite(ctx: ctx.cgContext, medikamente: medikamente, seite: 3)
                }

                // Page 4+: Entries
                if optionen.mitEintraege && !gefiltert.isEmpty {
                    eintraegeSeiten(ctx: ctx, eintraege: gefiltert)
                }
            }
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Page 1: Cover

    private func deckblatt(ctx: CGContext, profil: Benutzerprofil?, optionen: ExportOptionen, anzahl: Int) {
        // Blue header bar
        ctx.setFillColor(blau.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: W, height: 180))

        // App name
        draw("PainDiary", at: CGPoint(x: rand, y: 52),
             font: .systemFont(ofSize: 28, weight: .bold), color: .white)
        draw("Medizinischer Bericht", at: CGPoint(x: rand, y: 88),
             font: .systemFont(ofSize: 16, weight: .regular), color: UIColor.white.withAlphaComponent(0.85))

        // Date on right
        let datumStr = "Erstellt am \(fmtLang(Date()))"
        drawRight(datumStr, rightX: W - rand, y: 88,
                  font: .systemFont(ofSize: 11), color: UIColor.white.withAlphaComponent(0.75))

        // Patient info box
        let boxY: CGFloat = 210
        roundedRect(ctx: ctx, rect: CGRect(x: rand, y: boxY, width: iw, height: 160),
                    corner: 10, fill: hellBlau, stroke: UIColor(white: 0.8, alpha: 1))

        draw("Patienteninformationen", at: CGPoint(x: rand + 16, y: boxY + 14),
             font: .systemFont(ofSize: 13, weight: .semibold), color: blau)

        var infoY = boxY + 38
        let labelFont = UIFont.systemFont(ofSize: 11, weight: .medium)
        let valueFont = UIFont.systemFont(ofSize: 11)
        let grau = UIColor.secondaryLabel

        if let p = profil {
            let name = "\(p.vorname) \(p.nachname)".trimmingCharacters(in: .whitespaces)
            if !name.isEmpty {
                drawLabel("Name:", value: name, x: rand + 16, y: infoY, labelFont: labelFont, valueFont: valueFont, labelColor: grau)
                infoY += 18
            }
            if let geb = p.geburtsdatum {
                drawLabel("Geburtsdatum:", value: fmt(geb), x: rand + 16, y: infoY, labelFont: labelFont, valueFont: valueFont, labelColor: grau)
                infoY += 18
            }
            if !p.versicherung.isEmpty {
                drawLabel("Krankenkasse:", value: p.versicherung, x: rand + 16, y: infoY, labelFont: labelFont, valueFont: valueFont, labelColor: grau)
                infoY += 18
            }
            if !p.versicherungsNummer.isEmpty {
                drawLabel("Vers.-Nr.:", value: p.versicherungsNummer, x: rand + 16, y: infoY, labelFont: labelFont, valueFont: valueFont, labelColor: grau)
                infoY += 18
            }
        } else {
            draw("Kein Profil erfasst", at: CGPoint(x: rand + 16, y: infoY), font: valueFont, color: grau)
        }

        // Timeframe info box
        let tf = boxY + 185
        roundedRect(ctx: ctx, rect: CGRect(x: rand, y: tf, width: iw, height: 80),
                    corner: 10, fill: UIColor(white: 0.97, alpha: 1), stroke: UIColor(white: 0.85, alpha: 1))
        draw("Berichtszeitraum", at: CGPoint(x: rand + 16, y: tf + 12),
             font: .systemFont(ofSize: 13, weight: .semibold), color: .label)
        draw(optionen.zeitraum.rawValue, at: CGPoint(x: rand + 16, y: tf + 32),
             font: .systemFont(ofSize: 22, weight: .bold), color: blau)
        draw("\(anzahl) Einträge im gewählten Zeitraum", at: CGPoint(x: rand + 16, y: tf + 58),
             font: .systemFont(ofSize: 11), color: grau)

        // Footer
        fusszeile(ctx: ctx, seite: 1)
    }

    // MARK: - Page 2: Summary

    private func zusammenfassung(ctx: CGContext, eintraege: [PainEntry], midas: [MIDASBewertung], seite: Int) {
        seitenKopf(ctx: ctx, titel: "Zusammenfassung", seite: seite)
        var y: CGFloat = rand + 52

        // 4 stat boxes
        let avg = eintraege.map { Double($0.schmerzstaerke) }.reduce(0, +) / Double(eintraege.count)
        let maxVal = eintraege.map(\.schmerzstaerke).max() ?? 0
        let tage = Set(eintraege.map { Calendar.current.startOfDay(for: $0.datum) }).count
        let letzterMidas = midas.sorted { $0.datum > $1.datum }.first

        let boxW = (iw - 12) / 4
        let boxY = y
        statBox(ctx: ctx, x: rand, y: boxY, w: boxW, h: 72, titel: "Ø Schmerzstärke",
                wert: String(format: "%.1f/10", avg), farbe: UIColor.systemOrange)
        statBox(ctx: ctx, x: rand + boxW + 4, y: boxY, w: boxW, h: 72, titel: "Höchstwert",
                wert: "\(maxVal)/10", farbe: UIColor.systemRed)
        statBox(ctx: ctx, x: rand + (boxW + 4) * 2, y: boxY, w: boxW, h: 72, titel: "Tage mit Schmerz",
                wert: "\(tage)", farbe: UIColor.systemBlue)
        statBox(ctx: ctx, x: rand + (boxW + 4) * 3, y: boxY, w: boxW, h: 72, titel: "MIDAS Score",
                wert: letzterMidas.map { "\($0.score)" } ?? "–", farbe: UIColor.systemPurple)
        y = boxY + 88

        // MIDAS details
        if let m = letzterMidas {
            draw("MIDAS: \(m.gradText)  (vom \(fmt(m.datum)))",
                 at: CGPoint(x: rand, y: y),
                 font: .systemFont(ofSize: 11), color: .secondaryLabel)
            y += 22
        }

        // Pain distribution bar chart
        trennlinie(ctx: ctx, y: y)
        y += 14
        draw("Schmerzverteilung", at: CGPoint(x: rand, y: y),
             font: .systemFont(ofSize: 13, weight: .semibold), color: .label)
        y += 20

        let buckets = schmerzBuckets(eintraege: eintraege)
        let maxCount = buckets.values.max() ?? 1
        let barH: CGFloat = 16
        let labelW: CGFloat = 50
        let barMaxW = iw - labelW - 40

        for level in stride(from: 10, through: 0, by: -2) {
            let count = buckets[level] ?? 0
            let barW = count > 0 ? max(4, CGFloat(count) / CGFloat(maxCount) * barMaxW) : 0
            let farbe = schmerzFarbe(level)
            draw("\(level)/10", at: CGPoint(x: rand, y: y + 1),
                 font: .systemFont(ofSize: 9), color: .secondaryLabel)
            if barW > 0 {
                ctx.setFillColor(farbe.withAlphaComponent(0.8).cgColor)
                ctx.fill(CGRect(x: rand + labelW, y: y, width: barW, height: barH - 2))
            }
            draw("\(count)", at: CGPoint(x: rand + labelW + barW + 4, y: y + 1),
                 font: .systemFont(ofSize: 9), color: .secondaryLabel)
            y += barH
        }
        y += 10

        // Top triggers
        trennlinie(ctx: ctx, y: y)
        y += 14
        draw("Häufige Auslöser", at: CGPoint(x: rand, y: y),
             font: .systemFont(ofSize: 13, weight: .semibold), color: .label)
        y += 20

        let ausloeser = ausloeserHaeufigkeit(eintraege: eintraege)
        for (i, (name, count)) in ausloeser.prefix(5).enumerated() {
            draw("\(i+1). \(name)", at: CGPoint(x: rand, y: y),
                 font: .systemFont(ofSize: 11), color: .label)
            drawRight("\(count)×", rightX: W - rand, y: y,
                      font: .systemFont(ofSize: 11), color: .secondaryLabel)
            y += 18
        }

        // Top body locations
        y += 8
        trennlinie(ctx: ctx, y: y)
        y += 14
        draw("Häufigste Schmerzregionen", at: CGPoint(x: rand, y: y),
             font: .systemFont(ofSize: 13, weight: .semibold), color: .label)
        y += 20

        let regionen = regionenHaeufigkeit(eintraege: eintraege)
        for (i, (name, count)) in regionen.prefix(5).enumerated() {
            draw("\(i+1). \(name)", at: CGPoint(x: rand, y: y),
                 font: .systemFont(ofSize: 11), color: .label)
            drawRight("\(count)×", rightX: W - rand, y: y,
                      font: .systemFont(ofSize: 11), color: .secondaryLabel)
            y += 18
        }

        fusszeile(ctx: ctx, seite: seite)
    }

    // MARK: - Page 3: Medications

    private func medikamenteSeite(ctx: CGContext, medikamente: [Dauermedikation], seite: Int) {
        seitenKopf(ctx: ctx, titel: "Medikamente", seite: seite)
        var y: CGFloat = rand + 52

        let aktive = medikamente.filter { $0.aktiv }
        let inaktive = medikamente.filter { !$0.aktiv }

        if !aktive.isEmpty {
            draw("Aktuelle Medikation", at: CGPoint(x: rand, y: y),
                 font: .systemFont(ofSize: 13, weight: .semibold), color: .label)
            y += 20

            // Table header
            let cols: [CGFloat] = [rand, rand + 180, rand + 300, rand + 390]
            tabellenKopf(ctx: ctx, y: y, cols: cols, headers: ["Medikament", "Dosierung", "Frequenz", "Seit"])
            y += 26

            for med in aktive {
                if y > H - rand - 30 { break }
                tabellenZeile(ctx: ctx, y: y, cols: cols,
                              werte: [med.name, med.dosierung, med.frequenz, fmt(med.startDatum)],
                              fett: [true, false, false, false])
                y += 22
                trennlinie(ctx: ctx, y: y - 2, alpha: 0.15)
            }
            y += 14
        }

        if !inaktive.isEmpty {
            trennlinie(ctx: ctx, y: y)
            y += 16
            draw("Frühere Medikation", at: CGPoint(x: rand, y: y),
                 font: .systemFont(ofSize: 13, weight: .semibold), color: .secondaryLabel)
            y += 20

            for med in inaktive {
                if y > H - rand - 20 { break }
                draw("• \(med.name)", at: CGPoint(x: rand + 8, y: y),
                     font: .systemFont(ofSize: 11), color: .secondaryLabel)
                if !med.dosierung.isEmpty {
                    draw(med.dosierung, at: CGPoint(x: rand + 190, y: y),
                         font: .systemFont(ofSize: 11), color: .secondaryLabel)
                }
                y += 18
            }
        }

        fusszeile(ctx: ctx, seite: seite)
    }

    // MARK: - Page 4+: Entries

    private func eintraegeSeiten(ctx: UIGraphicsPDFRendererContext, eintraege: [PainEntry]) {
        var seite = 4
        ctx.beginPage()
        seitenKopf(ctx: ctx.cgContext, titel: "Schmerzeinträge", seite: seite)
        var y: CGFloat = rand + 52

        let cols: [CGFloat] = [rand, rand + 72, rand + 152, rand + 252, rand + 312, rand + 372]
        tabellenKopf(ctx: ctx.cgContext, y: y, cols: cols,
                     headers: ["Datum", "Stärke", "Körperstelle", "Auslöser", "Dauer", "Art"])
        y += 26

        for eintrag in eintraege {
            let zeilenH: CGFloat = 20
            if y + zeilenH > H - rand - 20 {
                fusszeile(ctx: ctx.cgContext, seite: seite)
                ctx.beginPage()
                seite += 1
                seitenKopf(ctx: ctx.cgContext, titel: "Schmerzeinträge (Forts.)", seite: seite)
                y = rand + 52
                tabellenKopf(ctx: ctx.cgContext, y: y, cols: cols,
                             headers: ["Datum", "Stärke", "Körperstelle", "Auslöser", "Dauer", "Art"])
                y += 26
            }

            let dauer = eintrag.dauerMinuten > 0 ? dauerText(eintrag.dauerMinuten) : "–"
            let koerper = eintrag.koerperstelle.components(separatedBy: ", ").first ?? eintrag.koerperstelle
            let ausloeser = String(eintrag.ausloeser.prefix(20))
            let art = String(eintrag.schmerzart.prefix(16))

            tabellenZeile(ctx: ctx.cgContext, y: y, cols: cols,
                          werte: [fmtKurz(eintrag.datum), "\(eintrag.schmerzstaerke)/10",
                                  koerper, ausloeser, dauer, art],
                          fett: [false, true, false, false, false, false])

            // Notizen as sub-row
            if !eintrag.notizen.isEmpty || !eintrag.massnahmen.isEmpty {
                y += zeilenH
                let sub = [eintrag.massnahmen.isEmpty ? "" : "→ \(String(eintrag.massnahmen.prefix(40)))",
                           eintrag.notizen.isEmpty ? "" : "Notiz: \(String(eintrag.notizen.prefix(60)))"]
                    .filter { !$0.isEmpty }.joined(separator: "   ")
                draw(sub, at: CGPoint(x: cols[2], y: y),
                     font: .systemFont(ofSize: 8.5), color: .secondaryLabel)
                y += 14
            } else {
                y += zeilenH
            }

            trennlinie(ctx: ctx.cgContext, y: y - 2, alpha: 0.12)
        }

        fusszeile(ctx: ctx.cgContext, seite: seite)
    }

    // MARK: - Drawing helpers

    private func seitenKopf(ctx: CGContext, titel: String, seite: Int) {
        ctx.setFillColor(blau.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: W, height: 40))
        draw("PainDiary", at: CGPoint(x: rand, y: 11),
             font: .systemFont(ofSize: 12, weight: .semibold), color: UIColor.white.withAlphaComponent(0.7))
        draw(titel, at: CGPoint(x: rand + 70, y: 11),
             font: .systemFont(ofSize: 12, weight: .bold), color: .white)
    }

    private func fusszeile(ctx: CGContext, seite: Int) {
        trennlinie(ctx: ctx, y: H - 32, alpha: 0.2)
        draw("PainDiary – Vertraulicher Patientenbericht", at: CGPoint(x: rand, y: H - 26),
             font: .systemFont(ofSize: 8), color: .tertiaryLabel)
        drawRight("Seite \(seite)", rightX: W - rand, y: H - 26,
                  font: .systemFont(ofSize: 8), color: .tertiaryLabel)
    }

    private func tabellenKopf(ctx: CGContext, y: CGFloat, cols: [CGFloat], headers: [String]) {
        ctx.setFillColor(hellBlau.cgColor)
        ctx.fill(CGRect(x: rand, y: y, width: iw, height: 20))
        for (i, header) in headers.enumerated() {
            let x = cols[i]
            draw(header, at: CGPoint(x: x + 4, y: y + 4),
                 font: .systemFont(ofSize: 9, weight: .semibold), color: blau)
        }
    }

    private func tabellenZeile(ctx: CGContext, y: CGFloat, cols: [CGFloat], werte: [String], fett: [Bool]) {
        for (i, wert) in werte.enumerated() {
            let x = cols[i]
            let maxW: CGFloat = i + 1 < cols.count ? cols[i + 1] - x - 6 : W - rand - x - 6
            let font: UIFont = (i < fett.count && fett[i]) ? .systemFont(ofSize: 10, weight: .medium) : .systemFont(ofSize: 10)
            drawClamped(wert, at: CGPoint(x: x + 4, y: y + 3), font: font, color: .label, maxW: maxW)
        }
    }

    private func statBox(ctx: CGContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat,
                         titel: String, wert: String, farbe: UIColor) {
        roundedRect(ctx: ctx, rect: CGRect(x: x, y: y, width: w, height: h),
                    corner: 8, fill: farbe.withAlphaComponent(0.1), stroke: farbe.withAlphaComponent(0.3))
        draw(wert, at: CGPoint(x: x + 8, y: y + 10),
             font: .systemFont(ofSize: 18, weight: .bold), color: farbe)
        draw(titel, at: CGPoint(x: x + 8, y: y + 36),
             font: .systemFont(ofSize: 8), color: .secondaryLabel)
    }

    private func roundedRect(ctx: CGContext, rect: CGRect, corner: CGFloat, fill: UIColor, stroke: UIColor) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: corner)
        ctx.saveGState()
        ctx.addPath(path.cgPath)
        ctx.setFillColor(fill.cgColor)
        ctx.fillPath()
        ctx.addPath(path.cgPath)
        ctx.setStrokeColor(stroke.cgColor)
        ctx.setLineWidth(0.5)
        ctx.strokePath()
        ctx.restoreGState()
    }

    private func trennlinie(ctx: CGContext, y: CGFloat, alpha: CGFloat = 0.35) {
        ctx.setStrokeColor(UIColor.separator.withAlphaComponent(alpha).cgColor)
        ctx.setLineWidth(0.5)
        ctx.move(to: CGPoint(x: rand, y: y))
        ctx.addLine(to: CGPoint(x: W - rand, y: y))
        ctx.strokePath()
    }

    private func draw(_ text: String, at point: CGPoint, font: UIFont, color: UIColor) {
        let attr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        text.draw(at: point, withAttributes: attr)
    }

    private func drawRight(_ text: String, rightX: CGFloat, y: CGFloat, font: UIFont, color: UIColor) {
        let attr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let size = (text as NSString).size(withAttributes: attr)
        text.draw(at: CGPoint(x: rightX - size.width, y: y), withAttributes: attr)
    }

    private func drawClamped(_ text: String, at point: CGPoint, font: UIFont, color: UIColor, maxW: CGFloat) {
        let attr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let rect = CGRect(x: point.x, y: point.y, width: maxW, height: 14)
        (text as NSString).drawWithEllipsis(in: rect, attrs: attr)
    }

    private func drawLabel(_ label: String, value: String, x: CGFloat, y: CGFloat,
                           labelFont: UIFont, valueFont: UIFont, labelColor: UIColor) {
        let la: [NSAttributedString.Key: Any] = [.font: labelFont, .foregroundColor: labelColor]
        label.draw(at: CGPoint(x: x, y: y), withAttributes: la)
        let lw = (label as NSString).size(withAttributes: la).width
        let va: [NSAttributedString.Key: Any] = [.font: valueFont, .foregroundColor: UIColor.label]
        value.draw(at: CGPoint(x: x + lw + 6, y: y), withAttributes: va)
    }

    // MARK: - Data helpers

    private func schmerzBuckets(eintraege: [PainEntry]) -> [Int: Int] {
        var result: [Int: Int] = [:]
        for e in eintraege { result[e.schmerzstaerke, default: 0] += 1 }
        return result
    }

    private func ausloeserHaeufigkeit(eintraege: [PainEntry]) -> [(String, Int)] {
        var map: [String: Int] = [:]
        for e in eintraege where !e.ausloeser.isEmpty {
            e.ausloeser.components(separatedBy: ", ").forEach { map[$0.trimmingCharacters(in: .whitespaces), default: 0] += 1 }
        }
        return map.sorted { $0.value > $1.value }
    }

    private func regionenHaeufigkeit(eintraege: [PainEntry]) -> [(String, Int)] {
        var map: [String: Int] = [:]
        for e in eintraege where !e.koerperstelle.isEmpty {
            e.koerperstelle.components(separatedBy: ", ").forEach { map[$0.trimmingCharacters(in: .whitespaces), default: 0] += 1 }
        }
        return map.sorted { $0.value > $1.value }
    }

    private func schmerzFarbe(_ level: Int) -> UIColor {
        switch level {
        case 0...2: return UIColor.systemGreen
        case 3...4: return UIColor.systemYellow
        case 5...6: return UIColor.systemOrange
        case 7...8: return UIColor.systemRed
        default:    return UIColor(red: 0.6, green: 0, blue: 0, alpha: 1)
        }
    }

    private func dauerText(_ minuten: Int) -> String {
        if minuten < 60 { return "\(minuten) min" }
        let h = minuten / 60; let m = minuten % 60
        return m == 0 ? "\(h) h" : "\(h)h \(m)m"
    }

    private func fmt(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "dd.MM.yyyy"; return f.string(from: date)
    }

    private func fmtKurz(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "dd.MM.yy"; return f.string(from: date)
    }

    private func fmtLang(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "de_CH")
        f.dateStyle = .long; return f.string(from: date)
    }
}

private extension NSString {
    func drawWithEllipsis(in rect: CGRect, attrs: [NSAttributedString.Key: Any]) {
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.lineBreakMode = .byTruncatingTail
        var a = attrs
        a[.paragraphStyle] = paraStyle
        draw(in: rect, withAttributes: a)
    }
}
#endif
