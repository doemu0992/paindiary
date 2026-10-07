import SwiftUI

/// Monatskalender mit durchgehenden Perioden-/Fruchtbarkeits-Bändern (44-pt-Felder).
struct ZyklusKalenderView: View {
    let monat: Date
    let eintraegeProTag: [Date: ZyklusTagesSicht]
    let analyse: ZyklusAnalyse
    let zeigePrognosen: Bool
    let ausgewaehlterTag: Date?
    var onVorheriger: () -> Void
    var onNaechster: () -> Void
    let onTap: (Date) -> Void

    private var kal: Calendar { Calendar.current }

    private var monatsTitel: String {
        monat.formatted(.dateTime.month(.wide).year().locale(ZyklusLocale.de))
    }

    /// Wochentags-Kürzel, beginnend mit `firstWeekday` der Region.
    private var wochentage: [String] {
        var deutsch = kal
        deutsch.locale = ZyklusLocale.de
        let symbole = deutsch.shortWeekdaySymbols
        let erster = kal.firstWeekday - 1
        return Array(symbole[erster...] + symbole[..<erster])
    }

    private var tageImMonat: [Date?] {
        guard let erster = kal.date(from: kal.dateComponents([.year, .month], from: monat)),
              let anzahl = kal.range(of: .day, in: .month, for: erster)?.count else { return [] }
        let offset = (kal.component(.weekday, from: erster) - kal.firstWeekday + 7) % 7
        var tage: [Date?] = Array(repeating: nil, count: offset)
        for d in 0..<anzahl {
            tage.append(kal.date(byAdding: .day, value: d, to: erster))
        }
        while tage.count % 7 != 0 { tage.append(nil) }
        return tage
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: onVorheriger) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Vorheriger Monat")
                Spacer()
                Text(monatsTitel).font(.title3.bold())
                Spacer()
                Button(action: onNaechster) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Nächster Monat")
            }
            .foregroundStyle(Color.pink)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 2) {
                ForEach(Array(wochentage.enumerated()), id: \.offset) { _, tag in
                    Text(tag)
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 4)
                        .accessibilityHidden(true)
                }

                ForEach(Array(tageImMonat.enumerated()), id: \.offset) { index, datum in
                    if let datum {
                        zelle(datum: datum, spalte: index % 7)
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
    }

    private func zelle(datum: Date, spalte: Int) -> some View {
        let zustand = ZyklusRechner.tagZustand(datum: datum, analyse: analyse, kalender: kal)
        let eintrag = eintraegeProTag[kal.startOfDay(for: datum)]
        let vortag = kal.date(byAdding: .day, value: -1, to: datum) ?? datum
        let folgetag = kal.date(byAdding: .day, value: 1, to: datum) ?? datum
        let vorZustand = ZyklusRechner.tagZustand(datum: vortag, analyse: analyse, kalender: kal)
        let folgeZustand = ZyklusRechner.tagZustand(datum: folgetag, analyse: analyse, kalender: kal)

        let fruchtbar = zeigePrognosen && zustand.fruchtbar
        let fruchtbarRand = zeigePrognosen && zustand.fruchtbarRand
        let vorhergesagt = zeigePrognosen && zustand.vorhergesagtePeriode
        let eisprung = zeigePrognosen && zustand.ovulation
        let linksVerbunden = spalte != 0
        let rechtsVerbunden = spalte != 6

        return ZyklusTagZelle(
            datum: datum,
            periode: zustand.periode,
            periodeLinks: zustand.periode && vorZustand.periode && linksVerbunden,
            periodeRechts: zustand.periode && folgeZustand.periode && rechtsVerbunden,
            fruchtbar: fruchtbar,
            fruchtbarLinks: fruchtbar && vorZustand.fruchtbar && linksVerbunden,
            fruchtbarRechts: fruchtbar && folgeZustand.fruchtbar && rechtsVerbunden,
            fruchtbarRand: fruchtbarRand,
            vorhergesagt: vorhergesagt,
            eisprung: eisprung,
            ausgewaehlt: ausgewaehlterTag.map { kal.isDate($0, inSameDayAs: datum) } ?? false,
            eintrag: eintrag
        ) {
            onTap(datum)
        }
    }
}

// MARK: - Tageszelle

private struct ZyklusTagZelle: View {
    let datum: Date
    let periode: Bool
    let periodeLinks: Bool
    let periodeRechts: Bool
    let fruchtbar: Bool
    let fruchtbarLinks: Bool
    let fruchtbarRechts: Bool
    let fruchtbarRand: Bool
    let vorhergesagt: Bool
    let eisprung: Bool
    let ausgewaehlt: Bool
    let eintrag: ZyklusTagesSicht?
    let action: () -> Void

    private var istHeute: Bool { Calendar.current.isDateInToday(datum) }
    private var tagNummer: String { "\(Calendar.current.component(.day, from: datum))" }

    private var periodeDeckkraft: Double {
        switch eintrag?.fluss ?? .keine {
        case .schmierblutung: return 0.35
        case .leicht:         return 0.6
        case .stark:          return 1.0
        default:              return 0.85
        }
    }

