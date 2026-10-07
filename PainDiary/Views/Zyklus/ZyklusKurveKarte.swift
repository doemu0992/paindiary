import SwiftUI
import Charts

/// Zykluskurve: Basaltemperatur und Ovulationstests pro Zyklustag, mit markiertem Eisprung.
struct ZyklusKurveKarte: View {
    let analyse: ZyklusAnalyse
    let proTag: [Date: ZyklusTagesSicht]

    @State private var auswahl = 0   // 0 = aktueller Zyklus, 1 = vorheriger …

    private var kal: Calendar { Calendar.current }

    private var zyklen: [ZyklusInfo] { Array(analyse.zyklen.reversed().prefix(6)) }

    private struct Punkt: Identifiable {
        let id: Int
        let tag: Int
        let wert: Double
    }

    private struct LHPunkt: Identifiable {
        let id: Int
        let tag: Int
        let positiv: Bool
    }

    private func tage(_ info: ZyklusInfo) -> Int {
        let ende = info.naechsterStart
            ?? kal.date(byAdding: .day, value: info.erwarteteLaenge, to: info.start) ?? info.start
        return max((kal.dateComponents([.day], from: info.start, to: ende).day ?? 28), 1)
    }

    private func zyklusTag(_ datum: Date, _ info: ZyklusInfo) -> Int {
        (kal.dateComponents([.day], from: info.start, to: kal.startOfDay(for: datum)).day ?? 0) + 1
    }

    private func daten(_ info: ZyklusInfo) -> (bbt: [Punkt], lh: [LHPunkt]) {
        var bbt: [Punkt] = []
        var lh: [LHPunkt] = []
        for n in 1...tage(info) {
            guard let d = kal.date(byAdding: .day, value: n - 1, to: info.start),
                  let t = proTag[kal.startOfDay(for: d)] else { continue }
            if ZyklusGrenzen.bbtBereich.contains(t.basaltemperatur) {
                bbt.append(Punkt(id: n, tag: n, wert: t.basaltemperatur))
            }
            if t.lhTest == .positiv || t.lhTest == .negativ {
                lh.append(LHPunkt(id: n, tag: n, positiv: t.lhTest == .positiv))
            }
        }
        return (bbt, lh)
    }

    var body: some View {
        if !zyklen.isEmpty {
            let info = zyklen[min(auswahl, zyklen.count - 1)]
            let d = daten(info)
            let laenge = tage(info)
            let ovTag = info.eisprung.map { zyklusTag($0, info) }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Zykluskurve", systemImage: "waveform.path.ecg")
                        .font(.headline).foregroundStyle(.pink)
                    Spacer()
                    InfoButton(titel: "Zykluskurve",
                               text: "Basaltemperatur (Linie) und Ovulationstests (Sterne = positiv, Punkte = negativ) pro Zyklustag. Nach dem Eisprung steigt die Temperatur um etwa 0,2–0,5 °C und bleibt erhöht. Die senkrechte Linie zeigt den Eisprung – durchgezogen, wenn er bestätigt ist (Temperatur oder von dir), gestrichelt, wenn er nur geschätzt oder per LH-Test bzw. Schleim bestimmt ist.")
                }

                if zyklen.count > 1 {
                    Picker("Zyklus", selection: $auswahl) {
                        ForEach(Array(zyklen.enumerated()), id: \.offset) { i, z in
                            Text(i == 0 && z.naechsterStart == nil ? "Aktuell"
                                 : z.start.formatted(.dateTime.day().month(.abbreviated).locale(ZyklusLocale.de)))
                                .tag(i)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.pink)
                }

                if d.bbt.count < 2 && d.lh.isEmpty {
                    Text("In diesem Zyklus sind noch keine Temperaturen oder Ovulationstests erfasst.")
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
                        .multilineTextAlignment(.center)
                } else {
                    let werte = d.bbt.map(\.wert)
                    let minY = (werte.min() ?? 36.0) - 0.25
                    let maxY = (werte.max() ?? 37.0) + 0.25
                    Chart {
                        ForEach(d.bbt) { p in
                            LineMark(x: .value("Zyklustag", p.tag), y: .value("°C", p.wert))
                                .foregroundStyle(Color.pink)
                                .interpolationMethod(.monotone)
                            PointMark(x: .value("Zyklustag", p.tag), y: .value("°C", p.wert))
                                .foregroundStyle(Color.pink)
                                .symbolSize(22)
                        }
                        if let ov = ovTag, ov >= 1, ov <= laenge {
                            RuleMark(x: .value("Eisprung", ov))
                                .foregroundStyle(ZyklusFarbe.eisprung)
                                .lineStyle(StrokeStyle(lineWidth: 1.5,
                                                       dash: info.eisprungQuelle.istBestaetigt ? [] : [4, 3]))
                                .annotation(position: .top, alignment: .center) {
                                    Text("Eisprung").font(.caption2.bold()).foregroundStyle(ZyklusFarbe.eisprung)
                                }
                        }
                        ForEach(d.lh) { l in
                            PointMark(x: .value("Zyklustag", l.tag), y: .value("°C", minY + 0.08))
                                .symbol(l.positiv ? .diamond : .circle)
                                .foregroundStyle(l.positiv ? ZyklusFarbe.eisprung : Color.secondary.opacity(0.7))
                                .symbolSize(l.positiv ? 70 : 24)
                        }
                    }
                    .chartYScale(domain: minY...maxY)
                    .chartXScale(domain: 1...max(laenge, 2))
                    .chartYAxis {
                        AxisMarks(position: .leading) { v in
                            AxisGridLine()
                            AxisValueLabel {
                                if let w = v.as(Double.self) { Text(String(format: "%.1f", w)).font(.caption2) }
                            }
                        }
                    }
                    .frame(height: 190)
                    .clipped()

                    HStack(spacing: 14) {
                        legende(Color.pink, "Temperatur")
                        legende(ZyklusFarbe.eisprung, "LH positiv")
                        legende(Color.secondary, "LH negativ")
                        Spacer(minLength: 0)
                    }
                    Text("\(info.eisprungQuelle.istBestaetigt ? "Eisprung bestätigt" : "Eisprung geschätzt") (\(info.eisprungQuelle.titel))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(padding: 0)
        }
    }

    private func legende(_ farbe: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(farbe).frame(width: 7, height: 7)
            Text(text).font(.caption2).foregroundStyle(.secondary)
        }
    }
}
