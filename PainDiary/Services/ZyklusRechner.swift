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

    static let leer = ZyklusAnalyse(
        zykluslaenge: 28, periodendauer: 5, variation: 0,
        aktuellerZyklustag: nil, naechstePeriodeStart: nil,
        vorhergesagteOvulation: nil, zyklusStarts: [],
        periodeTageSet: [], fruchtbareTageSet: [], ovulationsTageSet: []
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

        // Average cycle length
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
            var len = 0
            var check = start
            while periodeTageSet.contains(check) {
                len += 1
                check = kal.date(byAdding: .day, value: 1, to: check) ?? check
            }
            if len > 0 { periodDauern.append(Double(len)) }
        }
        let avgPeriod = periodDauern.isEmpty ? 5.0 : periodDauern.reduce(0, +) / Double(periodDauern.count)

        // Predicted ovulation: prefer next upcoming one (current cycle if not yet past, else next cycle)
        let heute = kal.startOfDay(for: Date())
        let aktuellerZyklusOv: Date? = starts.last.map {
            kal.date(byAdding: .day, value: Int(avgZyklus) - 14, to: $0)!
        }
        let naechsteOvulation: Date?
        if let ov = aktuellerZyklusOv, kal.startOfDay(for: ov) >= heute {
            naechsteOvulation = ov
        } else if let np = naechstePeriode {
            naechsteOvulation = kal.date(byAdding: .day, value: Int(avgZyklus) - 14, to: np)
        } else {
            naechsteOvulation = nil
        }

        // Current cycle day
        let aktuellerTag: Int? = starts.last.map {
            (kal.dateComponents([.day], from: $0, to: heute).day ?? 0) + 1
        }

        // Next period prediction
        let naechstePeriode: Date? = starts.last.map {
            kal.date(byAdding: .day, value: Int(avgZyklus), to: $0)
        } ?? nil

        // Build fertile window and ovulation sets for all historical + next 2 cycles
        var fruchtbarSet: Set<Date> = []
        var ovulationsSet: Set<Date> = []

        let alleCycleStarts = starts + [naechstePeriode, naechstePeriode.flatMap {
            kal.date(byAdding: .day, value: Int(avgZyklus), to: $0)
        }].compactMap { $0 }

        for start in alleCycleStarts {
            let ovTag = kal.date(byAdding: .day, value: Int(avgZyklus) - 14, to: start)!
            let ovNorm = kal.startOfDay(for: ovTag)
            ovulationsSet.insert(ovNorm)
            for d in -5...1 {
                if let fTag = kal.date(byAdding: .day, value: d, to: ovNorm) {
                    fruchtbarSet.insert(fTag)
                }
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
            ovulationsTageSet: ovulationsSet
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
        var map: [Zyklusphase: [Int]] = Dictionary(uniqueKeysWithValues: Zyklusphase.allCases.map { ($0, []) })

        for entry in painEntries {
            let entryTag = kal.startOfDay(for: entry.datum)
            guard let zyklusStart = analyse.zyklusStarts.last(where: { $0 <= entryTag }) else { continue }
            let zyklustag = (kal.dateComponents([.day], from: zyklusStart, to: entryTag).day ?? 0) + 1
            let len = Int(analyse.zykluslaenge)
            let ovuTag = len - 14
            let periodLen = Int(analyse.periodendauer)

            let phase: Zyklusphase
            if zyklustag <= periodLen {
                phase = .menstruation
            } else if zyklustag < ovuTag - 2 {
                phase = .follikelphase
            } else if zyklustag <= ovuTag + 2 {
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
