import Foundation

struct ZyklusAnalyse {
    let zykluslaenge: Double       // average cycle length
    let periodendauer: Double      // average period duration
    let variation: Double          // standard deviation of cycle lengths
    let aktuellerZyklustag: Int?
    let naechstePeriodeStart: Date?
    let vorhergesagteOvulation: Date?
    let zyklusStarts: [Date]
    let periodeTageSet: Set<Date>
    let fruchtbareTageSet: Set<Date>
    let ovulationsTageSet: Set<Date>
    // Personalized ovulation offset (days from cycle start) learned from mucus data.
    // nil = not enough cycles with mucus tracking to learn (<2)
    let gelernterOvulationsOffset: Int?

    static let leer = ZyklusAnalyse(
        zykluslaenge: 28, periodendauer: 5, variation: 0,
        aktuellerZyklustag: nil, naechstePeriodeStart: nil,
        vorhergesagteOvulation: nil, zyklusStarts: [],
        periodeTageSet: [], fruchtbareTageSet: [], ovulationsTageSet: [],
        gelernterOvulationsOffset: nil
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

        // Collect period days — support both new `istPeriode` and legacy `typ == "Periode"`
        let periodeTage = eintraege
            .filter { $0.istPeriode || $0.typ == "Periode" }
            .map { kal.startOfDay(for: $0.datum) }
            .sorted()

        guard !periodeTage.isEmpty else { return .leer }

        let periodeTageSet = Set(periodeTage)
        let starts = findeZyklusStarts(aus: periodeTage)

        // Per-cycle lengths: zyklusLaengen[i] = length of cycle starting at starts[i]
        // (only available for completed cycles, i.e. i < starts.count - 1)
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

        // Average period duration
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

        // Learn personalized ovulation offset from mucus peak days across completed cycles.
        // Peak day = last Eiweiss/wässrig day in a cycle; ovulation = peak + 1.
        // Only uses completed cycles (those with a known end = next period start).
        let mucusOffsets: [Int] = (0..<starts.count).compactMap { i in
            guard i + 1 < starts.count else { return nil } // skip current incomplete cycle
            let zyklusStart = starts[i]
            let zyklusEnde = starts[i + 1]
            let spitzenTage = eintraege
                .filter {
                    let tag = kal.startOfDay(for: $0.datum)
                    let s = $0.zervixschleim.lowercased()
                    return (s == "wässrig" || s == "eiweiss") && tag >= zyklusStart && tag < zyklusEnde
                }
                .map { kal.startOfDay(for: $0.datum) }
                .sorted()
            guard let peak = spitzenTage.last else { return nil }
            return (kal.dateComponents([.day], from: zyklusStart, to: peak).day ?? 0) + 1
        }
        // Require at least 2 cycles with mucus data before trusting the learned offset.
        let persOvulationsOffset: Int = mucusOffsets.count >= 2
            ? mucusOffsets.reduce(0, +) / mucusOffsets.count
            : Int(avgZyklus) - 14

        // Next period and current cycle day
        let heute = kal.startOfDay(for: Date())
        let aktuellerTag: Int? = starts.last.map {
            (kal.dateComponents([.day], from: $0, to: heute).day ?? 0) + 1
        }
        let naechstePeriode: Date? = starts.last.map {
            kal.date(byAdding: .day, value: Int(avgZyklus), to: $0)
        } ?? nil

        // Next upcoming ovulation using personalized offset.
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

        // Build fertile + ovulation sets.
        // Historical completed cycles use their actual length with the standard offset
        // (we already have real mucus data for those days added below).
        // Current and future cycles use the personalized offset.
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
                // Completed cycle — calendar prediction with actual cycle length
                fuegeZyklusHinzu(start: starts[i], ovulationsOffset: Int(zyklusLaengen[i]) - 14)
            } else {
                // Current ongoing cycle — use personalized (or default) offset
                fuegeZyklusHinzu(start: starts[i], ovulationsOffset: persOvulationsOffset)
            }
        }
        // Next 2 predicted future cycles
        if let np = naechstePeriode {
            fuegeZyklusHinzu(start: np, ovulationsOffset: persOvulationsOffset)
            if let np2 = kal.date(byAdding: .day, value: Int(avgZyklus), to: np) {
                fuegeZyklusHinzu(start: np2, ovulationsOffset: persOvulationsOffset)
            }
        }

        // Symptothermalmethode: each wässrig/Eiweiss day is confirmed fertile
        for eintrag in eintraege {
            let schleim = eintrag.zervixschleim.lowercased()
            if schleim == "wässrig" || schleim == "eiweiss" {
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
            gelernterOvulationsOffset: mucusOffsets.count >= 2 ? persOvulationsOffset : nil
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

        // Predicted period (next 2 cycles)
        if !z.periode, let start = analyse.naechstePeriodeStart {
            let len = max(Int(analyse.periodendauer), 3)
            for offset in [0, 1] {
                if let pStart = kal.date(byAdding: .day, value: offset * Int(analyse.zykluslaenge), to: start) {
                    for d in 0..<len {
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
        let ovuOffset = analyse.gelernterOvulationsOffset ?? (Int(analyse.zykluslaenge) - 14)
        var map: [Zyklusphase: [Int]] = Dictionary(uniqueKeysWithValues: Zyklusphase.allCases.map { ($0, []) })

        for entry in painEntries {
            let entryTag = kal.startOfDay(for: entry.datum)
            guard let zyklusStart = analyse.zyklusStarts.last(where: { $0 <= entryTag }) else { continue }
            let zyklustag = (kal.dateComponents([.day], from: zyklusStart, to: entryTag).day ?? 0) + 1
            let periodLen = Int(analyse.periodendauer)

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
