import Foundation
#if os(iOS)
import UIKit

class PDFExportService {
    static let shared = PDFExportService()

    func erstellePDF(eintraege: [PainEntry], patientenName: String = "") -> URL? {
        let dateiname = "Schmerztagebuch_\(datumsString(Date())).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(dateiname)

        let seitenBreite: CGFloat = 595
        let seitenHoehe: CGFloat = 842
        let rand: CGFloat = 48
        let inhaltsBreite = seitenBreite - rand * 2

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: seitenBreite, height: seitenHoehe))

        do {
            try renderer.writePDF(to: url) { ctx in
                var y: CGFloat = rand

                func neueSeiteFallsNoetig(benoetigt: CGFloat) {
                    if y + benoetigt > seitenHoehe - rand {
                        ctx.beginPage()
                        y = rand
                    }
                }

                ctx.beginPage()

                // Header
                let headerAttr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                    .foregroundColor: UIColor.label
                ]
                "Schmerztagebuch".draw(at: CGPoint(x: rand, y: y), withAttributes: headerAttr)
                y += 30

                if !patientenName.isEmpty {
                    let nameAttr: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 13),
                        .foregroundColor: UIColor.secondaryLabel
                    ]
                    "Patient: \(patientenName)".draw(at: CGPoint(x: rand, y: y), withAttributes: nameAttr)
                    y += 20
                }

                let metaAttr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11),
                    .foregroundColor: UIColor.secondaryLabel
                ]
                let erstelltText = "Erstellt: \(datumsString(Date()))   Einträge: \(eintraege.count)"
                erstelltText.draw(at: CGPoint(x: rand, y: y), withAttributes: metaAttr)
                y += 24

                trennlinie(ctx: ctx.cgContext, x: rand, y: y, breite: inhaltsBreite)
                y += 16

                // Statistiken
                if !eintraege.isEmpty {
                    let avg = Double(eintraege.map(\.schmerzstaerke).reduce(0, +)) / Double(eintraege.count)
                    let max = eintraege.map(\.schmerzstaerke).max() ?? 0
                    let statTitel: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 13, weight: .semibold)
                    ]
                    "Zusammenfassung".draw(at: CGPoint(x: rand, y: y), withAttributes: statTitel)
                    y += 20
                    let statAttr: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 11),
                        .foregroundColor: UIColor.secondaryLabel
                    ]
                    "Ø Schmerzstärke: \(String(format: "%.1f", avg)) / 10    Höchstwert: \(max) / 10"
                        .draw(at: CGPoint(x: rand, y: y), withAttributes: statAttr)
                    y += 24
                    trennlinie(ctx: ctx.cgContext, x: rand, y: y, breite: inhaltsBreite)
                    y += 16
                }

                // Einträge
                let eintrTitel: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 13, weight: .semibold)
                ]
                "Einträge".draw(at: CGPoint(x: rand, y: y), withAttributes: eintrTitel)
                y += 20

                let eintrDatum: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12, weight: .medium)
                ]
                let eintrDetail: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11),
                    .foregroundColor: UIColor.secondaryLabel
                ]

                for eintrag in eintraege {
                    neueSeiteFallsNoetig(benoetigt: 80)

                    // Datum + Schmerzstärke
                    let datumStr = "\(vollDatumsString(eintrag.datum))  —  Stärke \(eintrag.schmerzstaerke)/10"
                    datumStr.draw(at: CGPoint(x: rand, y: y), withAttributes: eintrDatum)
                    y += 18

                    // Körperstelle + Schmerzart
                    var zeile2 = ""
                    if !eintrag.koerperstelle.isEmpty { zeile2 += eintrag.koerperstelle }
                    if !eintrag.schmerzart.isEmpty { zeile2 += zeile2.isEmpty ? eintrag.schmerzart : "  ·  \(eintrag.schmerzart)" }
                    if !zeile2.isEmpty {
                        zeile2.draw(at: CGPoint(x: rand + 8, y: y), withAttributes: eintrDetail)
                        y += 16
                    }

                    // Auslöser
                    if !eintrag.ausloeser.isEmpty {
                        "Auslöser: \(eintrag.ausloeser)".draw(at: CGPoint(x: rand + 8, y: y), withAttributes: eintrDetail)
                        y += 16
                    }

                    // Massnahmen
                    if !eintrag.massnahmen.isEmpty {
                        "Massnahmen: \(eintrag.massnahmen)".draw(at: CGPoint(x: rand + 8, y: y), withAttributes: eintrDetail)
                        y += 16
                    }

                    // Wetter
                    if let code = eintrag.wetterCode, let temp = eintrag.wetterTemperatur {
                        "Wetter: \(WetterSnapshot.beschreibungFuerCode(code)), \(String(format: "%.0f°C", temp))"
                            .draw(at: CGPoint(x: rand + 8, y: y), withAttributes: eintrDetail)
                        y += 16
                    }

                    // Notizen
                    if !eintrag.notizen.isEmpty {
                        let kurzNotiz = eintrag.notizen.count > 80 ? String(eintrag.notizen.prefix(80)) + "…" : eintrag.notizen
                        "Notizen: \(kurzNotiz)".draw(at: CGPoint(x: rand + 8, y: y), withAttributes: eintrDetail)
                        y += 16
                    }

                    y += 8
                    trennlinie(ctx: ctx.cgContext, x: rand, y: y, breite: inhaltsBreite, alpha: 0.2)
                    y += 12
                }
            }
            return url
        } catch {
            return nil
        }
    }

    private func trennlinie(ctx: CGContext, x: CGFloat, y: CGFloat, breite: CGFloat, alpha: CGFloat = 0.4) {
        ctx.setStrokeColor(UIColor.separator.withAlphaComponent(alpha).cgColor)
        ctx.setLineWidth(0.5)
        ctx.move(to: CGPoint(x: x, y: y))
        ctx.addLine(to: CGPoint(x: x + breite, y: y))
        ctx.strokePath()
    }

    private func datumsString(_ datum: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy"
        return f.string(from: datum)
    }

    private func vollDatumsString(_ datum: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy HH:mm"
        return f.string(from: datum)
    }
}
#endif
