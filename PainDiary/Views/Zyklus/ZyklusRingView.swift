import SwiftUI

/// Interaktiver Phasen-Ring des aktuellen Zyklus: ein Segment pro Zyklustag.
/// Antippen/Ziehen wählt einen Tag, die Mitte zeigt Zyklustag, Phase und Datum.
struct ZyklusRingView: View {
    let analyse: ZyklusAnalyse
    let untertitel: String
    @Binding var auswahl: Int?

    private var kal: Calendar { Calendar.current }

    private var aktuellerStart: Date? { analyse.zyklen.last?.start }

    private var heuteTag: Int { analyse.aktuellerZyklustag ?? 1 }

    private var anzahlTage: Int {
        let laenge = max(Int(analyse.adaptierteZykluslaenge.rounded()), 21)
        return min(max(laenge, heuteTag), 60)
    }

    private func datum(fuerTag n: Int) -> Date? {
        guard let start = aktuellerStart else { return nil }
        return kal.date(byAdding: .day, value: n - 1, to: start)
    }

    private func phase(fuerTag n: Int) -> ZyklusRechner.Zyklusphase? {
        guard let d = datum(fuerTag: n) else { return nil }
        return ZyklusRechner.phase(for: d, analyse: analyse, kalender: kal)
    }

    private func farbe(fuerTag n: Int) -> Color {
        guard let p = phase(fuerTag: n) else { return ZyklusFarbe.luteal }
        return ZyklusFarbe.farbe(p)
    }

    private func istFruchtbar(_ n: Int) -> Bool {
        guard let d = datum(fuerTag: n) else { return false }
        return analyse.fruchtbareTageSet.contains(kal.startOfDay(for: d))
    }

    private func istEisprung(_ n: Int) -> Bool {
        guard let d = datum(fuerTag: n) else { return false }
        return analyse.ovulationsTageSet.contains(kal.startOfDay(for: d))
    }

    private func position(tag n: Int, seite: CGFloat, radius: CGFloat) -> CGPoint {
        let winkel = (Double(n) - 0.5) / Double(anzahlTage) * 2 * Double.pi - Double.pi / 2
        return CGPoint(x: seite / 2 + radius * CGFloat(cos(winkel)),
                       y: seite / 2 + radius * CGFloat(sin(winkel)))
    }

    private func tag(an punkt: CGPoint, seite: CGFloat) -> Int {
        let dx = Double(punkt.x - seite / 2)
        let dy = Double(punkt.y - seite / 2)
        var winkel = atan2(dx, -dy)      // 0 = oben, im Uhrzeigersinn positiv
        if winkel < 0 { winkel += 2 * Double.pi }
        let n = Int(winkel / (2 * Double.pi) * Double(anzahlTage)) + 1
        return min(max(n, 1), anzahlTage)
    }

    var body: some View {
        GeometryReader { geo in
            let seite = min(geo.size.width, geo.size.height)
            let dicke = seite * 0.085
            let anzahl = anzahlTage

            ZStack {
                // Phasen-Segmente
                ForEach(1...anzahl, id: \.self) { n in
                    Circle()
                        .trim(from: (Double(n - 1) + 0.07) / Double(anzahl),
                              to: (Double(n) - 0.07) / Double(anzahl))
                        .stroke(farbe(fuerTag: n).opacity(n < heuteTag ? 0.55 : 1.0),
                                style: StrokeStyle(lineWidth: dicke, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                        .padding(dicke / 2)
                }

                // Fruchtbares Fenster (innerer Ring)
                ForEach(1...anzahl, id: \.self) { n in
                    if istFruchtbar(n) {
                        Circle()
                            .trim(from: (Double(n - 1) + 0.04) / Double(anzahl),
                                  to: (Double(n) - 0.04) / Double(anzahl))
                            .stroke(ZyklusFarbe.fruchtbar,
                                    style: StrokeStyle(lineWidth: dicke * 0.42, lineCap: .butt))
                            .rotationEffect(.degrees(-90))
                            .padding(dicke * 1.45)
                    }
                }

                // Eisprung-Marker
                ForEach(1...anzahl, id: \.self) { n in
                    if istEisprung(n) {
                        Circle()
                            .fill(ZyklusFarbe.eisprung)
                            .frame(width: dicke * 0.7, height: dicke * 0.7)
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                            .shadow(color: ZyklusFarbe.eisprung.opacity(0.5), radius: 5)
                            .position(position(tag: n, seite: seite, radius: (seite - dicke) / 2))
                    }
                }

                // Auswahl
                if let a = auswahl, a >= 1, a <= anzahl {
                    Circle()
                        .stroke(Color.primary, lineWidth: 2)
                        .frame(width: dicke * 1.1, height: dicke * 1.1)
                        .position(position(tag: a, seite: seite, radius: (seite - dicke) / 2))
                }

                // Heute
                Circle()
                    .fill(.white)
                    .frame(width: dicke * 0.9, height: dicke * 0.9)
                    .overlay(Circle().stroke(Color.pink, lineWidth: 3))
                    .shadow(color: Color.pink.opacity(0.45), radius: 6)
                    .position(position(tag: min(heuteTag, anzahl), seite: seite, radius: (seite - dicke) / 2))

                // Touch-Fläche
                Color.clear
                    .contentShape(Circle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { wert in
                                let n = tag(an: wert.location, seite: seite)
                                if auswahl != n { auswahl = n }
                            }
                    )

                mitte(seite: seite)
                    .frame(width: seite * 0.52)
                    .onTapGesture { auswahl = nil }
            }
            .frame(width: seite, height: seite)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Zyklus-Ring")
        .accessibilityValue(barrierefreierText)
        .accessibilityAdjustableAction { richtung in
            let aktuell = auswahl ?? heuteTag
            switch richtung {
            case .increment: auswahl = min(aktuell + 1, anzahlTage)
            case .decrement: auswahl = max(aktuell - 1, 1)
            @unknown default: break
            }
        }
    }

    private var barrierefreierText: String {
        let n = auswahl ?? heuteTag
        let phaseText = phase(fuerTag: n)?.rawValue ?? "unbekannt"
        return "Zyklustag \(n), \(phaseText). \(auswahl == nil ? untertitel : "")"
    }

    @ViewBuilder
    private func mitte(seite: CGFloat) -> some View {
        let n = auswahl ?? heuteTag
        let p = phase(fuerTag: n)
        VStack(spacing: 2) {
            if auswahl != nil, let d = datum(fuerTag: n) {
                Text(d, format: .dateTime.weekday(.abbreviated).day().month())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            } else {
                Text("ZYKLUSTAG")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text("\(n)")
                .font(.system(size: seite * 0.19, weight: .bold, design: .rounded))
                .foregroundStyle(Color.pink)
                .minimumScaleFactor(0.6)
            Text(p?.rawValue ?? "–")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(p.map { ZyklusFarbe.farbe($0) } ?? Color.secondary)
            Text(auswahl == nil ? untertitel : (n > heuteTag ? "Prognose" : " "))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
    }
}
