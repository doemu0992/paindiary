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
    // Personalized ovulation offset learned per cycle (LH test > BBT rise > mucus peak).
    // nil = fewer than 2 cycles with usable data.
    let gelernterOvulationsOffset: Int?
    // Recent-weighted averages used for predictions (last 3 cycles, 50/30/20 %).
    // Equal to zykluslaenge/periodendauer when fewer than 2 completed cycles exist.
    let adaptierteZykluslaenge: Double
    let adaptiertePeriodendauer: Double
    // Status of the current cycle's ovulation estimate.
    let ovulationBestaetigt: Bool     // belegt durch LH-Test oder Temperaturanstieg
    let ovulationVerzoegert: Bool     // negative Tests haben die Vorhersage nach hinten geschoben
    let ovulationsUnsicherheit: Int   // ± Tage (0 = bestätigt)
    let gelernteLutealphase: Int      // Tage, aus eigenen Zyklen (10–16)

    static let leer = ZyklusAnalyse(
        zykluslaenge: 28, periodendauer: 5, variation: 0,
        aktuellerZyklustag: nil, naechstePeriodeStart: nil,
        vorhergesagteOvulation: nil, zyklusStarts: [],
        periodeTageSet: [], fruchtbareTageSet: [], ovulationsTageSet: [],
        gelernterOvulationsOffset: nil,
        adaptierteZykluslaenge: 28, adaptiertePeriodendauer: 5,
        ovulationBestaetigt: false, ovulationVerzoegert: false,
        ovulationsUnsicherheit: 1, gelernteLutealphase: 14
    )
}

extension ZyklusAnalyse {
    /// Unter hormoneller Verhütung finden keine (vorhersagbaren) Eisprünge statt —
    /// Fruchtbarkeits- und Eisprung-Prognosen werden ausgeblendet, Perioden-Statistik
    /// und -Vorhersage (Abbruchblutung ist regelmässig) bleiben erhalten.
    var ohneFruchtbarkeitsPrognosen: ZyklusAnalyse {
        ZyklusAnalyse(
            zykluslaenge: zykluslaenge, periodendauer: periodendauer, variation: variation,
            aktuellerZyklustag: aktuellerZyklustag, naechstePeriodeStart: naechstePeriodeStart,
            vorhergesagteOvulation: nil, zyklusStarts: zyklusStarts,
            periodeTageSet: periodeTageSet, fruchtbareTageSet: [], ovulationsTageSet: [],
            gelernterOvulationsOffset: nil,
            adaptierteZykluslaenge: adaptierteZykluslaenge,
            adaptiertePeriodendauer: adaptiertePeriodendauer,
            ovulationBestaetigt: false, ovulationVerzoegert: false,
            ovulationsUnsicherheit: 0, gelernteLutealphase: gelernteLutealphase
        )
    }
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

