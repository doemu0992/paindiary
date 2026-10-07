import SwiftUI
import Charts

/// „Verlauf"-Tab: Kennzahlen, Hinweise und die Liste aller erkannten Zyklen.
struct ZyklusVerlaufView: View {
    let analyse: ZyklusAnalyse
    var proTag: [Date: ZyklusTagesSicht] = [:]

    var body: some View {
        VStack(spacing: 16) {
            statistikKarte
            if !analyse.hinweise.isEmpty { hinweiseKarte }
            ZyklusKurveKarte(analyse: analyse, proTag: proTag)
            if laengenDaten.count >= 2 { laengenKarte }
            zyklenKarte
        }
    }

    // MARK: - Kennzahlen

    private var statistikKarte: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Deine Zyklen", systemImage: "chart.bar.fill")
                .font(.headline).foregroundStyle(.pink)
            HStack(spacing: 0) {
                statPill(analyse.gueltigeZyklen > 0 ? "\(Int(analyse.medianZykluslaenge.rounded())) T" : "–",
                         label: "Zyklus (Median)", farbe: .pink)
                Divider().frame(height: 40)
                statPill(analyse.gueltigeZyklen >= 2 ? "± \(String(format: "%.1f", analyse.variation))" : "–",
                         label: "Streuung (Tage)", farbe: .orange)
                Divider().frame(height: 40)
                statPill("\(analyse.lutealphase) T",
                         label: analyse.lutealphaseGelernt ? "Lutealphase (gelernt)" : "Lutealphase (Standard)",
                         farbe: ZyklusFarbe.praemenstruell)
            }
            Divider()
            HStack(spacing: 8) {
                badge(analyse.regelmaessigkeit.titel,
                      farbe: analyse.regelmaessigkeit == .unregelmaessig ? .orange : .teal)
                badge(analyse.datenQualitaet.titel, farbe: .secondary)
                badge("\(analyse.gueltigeZyklen) Zyklen", farbe: .secondary)
                Spacer(minLength: 0)
            }
            Text(prognoseText)
                .font(.caption2).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .zyklusGlas()
    }

    private var prognoseText: String {
        var text = "Prognose-Methode: \(analyse.prognoseMethode)"
        if let f = analyse.prognoseFehler {
            text += " · typische Abweichung ± \(String(format: "%.1f", f)) Tage (an deinen letzten Zyklen gemessen)"
        } else {
            text += " · Genauigkeit wird ab 4 Zyklen gemessen"
        }
        if analyse.evidenzVerankert {
            text += ". Periode neu berechnet aus Eisprung-Beleg im laufenden Zyklus"
        }
        return text
    }

    private var hinweiseKarte: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Hinweise", systemImage: "info.circle.fill")
                .font(.headline).foregroundStyle(.orange)
            ForEach(analyse.hinweise, id: \.self) { text in
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .zyklusGlas()
    }

    // MARK: - Zykluslängen-Diagramm

    private var laengenDaten: [ZyklusInfo] {
        Array(analyse.zyklen.filter { $0.laenge != nil }.suffix(12))
    }

    private var laengenKarte: some View {
        let daten = laengenDaten
        let werte = daten.compactMap { $0.laenge }
        let minY = max((werte.min() ?? 21) - 4, 0)
        let maxY = (werte.max() ?? 35) + 4

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Zykluslänge", systemImage: "chart.bar.fill")
                    .font(.headline).foregroundStyle(.pink)
                Spacer()
                InfoButton(titel: "Zykluslänge",
                           text: "Länge deiner letzten Zyklen in Tagen (Beginn einer Periode bis zum Tag vor der nächsten). Die gestrichelte Linie ist der Median. Graue Balken zählen nicht in die Statistik (unplausible Länge unter 15 oder über 90 Tage, oder starker Ausreißer). Als normal gilt eine Länge von 24–38 Tagen; eine Schwankung von bis zu 9 Tagen gilt als regelmäßig.")
            }
            Chart {
                ForEach(Array(daten.enumerated()), id: \.element.id) { index, info in
                    // yStart statt Baseline 0: Balken bleiben innerhalb der Y-Achse (kein Überlaufen in die nächste Karte)
                    // RectangleMark mit expliziten Grenzen: BarMark(.ratio) hat auf numerischer X-Achse Breite 0
                    RectangleMark(
                        xStart: .value("Von", Double(index) - 0.35),
                        xEnd: .value("Bis", Double(index) + 0.35),
                        yStart: .value("Min", minY),
                        yEnd: .value("Tage", info.laenge ?? 0)
                    )
                    .foregroundStyle(info.fuerStatistikGueltig ? Color.pink.gradient : Color.secondary.opacity(0.4).gradient)
                    .cornerRadius(4)
                    .annotation(position: .top) {
                        Text("\(info.laenge ?? 0)").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                if analyse.gueltigeZyklen > 0 {
                    RuleMark(y: .value("Median", analyse.medianZykluslaenge))
                        .foregroundStyle(Color.secondary.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                }
            }
            .chartYScale(domain: minY...maxY)
            .chartXScale(domain: -1...daten.count)
            .chartXAxis {
                AxisMarks(values: Array(0..<daten.count)) { value in
                    AxisValueLabel {
                        if let i = value.as(Int.self), daten.indices.contains(i) {
                            Text(daten[i].start.formatted(.dateTime.day().month(.defaultDigits).locale(ZyklusLocale.de)))
                                .font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 170)
            .clipped()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .zyklusGlas()
    }

    // MARK: - Zyklen

    private var zyklenKarte: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("Erkannte Zyklen", systemImage: "calendar")
                .font(.headline).foregroundStyle(.pink)
                .padding(.bottom, 10)
            let zyklen = Array(analyse.zyklen.reversed())
            ForEach(Array(zyklen.enumerated()), id: \.element.id) { index, info in
                if index > 0 { Divider().padding(.vertical, 8) }
                zeile(info)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .zyklusGlas()
    }

    private func zeile(_ info: ZyklusInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(zeitraum(info)).font(.subheadline.bold())
                Spacer()
                if let l = info.laenge {
                    Text("\(l) Tage")
                        .font(.caption.bold())
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background((info.fuerStatistikGueltig ? Color.pink : Color.secondary).opacity(0.15),
                                    in: Capsule())
                        .foregroundStyle(info.fuerStatistikGueltig ? Color.pink : Color.secondary)
                } else {
                    Text("läuft")
                        .font(.caption.bold())
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.teal.opacity(0.15), in: Capsule())
                        .foregroundStyle(Color.teal)
                }
            }
            Text(details(info))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if info.laenge != nil && !info.fuerStatistikGueltig {
                Text("Nicht in der Statistik (unplausible Länge oder Ausreißer)")
                    .font(.caption2).foregroundStyle(.orange)
            }
        }
    }

    private func zeitraum(_ info: ZyklusInfo) -> String {
        let von = info.start.formatted(.dateTime.day().month(.abbreviated).locale(ZyklusLocale.de))
        if let ende = info.naechsterStart,
           let letzter = Calendar.current.date(byAdding: .day, value: -1, to: ende) {
            return "\(von) – \(letzter.formatted(.dateTime.day().month(.abbreviated).locale(ZyklusLocale.de)))"
        }
        return "seit \(von)"
    }

    private func details(_ info: ZyklusInfo) -> String {
        var teile = ["Periode \(info.periodenTage) T"]
        if !info.lhPositiveTage.isEmpty {
            let tage = info.lhPositiveTage
                .map { $0.formatted(.dateTime.day().month(.abbreviated).locale(ZyklusLocale.de)) }
                .joined(separator: ", ")
            teile.append("★ LH positiv \(tage)")
        }
        if let ov = info.eisprung {
            teile.append("Eisprung \(ov.formatted(.dateTime.day().month(.abbreviated).locale(ZyklusLocale.de))) (\(info.eisprungQuelle.titel))")
        }
        if let l = info.lutealLaenge, info.eisprungQuelle != .kalender {
            teile.append("Lutealphase \(l) T")
        }
        return teile.joined(separator: " · ")
    }

    // MARK: - Helfer

    private func statPill(_ wert: String, label: String, farbe: Color) -> some View {
        VStack(spacing: 4) {
            Text(wert).font(.title3.bold()).foregroundStyle(farbe)
            Text(label).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func badge(_ text: String, farbe: Color) -> some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(farbe.opacity(0.15), in: Capsule())
            .foregroundStyle(farbe)
    }
}
