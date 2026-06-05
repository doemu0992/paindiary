import Foundation

struct ZyklusAnalyse {
    let zykluslaenge: Double        // all-time average (Anzeige)
    let periodendauer: Double       // all-time average (Anzeige)
    let variation: Double
    let aktuellerZyklustag: Int?
    let naechstePeriodeStart: Date?
    let vorhergesagteOvulation: Date?
    let zyklusStarts: [Date]
    let periodeTageSet: Set<Date>
    let fruchtbareTageSet: Set<Date>
    let ovulationsTageSet: Set<Date>
    // Personalized ovulation offset learned from mucus peak days. nil = <2 cycles with data.
    let gelernterOvulationsOffset: Int?
    // Recent-weighted averages used for predictions (last 3 cycles, 50/30/20 %).
    // Equal to zykluslaenge/periodendauer when fewer than 2 completed cycles exist.
    let adaptierteZykluslaenge: Double
    let adaptiertePeriodendauer: Double

    static let leer = ZyklusAnalyse(
        zykluslaenge: 28, periodendauer: 5, variation: 0,
        aktuellerZyklustag: nil, naechstePeriodeStart: nil,
        vorhergesagteOvulation: nil, zyklusStarts: [],
        periodeTageSet: [], fruchtbareTageSet: [], ovulationsTageSet: [],
        gelernterOvulationsOffset: nil,
        adaptierteZykluslaenge: 28, adaptiertePeriodendauer: 5
    )
}

struct ZyklusTagZustand {
    var periode: Bool = false
    var vorhergesagtePeriode: Bool = false
    var fruchtbar: Bool = false
    var ovulation: Bool = false
    var verbundenLinks: Bool = false
    var verbundenRechts: Bool = false
}

struct ZyklusRechner {

    // MARK: - Main analysis