    static func analyse(eintraege alleEintraege: [ZyklusEintrag], stoerTage: Set<Date> = []) -> ZyklusAnalyse {
        let kal = Calendar.current
        let heute = kal.startOfDay(for: Date())

        // Zukunftsdatierte Einträge (über den Kalender möglich) fliessen nicht
        // in die Berechnung ein — ein auf morgen datierter Test oder Periodentag
        // würde sonst Vorhersage und Lernen verfälschen.
        let eintraege = alleEintraege.filter { kal.startOfDay(for: $0.datum) <= heute }

        let periodeTage = eintraege
            .filter { $0.istPeriode || $0.typ == "Periode" }
            .map { kal.startOfDay(for: $0.datum) }
            .sorted()

        guard !periodeTage.isEmpty else { return .leer }

        let periodeTageSet = Set(periodeTage)
        let starts = findeZyklusStarts(aus: periodeTage)

        // Zykluslängen pro abgeschlossenem Zyklus. Nur plausible Längen (21–60 Tage)
        // fliessen in Statistik, adaptive Vorhersage und Lernen ein — Ausreisser
        // (Tracking-Pausen, Datenlücken) würden sonst alle Vorhersagen verzerren.
        var zyklusLaengen: [Double] = []            // nur plausible
        var zyklusLaengenProZyklus: [Double?] = []  // pro Zyklus, nil = implausibel
        for i in 1..<starts.count {
            let diff = Double(kal.dateComponents([.day], from: starts[i-1], to: starts[i]).day ?? 28)
            let plausibel = diff >= 21 && diff <= 60
            zyklusLaengenProZyklus.append(plausibel ? diff : nil)
            if plausibel { zyklusLaengen.append(diff) }
        }
        // Ausreisser-Schutz: Ein einzelner "Riesen-Zyklus" ist fast immer eine
        // Erfassungslücke (nicht nachgetragene Periode) — zwei echte Zyklen
        // verschmelzen zu einem. Längen, die mehr als 10 Tage vom Median der
        // eigenen Zyklen abweichen, fliessen nicht in Statistik, adaptive
        // Vorhersage und Lernen ein. (Der Zyklusverlauf-Chart zeigt sie weiter,
        // damit die Lücke sichtbar bleibt.)
        if zyklusLaengen.count >= 4 {
            let sortiert = zyklusLaengen.sorted()
            let median = sortiert[sortiert.count / 2]
            let ohneAusreisser = zyklusLaengen.filter { abs($0 - median) <= 10 }
            if ohneAusreisser.count >= 3 { zyklusLaengen = ohneAusreisser }
        }

        let avgZyklus = zyklusLaengen.isEmpty ? 28.0 : zyklusLaengen.reduce(0, +) / Double(zyklusLaengen.count)
        let variation: Double = {
            guard zyklusLaengen.count >= 2 else { return 0 }
            let mean = zyklusLaengen.reduce(0, +) / Double(zyklusLaengen.count)
            let variance = zyklusLaengen.map { pow($0 - mean, 2) }.reduce(0, +) / Double(zyklusLaengen.count)
            return sqrt(variance)
        }()

        // Periodendauer je Zyklus: zusammenhängende Blutungstage ab Zyklusstart.
        // Eine Lücke von 1 Tag (vergessene Erfassung) wird toleriert, maximal
        // 10 Tage insgesamt — spätere Zwischenblutungen zählen nicht zur Periode.
        var periodDauern: [Double] = []
        var periodenKettenTage: Set<Date> = []   // Tage, die zu einer echten Periode gehören
        for (i, start) in starts.enumerated() {
            let ende = i + 1 < starts.count ? starts[i + 1] : nil
            var letzter = start
            for tag in periodeTage where tag > start {
                if let e = ende, tag >= e { break }
                let luecke = kal.dateComponents([.day], from: letzter, to: tag).day ?? 99
                let seitStart = kal.dateComponents([.day], from: start, to: tag).day ?? 99
                guard luecke <= 2, seitStart <= 9 else { break }
                letzter = tag
            }
            let dauer = (kal.dateComponents([.day], from: start, to: letzter).day ?? 0) + 1
            periodDauern.append(Double(dauer))
            for d in 0..<dauer {
                if let t = kal.date(byAdding: .day, value: d, to: start) { periodenKettenTage.insert(t) }
            }
        }
        let avgPeriod = periodDauern.isEmpty ? 5.0 : periodDauern.reduce(0, +) / Double(periodDauern.count)

        // Recent-weighted averages: last 3 cycles get 50 / 30 / 20 % weight.
        // With fewer cycles falls back gracefully to available data or overall avg.
        let adaptZyklusBasis: Double = {
            let r = Array(zyklusLaengen.suffix(3))
            switch r.count {
            case 0:       return avgZyklus
            case 1:       return r[0]
            case 2:       return r[0] * 0.4 + r[1] * 0.6
            default:      return r[0] * 0.2 + r[1] * 0.3 + r[2] * 0.5
            }
        }()
        // Selbstlernende Bias-Korrektur: Wie hätte die adaptive Gewichtung die
        // letzten Zyklen vorhergesagt, und wie weit lag sie systematisch daneben?
        // Ein konsistenter Fehler (immer zu früh / zu spät) wird abgezogen.
        let prognoseBias: Int = {
            guard zyklusLaengen.count >= 3 else { return 0 }
            var fehler: [Double] = []
            for i in 2..<zyklusLaengen.count {
                let r = Array(zyklusLaengen[max(0, i - 3)..<i])
                let prognose: Double
                switch r.count {
                case 1:  prognose = r[0]
                case 2:  prognose = r[0] * 0.4 + r[1] * 0.6
                default: prognose = r[0] * 0.2 + r[1] * 0.3 + r[2] * 0.5
                }
                fehler.append(zyklusLaengen[i] - prognose)
            }
            let letzte = Array(fehler.suffix(3))
            let mittel = letzte.reduce(0, +) / Double(letzte.count)
            return min(max(Int(mittel.rounded()), -2), 2)
        }()
        let adaptZyklus = adaptZyklusBasis + Double(prognoseBias)
        let adaptPeriod: Double = {
            let r = Array(periodDauern.suffix(3))
            switch r.count {
            case 0:       return avgPeriod
            case 1:       return r[0]
            case 2:       return r[0] * 0.4 + r[1] * 0.6
            default:      return r[0] * 0.2 + r[1] * 0.3 + r[2] * 0.5
            }
        }()

        // LH tests (multiple per day possible, each with its own time).
        // A positive test means ovulation follows in ~24–36 h:
        //   morning/afternoon test → ovulation next day (+24–36 h lands there)
        //   evening test (>= 18:00) → ovulation the day after next
        //   no time known → next day
        // The FIRST positive test counts; later positives are the same surge.
        let alleTestMessungen: [(tag: Date, zeit: Date?, ergebnis: String)] = eintraege.flatMap { e in
            let tag = kal.startOfDay(for: e.datum)
            return e.ovulationstestMessungen.map { (tag, $0.zeit, $0.ergebnis.lowercased()) }
        }

        func lhOffset(zyklusStart: Date, zyklusEnde: Date?) -> Int? {
            let positive = alleTestMessungen
                .filter { m in
                    m.ergebnis == "positiv" && m.tag >= zyklusStart
                        && (zyklusEnde.map { ende in m.tag < ende } ?? true)
                }
                .sorted { ($0.zeit ?? $0.tag) < ($1.zeit ?? $1.tag) }
            guard let erster = positive.first else { return nil }
            let abends = erster.zeit.map { kal.component(.hour, from: $0) >= 18 } ?? false
            return (kal.dateComponents([.day], from: zyklusStart, to: erster.tag).day ?? 0) + (abends ? 2 : 1)
        }

        // Basaltemperatur: 3-über-6-Regel (Sensiplan / symptothermale Methode).
        // Drei aufeinanderfolgende Messwerte liegen über dem Maximum der bis zu
        // 6 vorherigen Messwerte, der dritte davon mindestens 0,2 °C darüber.
        // Der Eisprung liegt am Tag VOR dem ersten erhöhten Wert (der Anstieg
        // bestätigt den Eisprung retrospektiv).
        // Gestörte Messwerte (Alkohol am Vorabend, zu kurzer Schlaf, Krankheit)
        // fliegen raus, BEVOR die Regel angewendet wird — ein einziger
        // Fieber-Ausreisser würde sonst einen falschen Eisprung "bestätigen".
        let tempTage: [(tag: Date, temp: Double)] = eintraege
            .filter { $0.basaltemperatur > 0 && !stoerTage.contains(kal.startOfDay(for: $0.datum)) }
            .map { (kal.startOfDay(for: $0.datum), $0.basaltemperatur) }
            .sorted { $0.tag < $1.tag }

        func bbtOffset(zyklusStart: Date, zyklusEnde: Date?) -> Int? {
            let imZyklus = tempTage.filter { t in
                t.tag >= zyklusStart && (zyklusEnde.map { ende in t.tag < ende } ?? true)
            }
            guard imZyklus.count >= 6 else { return nil }
            for i in 3..<(imZyklus.count - 2) {
                let vorher = imZyklus[max(0, i - 6)..<i]
                guard vorher.count >= 3, let referenz = vorher.map(\.temp).max() else { continue }
                // Die 3 Anstiegswerte müssen zeitlich eng beieinander liegen (≤ 4 Tage),
                // sonst ist die Messreihe zu lückenhaft für eine Bestätigung.
                let spanne = kal.dateComponents([.day], from: imZyklus[i].tag, to: imZyklus[i + 2].tag).day ?? 99
                guard spanne <= 4,
                      imZyklus[i].temp > referenz,
                      imZyklus[i + 1].temp > referenz,
                      imZyklus[i + 2].temp >= referenz + 0.2 else { continue }
                let ovTag = kal.date(byAdding: .day, value: -1, to: imZyklus[i].tag)!
                let offset = kal.dateComponents([.day], from: zyklusStart, to: ovTag).day ?? -1
                // Eisprung vor Zyklustag 5 ist physiologisch unplausibel
                guard offset >= 5 else { continue }
                return offset
            }
            return nil
        }

        // Mittelschmerz: Krämpfe/Unterleibsschmerz mitten im Zyklus (Tag 8–20,
        // nicht während oder direkt nach der Periode) sind ein schwaches
        // Eisprung-Signal — der Schmerz tritt ungefähr AM Eisprungtag auf.
        func mittelschmerzOffset(zyklusStart: Date, zyklusEnde: Date?) -> Int? {
            let kandidaten = eintraege.filter { e in
                let tag = kal.startOfDay(for: e.datum)
                guard tag >= zyklusStart, (zyklusEnde.map { tag < $0 } ?? true) else { return false }
                let s = e.symptome.lowercased()
                guard s.contains("krämpfe") || s.contains("unterleib") else { return false }
                let off = kal.dateComponents([.day], from: zyklusStart, to: tag).day ?? 0
                guard (7...19).contains(off) else { return false }
                let naheAnPeriode = (0...3).contains { d in
                    kal.date(byAdding: .day, value: -d, to: tag).map { periodeTageSet.contains($0) } ?? false
                }
                return !naheAnPeriode
            }
            .map { kal.startOfDay(for: $0.datum) }.sorted()
            guard let erster = kandidaten.first else { return nil }
            return kal.dateComponents([.day], from: zyklusStart, to: erster).day
        }

        // Ovulationsblutung: eine isolierte Schmierblutung mitten im Zyklus
        // (gehört zu keiner Periodenkette) ist ebenfalls ein schwaches Signal.
        func zwischenblutungOffset(zyklusStart: Date, zyklusEnde: Date?) -> Int? {
            let kandidaten = periodeTage.filter { tag in
                tag >= zyklusStart
                    && (zyklusEnde.map { tag < $0 } ?? true)
                    && !periodenKettenTage.contains(tag)
            }
            guard let erster = kandidaten.first else { return nil }
            let off = kal.dateComponents([.day], from: zyklusStart, to: erster).day ?? 0
            return (7...19).contains(off) ? off : nil
        }

        // Confirmed ovulation in the CURRENT cycle (measured, not estimated).
        // Computed up front so it can feed the learning pool immediately —
        // the next cycle's prediction must not wait for this cycle to finish.
        let aktuellerZyklusLH  = starts.last.flatMap { lhOffset(zyklusStart: $0, zyklusEnde: nil) }
        let aktuellerZyklusBBT = starts.last.flatMap { bbtOffset(zyklusStart: $0, zyklusEnde: nil) }
        // LH-positiv oder Temperaturanstieg = Eisprung ist belegt, nicht geschätzt
        let aktuellerOvBestaetigt = aktuellerZyklusLH != nil || aktuellerZyklusBBT != nil

        // Mucus peak per cycle (helper for learning and current-cycle estimate).
        // Requires at least 4 days after period end to exclude post-period discharge.
        func mucusPeakOffset(zyklusStart: Date, zyklusEnde: Date?) -> Int? {
            let zyklusPeriodEnd = periodeTage.last(where: { tag in
                tag >= zyklusStart && (zyklusEnde.map { tag < $0 } ?? true)
            })
            let fruehesteMucus: Date = zyklusPeriodEnd.map {
                kal.date(byAdding: .day, value: 4, to: $0)!
            } ?? zyklusStart
            let spitzenTage = eintraege
                .filter {
                    let tag = kal.startOfDay(for: $0.datum)
                    let s = $0.zervixschleim.lowercased()
                    return (s == "wässrig" || s == "eiweiss") && tag >= fruehesteMucus
                        && (zyklusEnde.map { tag < $0 } ?? true)
                }
                .map { kal.startOfDay(for: $0.datum) }.sorted()
            guard let peak = spitzenTage.last else { return nil }
            return (kal.dateComponents([.day], from: zyklusStart, to: peak).day ?? 0) + 1
        }

        // Personalized ovulation offset, learned per cycle with SIGNAL QUALITY
        // weighting: LH test ×3 > BBT rise ×2 > mucus/Mittelschmerz/Zwischenblutung ×1.
        var ovulationsSignale: [(offset: Int, gewicht: Int)] = (0..<starts.count).compactMap { i in
            guard i + 1 < starts.count else { return nil }
            let s = starts[i]; let e = starts[i + 1]
            if let lh = lhOffset(zyklusStart: s, zyklusEnde: e) { return (lh, 3) }
            if let bbt = bbtOffset(zyklusStart: s, zyklusEnde: e) { return (bbt, 2) }
            if let peak = mucusPeakOffset(zyklusStart: s, zyklusEnde: e) { return (peak, 1) }
            if let ms = mittelschmerzOffset(zyklusStart: s, zyklusEnde: e) { return (ms, 1) }
            if let zb = zwischenblutungOffset(zyklusStart: s, zyklusEnde: e) { return (zb, 1) }
            return nil
        }
        // Bestätigter Eisprung im laufenden Zyklus fliesst SOFORT ins Lernen ein —
        // die Vorhersage des Folgezyklus wartet nicht auf das Zyklusende.
        if let lh = aktuellerZyklusLH {
            ovulationsSignale.append((lh, 3))
        } else if let bbt = aktuellerZyklusBBT {
            ovulationsSignale.append((bbt, 2))
        }
        // Selbstkalibrierung des gelernten Offsets gegen die eigene Zykluslänge:
        // Die Lutealphase (Zyklus − Offset) liegt physiologisch bei 10–16 Tagen.
        // Ein zu früh gelernter Offset (z.B. durch spärlich erfassten Zervixschleim)
        // wird an diese Grenzen zurückgeholt, statt alle Vorhersagen zu verzerren.
        let persOvulationsOffset: Int = {
            let kalenderOffset = Int(round(adaptZyklus)) - 14
            guard ovulationsSignale.count >= 2 else { return kalenderOffset }
            let summeGewichte = ovulationsSignale.map(\.gewicht).reduce(0, +)
            let gewichteteSumme = ovulationsSignale.map { $0.offset * $0.gewicht }.reduce(0, +)
            let gelernt = Int((Double(gewichteteSumme) / Double(summeGewichte)).rounded())
            let minOffset = Int(round(adaptZyklus)) - 16   // Lutealphase max. 16 Tage
            let maxOffset = Int(round(adaptZyklus)) - 10   // Lutealphase min. 10 Tage
            return min(max(gelernt, minOffset), maxOffset)
        }()

        // Current cycle: LH test beats everything — ovulation is a hard fact
        // ~24–36 h after the first positive test. A BBT rise confirms ovulation
        // retrospectively. Otherwise use this cycle's observed mucus peak (only
        // mucus at least 4 days after the period ends, to exclude post-period
        // discharge). Without a confirmed ovulation, negative tests around the
        // predicted ovulation day push the prediction later.
        let (aktuellerZyklusOvOffset, aktuellerOvVerzoegert): (Int, Bool) = {
            guard let currentStart = starts.last else { return (persOvulationsOffset, false) }
            if let lh = aktuellerZyklusLH { return (lh, false) }
            if let bbt = aktuellerZyklusBBT { return (bbt, false) }

            // Beobachtete schwache Signale: Schleim-Peak > Mittelschmerz > Zwischenblutung.
            // Only shift ovulation later — never earlier — to avoid treating the first
            // day of fertile mucus as the peak (peak = last day; cycle is still ongoing).
            let beobachtet = mucusPeakOffset(zyklusStart: currentStart, zyklusEnde: nil)
                ?? mittelschmerzOffset(zyklusStart: currentStart, zyklusEnde: nil)
                ?? zwischenblutungOffset(zyklusStart: currentStart, zyklusEnde: nil)
            let basis = beobachtet.map { max($0, persOvulationsOffset) } ?? persOvulationsOffset

            // Negative tests contradict the prediction: the LH surge shows up
            // ~24–36 h BEFORE ovulation, so a negative test on or after the day
            // before the predicted ovulation means ovulation hasn't been triggered
            // yet → shift to (last such negative test day + 1). Only ever shift
            // later, never cancel — a single test can miss a short surge.
            // Negatives earlier in the cycle are expected and ignored.
            guard let ovDatum = kal.date(byAdding: .day, value: basis, to: currentStart),
                  let grenze = kal.date(byAdding: .day, value: -1, to: ovDatum) else { return (basis, false) }
            let relevanteNegative = alleTestMessungen
                .filter { $0.ergebnis == "negativ" && $0.tag >= currentStart && $0.tag >= grenze }
                .map(\.tag)
            guard let letzterNegativer = relevanteNegative.max() else { return (basis, false) }
            let verschoben = (kal.dateComponents([.day], from: currentStart, to: letzterNegativer).day ?? 0) + 1
            return (max(basis, verschoben), verschoben > basis)
        }()

        // Predictions use adaptive cycle length and personalized ovulation offset.
        let aktuellerTag: Int? = starts.last.map {
            (kal.dateComponents([.day], from: $0, to: heute).day ?? 0) + 1
        }
        // Die Lutealphase ist konstant (~12–16 Tage), die Follikelphase variiert:
        // verschiebt sich der Eisprung, verschiebt sich auch die Periode.
        // Bestätigter Eisprung (LH/BBT) datiert die Periode exakt; geschätzte
        // Verschiebungen (Schleim-Peak, negative Tests) korrigieren nur nach hinten.
        let lutealTage = min(max(Int(round(adaptZyklus)) - persOvulationsOffset, 10), 16)

        // Bestätigter Eisprung passt den KOMPLETTEN Zyklus an, nicht nur den
        // Eisprungtag: Die projizierte Länge des laufenden Zyklus (Eisprung +
        // Lutealphase) geht sofort als neuester Datenpunkt in die adaptive
        // Zykluslänge ein — alle Folge-Vorhersagen (übernächste Periode,
        // künftige Fenster, Phasenrechnung) rechnen damit weiter.
        let adaptZyklusAngepasst: Double = {
            guard aktuellerOvBestaetigt else { return adaptZyklus }
            let projiziert = Double(aktuellerZyklusOvOffset + lutealTage)
            let r = Array((zyklusLaengen + [projiziert]).suffix(3))
            switch r.count {
            case 1:  return r[0]
            case 2:  return r[0] * 0.4 + r[1] * 0.6
            default: return r[0] * 0.2 + r[1] * 0.3 + r[2] * 0.5
            }
        }()

        let naechstePeriode: Date? = starts.last.map { start in
            let kalendarisch = kal.date(byAdding: .day, value: Int(round(adaptZyklusAngepasst)), to: start)!
            let ovBasiert = kal.date(byAdding: .day, value: aktuellerZyklusOvOffset + lutealTage, to: start)!
            return aktuellerOvBestaetigt ? ovBasiert : max(kalendarisch, ovBasiert)
        }

        let aktuellerZyklusOv: Date? = starts.last.map {
            kal.date(byAdding: .day, value: aktuellerZyklusOvOffset, to: $0)!
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

        // Bei schwankenden Zyklen (hohe Variation) wird das VORHERGESAGTE
        // fruchtbare Fenster nach vorne verbreitert — die Unsicherheit über den
        // Eisprungtermin muss sich im Fenster widerspiegeln.
        let fensterExtra = variation >= 2.5 ? 2 : (variation >= 1.5 ? 1 : 0)

        func fuegeZyklusHinzu(start: Date, ovulationsOffset: Int, extraVor: Int = 0) {
            let ovNorm = kal.startOfDay(for: kal.date(byAdding: .day, value: ovulationsOffset, to: start)!)
            ovulationsSet.insert(ovNorm)
            for d in (-5 - extraVor)...1 {
                if let ft = kal.date(byAdding: .day, value: d, to: ovNorm) {
                    fruchtbarSet.insert(ft)
                }
            }
        }

        for i in 0..<starts.count {
            if i == starts.count - 1 {
                // Current (incomplete) cycle: LH / BBT / weak signals (see aktuellerZyklusOvOffset).
                // No widening when the ovulation is confirmed — then the window is exact.
                fuegeZyklusHinzu(start: starts[i], ovulationsOffset: aktuellerZyklusOvOffset,
                                 extraVor: aktuellerOvBestaetigt ? 0 : fensterExtra)
            } else if let direkt = lhOffset(zyklusStart: starts[i], zyklusEnde: starts[i + 1])
                        ?? bbtOffset(zyklusStart: starts[i], zyklusEnde: starts[i + 1]) {
                // Completed cycle with a measured signal: LH test or BBT rise
                fuegeZyklusHinzu(start: starts[i], ovulationsOffset: direkt)
            } else if let laenge = zyklusLaengenProZyklus[i] {
                // Plausible completed cycle: back-calculate from actual length
                fuegeZyklusHinzu(start: starts[i], ovulationsOffset: Int(laenge) - 14)
            }
            // Implausible length without a direct signal → no ovulation marking
        }
        if let np = naechstePeriode {
            fuegeZyklusHinzu(start: np, ovulationsOffset: persOvulationsOffset, extraVor: fensterExtra)
            if let np2 = kal.date(byAdding: .day, value: Int(round(adaptZyklusAngepasst)), to: np) {
                fuegeZyklusHinzu(start: np2, ovulationsOffset: persOvulationsOffset, extraVor: fensterExtra)
            }
        }

        // Symptothermalmethode: wässrig/Eiweiss confirms a fertile day; cremig
        // is a transitional sign and also opens the window (conservative).
        // Exclude post-period discharge: skip days within 3 days of the last period day.
        for eintrag in eintraege {
            let s = eintrag.zervixschleim.lowercased()
            if s == "wässrig" || s == "eiweiss" || s == "cremig" {
                let tag = kal.startOfDay(for: eintrag.datum)
                let d1 = kal.date(byAdding: .day, value: -1, to: tag)!
                let d2 = kal.date(byAdding: .day, value: -2, to: tag)!
                let d3 = kal.date(byAdding: .day, value: -3, to: tag)!
                let naheAnPeriode = periodeTageSet.contains(tag) ||
                                   periodeTageSet.contains(d1) ||
                                   periodeTageSet.contains(d2) ||
                                   periodeTageSet.contains(d3)
                if !naheAnPeriode { fruchtbarSet.insert(tag) }
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
            gelernterOvulationsOffset: ovulationsSignale.count >= 2 ? persOvulationsOffset : nil,
            adaptierteZykluslaenge: adaptZyklusAngepasst,
            adaptiertePeriodendauer: adaptPeriod,
            ovulationBestaetigt: aktuellerOvBestaetigt,
            ovulationVerzoegert: aktuellerOvVerzoegert,
            ovulationsUnsicherheit: aktuellerOvBestaetigt ? 0 : max(1, min(2, Int(variation.rounded()))),
            gelernteLutealphase: lutealTage
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

    // MARK: - BBT-Störtage (modulübergreifend)

    /// Tage, an denen die Basaltemperatur nicht verwertbar ist — der einzigartige
    /// PainDiary-Vorteil: wir wissen aus anderen Modulen, wann Messwerte gestört sind.
    /// - Alkohol am Vorabend (Wellness-Tracker, ≥ 2 Gläser)
    /// - deutlich zu kurzer Schlaf (< 4,5 h laut Tagebuch-Eintrag des Tages)
    static func bbtStoerTage(painEntries: [PainEntry]) -> Set<Date> {
        let kal = Calendar.current
        var tage: Set<Date> = []

        // Schlafmangel: schlafStunden bezieht sich auf die vergangene Nacht →
        // die Morgentemperatur DESSELBEN Tages ist unzuverlässig.
        for e in painEntries where e.schlafStunden > 0 && e.schlafStunden < 4.5 {
            tage.insert(kal.startOfDay(for: e.datum))
        }

        // Alkohol am Vorabend stört die Temperatur des Folgetags (letzte 90 Tage).
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let heute = kal.startOfDay(for: Date())
        for offset in 0..<90 {
            guard let tag = kal.date(byAdding: .day, value: -offset, to: heute),
                  let vortag = kal.date(byAdding: .day, value: -1, to: tag) else { continue }
            if UserDefaults.standard.integer(forKey: "alkoholGlaeser_\(df.string(from: vortag))") >= 2 {
                tage.insert(tag)
            }
        }
        return tage
    }

    // MARK: - Cycle start detection

    private static func findeZyklusStarts(aus tage: [Date]) -> [Date] {
        guard !tage.isEmpty else { return [] }
        let kal = Calendar.current
        var starts = [tage[0]]
        for i in 1..<tage.count {
            let diff = kal.dateComponents([.day], from: tage[i-1], to: tage[i]).day ?? 0
            // Lücken bis 5 Tage gehören zur selben Periode (vergessene Erfassung).
            // Zusätzlich: kein Zyklus ist kürzer als 21 Tage — Blutungen davor sind
            // Zwischen-/Ovulationsblutungen, kein neuer Zyklusstart.
            let seitStart = kal.dateComponents([.day], from: starts.last!, to: tage[i]).day ?? 0
            if diff > 5 && seitStart >= 21 { starts.append(tage[i]) }
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

    static func phase(for date: Date, analyse: ZyklusAnalyse) -> Zyklusphase? {
        guard !analyse.zyklusStarts.isEmpty else { return nil }
        let kal = Calendar.current
        let tag = kal.startOfDay(for: date)
        guard let start = analyse.zyklusStarts.last(where: { $0 <= tag }) else { return nil }
        let zt = (kal.dateComponents([.day], from: start, to: tag).day ?? 0) + 1
        let periodLen = Int(round(analyse.adaptiertePeriodendauer))
        let ovuOffset = analyse.gelernterOvulationsOffset ?? (Int(round(analyse.adaptierteZykluslaenge)) - 14)
        if zt <= periodLen          { return .menstruation }
        else if zt < ovuOffset - 2  { return .follikelphase }
        else if zt <= ovuOffset + 2 { return .ovulation }
        else                        { return .lutealphase }
    }

    static func migraeneJePhase(
        anfaelle: [MigraeneEintrag],
        analyse: ZyklusAnalyse
    ) -> [(phase: Zyklusphase, anzahl: Int, avgStaerke: Double)] {
        guard !analyse.zyklusStarts.isEmpty else { return [] }
        let kal = Calendar.current
        let ovuOffset = analyse.gelernterOvulationsOffset ?? (Int(round(analyse.adaptierteZykluslaenge)) - 14)
        let periodLen = Int(round(analyse.adaptiertePeriodendauer))
        var map: [Zyklusphase: [Int]] = Dictionary(uniqueKeysWithValues: Zyklusphase.allCases.map { ($0, []) })

        for anfall in anfaelle {
            let tag = kal.startOfDay(for: anfall.datum)
            guard let start = analyse.zyklusStarts.last(where: { $0 <= tag }) else { continue }
            let zt = (kal.dateComponents([.day], from: start, to: tag).day ?? 0) + 1
            let phase: Zyklusphase
            if zt <= periodLen         { phase = .menstruation }
            else if zt < ovuOffset - 2 { phase = .follikelphase }
            else if zt <= ovuOffset + 2 { phase = .ovulation }
            else                        { phase = .lutealphase }
            map[phase, default: []].append(anfall.staerke)
        }

        return Zyklusphase.allCases.compactMap { p in
            let w = map[p] ?? []
            guard !w.isEmpty else { return nil }
            return (p, w.count, Double(w.reduce(0, +)) / Double(w.count))
        }
    }
}