    private func bandForm(links: Bool, rechts: Bool) -> UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: links ? 0 : 17,
            bottomLeadingRadius: links ? 0 : 17,
            bottomTrailingRadius: rechts ? 0 : 17,
            topTrailingRadius: rechts ? 0 : 17,
            style: .continuous
        )
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                if periode {
                    bandForm(links: periodeLinks, rechts: periodeRechts)
                        .fill(ZyklusFarbe.periode.opacity(periodeDeckkraft))
                        .frame(height: 34)
                        .padding(.leading, periodeLinks ? 0 : 5)
                        .padding(.trailing, periodeRechts ? 0 : 5)
                } else if vorhergesagt {
                    bandForm(links: false, rechts: false)
                        .fill(ZyklusFarbe.periode.opacity(0.08))
                        .overlay(
                            bandForm(links: false, rechts: false)
                                .strokeBorder(ZyklusFarbe.periode.opacity(0.55),
                                              style: StrokeStyle(lineWidth: 1.2, dash: [3, 2]))
                        )
                        .frame(height: 34)
                        .padding(.horizontal, 5)
                } else if fruchtbar {
                    bandForm(links: fruchtbarLinks, rechts: fruchtbarRechts)
                        .fill(ZyklusFarbe.fruchtbar.opacity(0.22))
                        .frame(height: 34)
                        .padding(.leading, fruchtbarLinks ? 0 : 5)
                        .padding(.trailing, fruchtbarRechts ? 0 : 5)
                } else if fruchtbarRand {
                    // Unsichere Randtage: sehr heller Hauch, nur eine Andeutung
                    bandForm(links: false, rechts: false)
                        .fill(ZyklusFarbe.fruchtbar.opacity(0.08))
                        .frame(height: 34)
                        .padding(.horizontal, 5)
                }

                if eisprung {
                    Circle()
                        .fill(ZyklusFarbe.eisprung)
                        .frame(width: 34, height: 34)
                        .shadow(color: ZyklusFarbe.eisprung.opacity(0.45), radius: 4)
                }

                // Positiver Ovulationstest: immer sichtbar als Stern oben rechts
                if eintrag?.lhTest == .positiv {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(ZyklusFarbe.eisprung)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(.top, 0).padding(.trailing, 4)
                        .accessibilityHidden(true)
                }

                if istHeute {
                    Circle()
                        .strokeBorder(Color.primary, lineWidth: 1.8)
                        .frame(width: 34, height: 34)
                }

                if ausgewaehlt {
                    Circle()
                        .strokeBorder(Color.pink, lineWidth: 2.5)
                        .frame(width: 40, height: 40)
                }

                Text(tagNummer)
                    .font(.system(.callout, design: .default).weight(periode || istHeute || eisprung ? .bold : .regular))
                    .foregroundStyle(textFarbe)

                // Status-Punkte (zusätzlich zu Farbe: Symbole in der Zugänglichkeits-Beschreibung)
                HStack(spacing: 3) {
                    if let e = eintrag {
                        if !e.symptome.isEmpty { punkt(.purple) }
                        if e.schleim != .keine { punkt(.blue) }
                        if e.sexAktivitaet != .keine { punkt(.pink) }
                        if e.lhTest != .keine || e.basaltemperatur > 0 || !e.notizen.isEmpty { punkt(.gray) }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 1)
            }
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(beschreibung)
    }

    private func punkt(_ farbe: Color) -> some View {
        Circle().fill(farbe.opacity(0.8)).frame(width: 4, height: 4)
    }

    private var textFarbe: Color {
        if eisprung { return .white }
        if periode { return periodeDeckkraft >= 0.6 ? .white : ZyklusFarbe.periode }
        if vorhergesagt { return ZyklusFarbe.periode }
        if fruchtbar { return .primary }   // lesbar in Hell- und Dunkelmodus (Band ist nur ein heller Teal-Hauch)
        return .primary
    }

    private var beschreibung: String {
        var teile: [String] = [datum.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(ZyklusLocale.de))]
        if istHeute { teile.append("heute") }
        if ausgewaehlt { teile.append("ausgewählt") }
        if periode { teile.append("Periode\(eintrag.map { $0.fluss == .keine ? "" : ", " + $0.fluss.titel } ?? "")") }
        if vorhergesagt { teile.append("Periode vorhergesagt") }
        if eisprung { teile.append("Eisprung") }
        if fruchtbar { teile.append("fruchtbar") }
        if fruchtbarRand && !fruchtbar { teile.append("möglicherweise fruchtbar") }
        if let e = eintrag {
            if !e.symptome.isEmpty { teile.append("Symptome erfasst") }
            if e.schleim != .keine { teile.append("Zervixschleim \(e.schleim.titel)") }
            if e.lhTest != .keine { teile.append("Ovulationstest \(e.lhTest.titel)") }
            if e.basaltemperatur > 0 { teile.append("Basaltemperatur erfasst") }
        }
        return teile.joined(separator: ", ")
    }
}