    static func analyse(eintraege: [ZyklusEintrag]) -> ZyklusAnalyse {
        let kal = Calendar.current

        let periodeTage = eintraege
            .filter { $0.istPeriode || $0.typ == "Periode" }
            .map { kal.startOfDay(for: $0.datum) }
            .sorted()

        guard !periodeTage.isEmpty else { return .leer }

        let periodeTageSet = Set(periodeTage)
        let starts = findeZyklusStarts(aus: periodeTage)

        var zyklusLaengen: [Double] = []
        for i in 1..<starts.count {
            let diff = kal.dateComponents([.day], from: starts[i-1], to: starts[i]).day ?? 28
            zyklusLaengen.append(Double(diff))
        }
        let avgZyklus = zyklusLaengen.isEmpty ? 28.0 : zyklusLaengen.reduce(0, +) / Double(zyklusLaengen.count)
        let variation: Double = {
            guard zyklusLaengen.count >= 2 else { return 0 }
            let mean = zyklusLaengen.reduce(0, +) / Double(zyklusLaengen.count)
            let variance = zyklusLaengen.map { pow($0 - mean, 2) }.reduce(0, +) / Double(zyklusLaengen.count)
            return sqrt(variance)
        }()

        var periodDauern: [Double] = []
        for start in starts {
            var len = 0; var check = start
            while periodeTageSet.contains(check) {
                len += 1
                check = kal.date(byAdding: .day, value: 1, to: check) ?? check
            }
            if len > 0 { periodDauern.append(Double(len)) }
        }
        let avgPeriod = periodDauern.isEmpty ? 5.0 : periodDauern.reduce(0, +) / Double(periodDauern.count)

        // Recent-weighted averages: last 3 cycles get 50 / 30 / 20 % weight.
        // With fewer cycles falls back gracefully to available data or overall avg.
        let adaptZyklus: Double = {
            let r = Array(zyklusLaengen.suffix(3))
            switch r.count {
            case 0:       return avgZyklus
            case 1:       return r[0]
            case 2:       return r[0] * 0.4 + r[1] * 0.6
            default:      return r[0] * 0.2 + r[1] * 0.3 + r[2] * 0.5
            }
        }()
        let adaptPeriod: Double = {
            let r = Array(periodDauern.suffix(3))
            switch r.count {
            case 0:       return avgPeriod
            case 1:       return r[0]
            case 2:       return r[0] * 0.4 + r[1] * 0.6
            default:      return r[0] * 0.2 + r[1] * 0.3 + r[2] * 0.5
            }
        }()

        // Personalized ovulation offset from mucus peak days.
        let mucusOffsets: [Int] = (0..<starts.count).compactMap { i in
            guard i + 1 < starts.count else { return nil }
            let zyklusStart = starts[i]; let zyklusEnde = starts[i + 1]
            let spitzenTage = eintraege
                .filter {
                    let tag = kal.startOfDay(for: $0.datum)
                    let s = $0.zervixschleim.lowercased()
                    return (s == "wässrig" || s == "eiweiss") && tag >= zyklusStart && tag < zyklusEnde
                }
                .map { kal.startOfDay(for: $0.datum) }.sorted()
            guard let peak = spitzenTage.last else { return nil }
            return (kal.dateComponents([.day], from: zyklusStart, to: peak).day ?? 0) + 1
        }
        let persOvulationsOffset: Int = mucusOffsets.count >= 2
            ? mucusOffsets.reduce(0, +) / mucusOffsets.count
            : Int(round(adaptZyklus)) - 14

        // Predictions use adaptive cycle length and personalized ovulation offset.
        let heute = kal.startOfDay(for: Date())
        let aktuellerTag: Int? = starts.last.map {
            (kal.dateComponents([.day], from: $0, to: heute).day ?? 0) + 1
        }
        let naechstePeriode: Date? = starts.last.map {
            kal.date(byAdding: .day, value: Int(round(adaptZyklus)), to: $0)
        } ?? nil

        let aktuellerZyklusOv: Date? = starts.last.map {
            kal.date(byAdding: .day, value: persOvulationsOffset, to: $0)!
        }
        let naechsteOvulation: Date?
        if let ov = aktuellerZyklusOv, kal.startOfDay(for: ov) >= heute {
            naechsteOvulation = ov
        } else if let np = naechstePeriode {
            naechsteOvulation = kal.date(byAdding: .day, value: persOvulationsOffset, to: np)
        } else {
            naechsteOvulation = nil
        }

        var fruchtbarSet: Set<Date> = []
        var ovulationsSet: Set<Date> = []

        func fuegeZyklusHinzu(start: Date, ovulationsOffset: Int) {
            let ovNorm = kal.startOfDay(for: kal.date(byAdding: .day, value: ovulationsOffset, to: start)!)
            ovulationsSet.insert(ovNorm)
            for d in -5...1 {
                if let ft = kal.date(byAdding: .day, value: d, to: ovNorm) {
                    fruchtbarSet.insert(ft)
                }
            }
        }

        for i in 0..<starts.count {
            if i < zyklusLaengen.count {
                fuegeZyklusHinzu(start: starts[i], ovulationsOffset: Int(zyklusLaengen[i]) - 14)
            } else {
                fuegeZyklusHinzu(start: starts[i], ovulationsOffset: persOvulationsOffset)
            }
        }
        if let np = naechstePeriode {
            fuegeZyklusHinzu(start: np, ovulationsOffset: persOvulationsOffset)
            if let np2 = kal.date(byAdding: .day, value: Int(round(adaptZyklus)), to: np) {
                fuegeZyklusHinzu(start: np2, ovulationsOffset: persOvulationsOffset)
            }
        }

        // Symptothermalmethode: every wässrig/Eiweiss day is a confirmed fertile day.
        for eintrag in eintraege {
            let s = eintrag.zervixschleim.lowercased()
            if s == "wässrig" || s == "eiweiss" {
                fruchtbarSet.insert(kal.startOfDay(for: eintrag.datum))
            }
        }

        return ZyklusAnalyse(
            zykluslaenge: avgZyklus,
            periodendauer: avgPeriod,
            variation: variation,
            aktuellerZyklustag: aktuellerTag,
            naechstePeriodeStart: naechstePeriode,
            vorhergesagteOvulation: naechsteOvulation,
            zyklusStarts: starts,
            periodeTageSet: periodeTageSet,
            fruchtbareTageSet: fruchtbarSet,
            ovulationsTageSet: ovulationsSet,
            gelernterOvulationsOffset: mucusOffsets.count >= 2 ? persOvulationsOffset : nil,
            adaptierteZykluslaenge: adaptZyklus,
            adaptiertePeriodendauer: adaptPeriod
        )
    }

    // MARK: - Tag state

    static func tagZustand(datum: Date, analyse: ZyklusAnalyse) -> ZyklusTagZustand {
        let kal = Calendar.current
        let tag = kal.startOfDay(for: datum)
        var z = ZyklusTagZustand()

        if analyse.periodeTageSet.contains(tag) {
            z.periode = true
            let vortag = kal.date(byAdding: .day, value: -1, to: tag)!
            let morgen = kal.date(byAdding: .day, value: 1, to: tag)!
            z.verbundenLinks = analyse.periodeTageSet.contains(vortag)
            z.verbundenRechts = analyse.periodeTageSet.contains(morgen)
        }

        // Predicted period: use adaptive cycle length and period duration.
        if !z.periode, let start = analyse.naechstePeriodeStart {
            let zyklusLen = Int(round(analyse.adaptierteZykluslaenge))
            let periodLen = max(Int(round(analyse.adaptiertePeriodendauer)), 3)
            for offset in [0, 1] {
                if let pStart = kal.date(byAdding: .day, value: offset * zyklusLen, to: start) {
                    for d in 0..<periodLen {
                        if let pDay = kal.date(byAdding: .day, value: d, to: pStart),
                           kal.startOfDay(for: pDay) == tag {
                            z.vorhergesagtePeriode = true
                        }
                    }
                }
            }
        }

        if !z.periode && analyse.fruchtbareTageSet.contains(tag) { z.fruchtbar = true }
        if analyse.ovulationsTageSet.contains(tag) { z.ovulation = true }

        return z
    }

    // MARK: - Cycle start detection

    private static func findeZyklusStarts(aus tage: [Date]) -> [Date] {
        guard !tage.isEmpty else { return [] }
        let kal = Calendar.current
        var starts = [tage[0]]
        for i in 1..<tage.count {
            let diff = kal.dateComponents([.day], from: tage[i-1], to: tage[i]).day ?? 0
            if diff > 1 { starts.append(tage[i]) }
        }
        return starts
    }

    // MARK: - Pain–cycle correlation

    enum Zyklusphase: String, CaseIterable {
        case menstruation = "Menstruation"
        case follikelphase = "Follikelphase"
        case ovulation = "Ovulation"
        case lutealphase = "Lutealphase"
    }

    static func schmerzJePhase(
        painEntries: [PainEntry],
        analyse: ZyklusAnalyse
    ) -> [(phase: Zyklusphase, avgSchmerz: Double, anzahl: Int)] {
        guard !analyse.zyklusStarts.isEmpty else { return [] }
        let kal = Calendar.current
        let ovuOffset = analyse.gelernterOvulationsOffset ?? (Int(round(analyse.adaptierteZykluslaenge)) - 14)
        var map: [Zyklusphase: [Int]] = Dictionary(uniqueKeysWithValues: Zyklusphase.allCases.map { ($0, []) })

        for entry in painEntries {
            let entryTag = kal.startOfDay(for: entry.datum)
            guard let zyklusStart = analyse.zyklusStarts.last(where: { $0 <= entryTag }) else { continue }
            let zyklustag = (kal.dateComponents([.day], from: zyklusStart, to: entryTag).day ?? 0) + 1
            let periodLen = Int(round(analyse.adaptiertePeriodendauer))

            let phase: Zyklusphase
            if zyklustag <= periodLen {
                phase = .menstruation
            } else if zyklustag < ovuOffset - 2 {
                phase = .follikelphase
            } else if zyklustag <= ovuOffset + 2 {
                phase = .ovulation
            } else {
                phase = .lutealphase
            }
            map[phase, default: []].append(entry.schmerzstaerke)
        }

        return Zyklusphase.allCases.compactMap { phase in
            let werte = map[phase] ?? []
            guard !werte.isEmpty else { return nil }
            return (phase: phase, avgSchmerz: Double(werte.reduce(0, +)) / Double(werte.count), anzahl: werte.count)
        }
    }
}
