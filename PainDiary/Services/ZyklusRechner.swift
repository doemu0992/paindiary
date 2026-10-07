import Foundation

// MARK: - Öffentliche Typen

enum Regelmaessigkeit {
    case unbekannt
    case regelmaessig
    case unregelmaessig

    var titel: String {
        switch self {
        case .unbekannt:      return "Noch unbekannt"
        case .regelmaessig:   return "Regelmäßig"
        case .unregelmaessig: return "Unregelmäßig"
        }
    }
}

enum DatenQualitaet: Int, Comparable {
    case standardwert = 0   // keine abgeschlossenen Zyklen: Lehrbuchwerte
    case wenigDaten         // 1–2 gültige Zyklen
    case gut                // 3–5 gültige Zyklen
    case sehrGut            // ≥ 6 gültige Zyklen

    static func < (a: DatenQualitaet, b: DatenQualitaet) -> Bool { a.rawValue < b.rawValue }

    var titel: String {
        switch self {
        case .standardwert: return "Schätzung (Standardwerte)"
        case .wenigDaten:   return "Wenig Daten"
        case .gut:          return "Gute Datenbasis"
        case .sehrGut:      return "Sehr gute Datenbasis"
        }
    }
}

/// Womit der Eisprung festgelegt wurde — in Prioritätsreihenfolge.
enum EisprungQuelle {
    case temperatur   // BBT-Anstieg (3-über-6-Regel) – rückblickend bestätigt
    case lhTest       // positiver LH-Test, Eisprung ≈ 1 Tag danach
    case schleim      // Peak-Tag des fruchtbaren Zervixschleims
    case kalender     // Schätzung: nächste Periode − Lutealphase

    var titel: String {
        switch self {
        case .temperatur: return "Temperatur bestätigt"
        case .lhTest:     return "LH-Test"
        case .schleim:    return "Zervixschleim"
        case .kalender:   return "Kalender-Schätzung"
        }
    }

    var istBestaetigt: Bool { self == .temperatur }
}

enum ZyklusStatus: Equatable {
    case normal
    case ueberfaellig(tage: Int)
    case keineAktuellenDaten   // letzter Zyklusstart > 90 Tage her
}

struct ZyklusInfo: Identifiable {
    var id: Date { start }
    let start: Date
    let naechsterStart: Date?
    let laenge: Int?
    let periodenTage: Int
    let eisprung: Date?
    let eisprungQuelle: EisprungQuelle
    let lutealLaenge: Int?
    let abgeschlossen: Bool
    let fuerStatistikGueltig: Bool
}

struct ZyklusAnalyse {
    // Bestehende API (von Dashboard, PDF, Korrelationen genutzt)
    let zykluslaenge: Double        // Ø aller gültigen Zyklen (Anzeige)
    let periodendauer: Double       // Ø der abgeschlossenen Perioden (Anzeige)
    let variation: Double           // Standardabweichung (Stichprobe, n−1)
    let aktuellerZyklustag: Int?
    let naechstePeriodeStart: Date?
    let vorhergesagteOvulation: Date?
    let zyklusStarts: [Date]
    let periodeTageSet: Set<Date>
    let fruchtbareTageSet: Set<Date>
    let ovulationsTageSet: Set<Date>
    /// Persönlicher Eisprung-Zyklustag (1-basiert), nil solange < 2 Zyklen mit Evidenz.
    let gelernterOvulationsOffset: Int?
    let adaptierteZykluslaenge: Double
    let adaptiertePeriodendauer: Double

    // Neu
    let medianZykluslaenge: Double
    let spanne: Int                 // längster − kürzester Zyklus (letzte 12)
    let gueltigeZyklen: Int
    let regelmaessigkeit: Regelmaessigkeit
    let datenQualitaet: DatenQualitaet
    let unsicherheitTage: Int       // ± Tage um die nächste Periode
    let naechstePeriodeFruehestens: Date?
    let naechstePeriodeSpaetestens: Date?
    let lutealphase: Int
    let lutealphaseGelernt: Bool
    let eisprungQuelle: EisprungQuelle?
    let eisprungBestaetigt: Bool
    let status: ZyklusStatus
    let hinweise: [String]
    let zyklen: [ZyklusInfo]
    let vorhergesagtePeriodeTageSet: Set<Date>
    let naechstesFruchtbaresFenster: ClosedRange<Date>?

    static func leerMitPeriodeTagen(_ periodeTage: Set<Date>) -> ZyklusAnalyse {
        ZyklusAnalyse(
            zykluslaenge: 28, periodendauer: 5, variation: 0,
            aktuellerZyklustag: nil, naechstePeriodeStart: nil,
            vorhergesagteOvulation: nil, zyklusStarts: [],
            periodeTageSet: periodeTage, fruchtbareTageSet: [], ovulationsTageSet: [],
            gelernterOvulationsOffset: nil,
            adaptierteZykluslaenge: 28, adaptiertePeriodendauer: 5,
            medianZykluslaenge: 28, spanne: 0, gueltigeZyklen: 0,
            regelmaessigkeit: .unbekannt, datenQualitaet: .standardwert,
            unsicherheitTage: 4,
            naechstePeriodeFruehestens: nil, naechstePeriodeSpaetestens: nil,
            lutealphase: ZyklusGrenzen.standardLutealphase, lutealphaseGelernt: false,
            eisprungQuelle: nil, eisprungBestaetigt: false,
            status: .normal, hinweise: [], zyklen: [],
            vorhergesagtePeriodeTageSet: [], naechstesFruchtbaresFenster: nil
        )
    }

    static let leer = ZyklusAnalyse.leerMitPeriodeTagen([])
}

struct ZyklusTagZustand {
    var periode: Bool = false
    var vorhergesagtePeriode: Bool = false
    var fruchtbar: Bool = false
    var ovulation: Bool = false
    var verbundenLinks: Bool = false
    var verbundenRechts: Bool = false
}

// MARK: - Rechner

/// Zyklus-Engine.
///
/// Konventionen (einheitlich im gesamten Modul):
/// - Ein „Tag" ist ein Kalendertag (Ordinalzahl in der Ära); intern wird nur mit Int-Tagesnummern gerechnet.
/// - **Zyklustag** ist 1-basiert: Tag 1 = erster Tag der Menstruationsblutung.
/// - **Eisprungtag** ist ein Datum. Die Lutealphase umfasst die Tage *nach* dem Eisprung bis zum Tag
///   vor der nächsten Periode: `Lutealphase = nächsterStart − Eisprung − 1`.
///   Beispiel 28-Tage-Zyklus, Lutealphase 14: Eisprung = Zyklustag 14, Lutealphase = Tag 15–28.
/// - Fruchtbares Fenster = 6 Tage bis einschließlich Eisprungtag (Wilcox et al., NEJM 1995).
struct ZyklusRechner {

    // MARK: - Cache

    private static var cache: (schluessel: Int, wert: ZyklusAnalyse)? = nil

    /// Fingerabdruck aller für die Analyse relevanten Felder. Auch für `onChange` nutzbar,
    /// weil Änderungen an bestehenden Einträgen das Array selbst nicht verändern.
    static func signatur(_ eintraege: [ZyklusEintrag]) -> Int {
        var h = Hasher()
        h.combine(eintraege.count)
        for e in eintraege {
            h.combine(e.datum)
            h.combine(e.istPeriode)
            h.combine(e.typ)
            h.combine(e.blutungsfluss)
            h.combine(e.zervixschleim)
            h.combine(e.ovulationstest)
            h.combine(e.basaltemperatur)
        }
        return h.finalize()
    }

    private struct Kontext {
        let kal: Calendar
        let heute: Date
        let heuteNr: Int

        init(kal: Calendar, heute: Date) {
            self.kal = kal
            self.heute = kal.startOfDay(for: heute)
            self.heuteNr = kal.ordinality(of: .day, in: .era, for: self.heute) ?? 0
        }

        func nr(_ datum: Date) -> Int {
            kal.ordinality(of: .day, in: .era, for: datum) ?? 0
        }

        func datum(_ nr: Int) -> Date {
            kal.date(byAdding: .day, value: nr - heuteNr, to: heute) ?? heute
        }
    }

    private struct TagesDaten {
        var nr: Int
        var blutung = false
        var menstruation = false
        var spotting = false
        var schleim: Zervixschleim = .keine
        var lh: LHTest = .keine
        var bbt: Double = 0
    }

    // MARK: - Main analysis

    static func analyse(eintraege: [ZyklusEintrag],
                        heute: Date = Date(),
                        kalender: Calendar = .current) -> ZyklusAnalyse {
        let ctx = Kontext(kal: kalender, heute: heute)
        var h = Hasher()
        h.combine(signatur(eintraege))
        h.combine(ctx.heute)
        h.combine(kalender.identifier)
        h.combine(kalender.timeZone.identifier)
        let schluessel = h.finalize()

        if let c = cache, c.schluessel == schluessel { return c.wert }
        let wert = berechne(tage: tagesDaten(aus: eintraege, ctx: ctx), ctx: ctx)
        cache = (schluessel, wert)
        return wert
    }

    private static func tagesDaten(aus eintraege: [ZyklusEintrag], ctx: Kontext) -> [Int: TagesDaten] {
        var map: [Int: TagesDaten] = [:]
        for e in eintraege.sorted(by: { $0.datum < $1.datum }) {
            let nr = ctx.nr(e.datum)
            var t = map[nr] ?? TagesDaten(nr: nr)
            if e.hatBlutung {
                t.blutung = true
                if e.fluss.istSpotting { t.spotting = true } else { t.menstruation = true }
            }
            let s = e.schleim
            if s != .keine { t.schleim = s }
            let l = e.lhTest
            if l == .positiv || t.lh != .positiv { t.lh = l == .keine ? t.lh : l }
            if ZyklusGrenzen.bbtBereich.contains(e.basaltemperatur) { t.bbt = e.basaltemperatur }
            map[nr] = t
        }
        return map
    }

    // MARK: Statistik-Helfer

    private static func median(_ werte: [Double]) -> Double {
        guard !werte.isEmpty else { return 0 }
        let s = werte.sorted()
        let m = s.count / 2
        return s.count % 2 == 0 ? (s[m - 1] + s[m]) / 2 : s[m]
    }

    /// Gewichteter Median; jüngere Werte (hinten im Array) zählen stärker (Gewicht = Position + 1).
    private static func gewichteterMedian(_ werte: [Double]) -> Double {
        let paare = werte.enumerated()
            .map { (wert: $0.element, gewicht: Double($0.offset + 1)) }
            .sorted { $0.wert < $1.wert }
        let gesamt = paare.reduce(0.0) { $0 + $1.gewicht }
        var kumuliert = 0.0
        for (i, p) in paare.enumerated() {
            kumuliert += p.gewicht
            if kumuliert > gesamt / 2 { return p.wert }
            if kumuliert == gesamt / 2 {
                return (p.wert + paare[min(i + 1, paare.count - 1)].wert) / 2
            }
        }
        return paare.last?.wert ?? 28
    }

    /// Prognostizierte Zykluslänge aus den bisherigen (gültigen) Längen, chronologisch.
    /// Wird von der Engine *und* von der Genauigkeits-Auswertung genutzt — eine Quelle der Wahrheit.
    static func prognoseLaenge(aus laengen: [Double]) -> Double {
        let r = Array(laengen.suffix(6))
        switch r.count {
        case 0:  return 28
        case 1:  return r[0]
        case 2:  return r[0] * 0.4 + r[1] * 0.6
        default: return gewichteterMedian(r)
        }
    }

    // MARK: Eisprung-Evidenz

    /// BBT-Verschiebung nach der 3-über-6-Regel: drei aufeinanderfolgende Tage über der höchsten der
    /// sechs vorhergehenden Messungen, der dritte ≥ 0,2 °C darüber. Eisprung ≈ Tag vor dem ersten hohen Wert.
    private static func bbtEisprung(_ tage: [TagesDaten]) -> Int? {
        let m = tage.filter { $0.bbt > 0 }
        guard m.count >= 9 else { return nil }
        for j in 6..<(m.count - 2) {
            let d1 = m[j], d2 = m[j + 1], d3 = m[j + 2]
            guard d2.nr - d1.nr == 1, d3.nr - d2.nr == 1 else { continue }
            guard d1.nr - m[j - 6].nr <= 9 else { continue }
            let abdeckung = m[(j - 6)..<j].map { $0.bbt }.max() ?? 0
            if d1.bbt > abdeckung, d2.bbt > abdeckung, d3.bbt >= abdeckung + 0.2 {
                return d1.nr - 1
            }
        }
        return nil
    }

    private static func berechne(tage: [Int: TagesDaten], ctx: Kontext) -> ZyklusAnalyse {
        let heuteNr = ctx.heuteNr
        let alleNrs = tage.keys.sorted()
        let blutungsNrs = alleNrs.filter { tage[$0]?.blutung == true }
        let periodeSet = Set(blutungsNrs.map { ctx.datum($0) })
        let flussNrs = alleNrs.filter { tage[$0]?.menstruation == true }
        guard !flussNrs.isEmpty else { return .leerMitPeriodeTagen(periodeSet) }

        // 1) Zyklusstarts: erster Tag einer Blutungsepisode (nur echte Blutung, kein Spotting).
        //    Lücken ≤ 7 Tage gehören zur selben Episode (vergessene Tage erzeugen keinen Fake-Zyklus);
        //    Episoden < 15 Tage nach dem letzten Start sind Zwischenblutungen.
        var starts: [Int] = []
        var vorherigerFluss: Int? = nil
        for n in flussNrs {
            if let v = vorherigerFluss, n - v <= 7 {
                // gleiche Episode
            } else if let s = starts.last, n - s < 15 {
                // Zwischenblutung — kein neuer Zyklus
            } else {
                starts.append(n)
            }
            vorherigerFluss = n
        }
        guard let letzterStart = starts.last else { return .leerMitPeriodeTagen(periodeSet) }

        /// Periodendauer: Spanne vom Start bis zum letzten Blutungstag der Kette (Lücken ≤ 2 Tage).
        func periodenSpanne(ab start: Int) -> Int {
            var letzter = start
            for n in flussNrs where n > start {
                if n - letzter <= 3 { letzter = n } else { break }
            }
            return min(letzter - start + 1, 14)
        }

        // 2) Zykluslängen: Plausibilitätsfilter + Ausreißer (MAD) ausschließen.
        var rohLaengen: [Int?] = []
        for i in starts.indices {
            rohLaengen.append(i + 1 < starts.count ? starts[i + 1] - starts[i] : nil)
        }
        let gueltigIdx = starts.indices.filter { i in
            rohLaengen[i].map { ZyklusGrenzen.gueltigeZyklusLaenge.contains($0) } ?? false
        }
        var bereinigtIdx = gueltigIdx
        if gueltigIdx.count >= 4 {
            let werte = gueltigIdx.compactMap { rohLaengen[$0] }.map { Double($0) }
            let medianRoh = median(werte)
            let mad = median(werte.map { abs($0 - medianRoh) })
            let grenze = max(10.0, 3 * 1.4826 * mad)
            bereinigtIdx = gueltigIdx.filter { i in
                guard let l = rohLaengen[i] else { return false }
                return abs(Double(l) - medianRoh) <= grenze
            }
        }
        let laengen: [Double] = bereinigtIdx.compactMap { rohLaengen[$0] }.map { Double($0) }
        let n = laengen.count
        let mittel = n == 0 ? 28.0 : laengen.reduce(0, +) / Double(n)
        let sd: Double = n >= 2
            ? sqrt(laengen.map { pow($0 - mittel, 2) }.reduce(0, +) / Double(n - 1))
            : 0
        let med = n == 0 ? 28.0 : median(laengen)
        let letzteLaengen = Array(laengen.suffix(12))
        let spanneWert = n >= 2 ? Int((letzteLaengen.max() ?? 0) - (letzteLaengen.min() ?? 0)) : 0
        // FIGO 2018: Variation ≤ 7–9 Tage = regelmäßig
        let regel: Regelmaessigkeit = n < 3 ? .unbekannt : (spanneWert <= 9 ? .regelmaessig : .unregelmaessig)
        let qualitaet: DatenQualitaet = n == 0 ? .standardwert : (n < 3 ? .wenigDaten : (n < 6 ? .gut : .sehrGut))

        let adaptZyklus = prognoseLaenge(aus: laengen)
        let zyklusLenInt = max(Int(adaptZyklus.rounded()), ZyklusGrenzen.gueltigeZyklusLaenge.lowerBound)

        // 3) Periodendauer: laufende (unvollständige) Periode zählt nicht in die Statistik.
        let periodeLaeuft = (flussNrs.last ?? 0) >= heuteNr - 1
        var periodDauern: [Double] = []
        for (i, s) in starts.enumerated() where !(i == starts.count - 1 && periodeLaeuft) {
            periodDauern.append(Double(periodenSpanne(ab: s)))
        }
        let avgPeriod = periodDauern.isEmpty ? 5.0 : periodDauern.reduce(0, +) / Double(periodDauern.count)
        let adaptPeriod: Double = {
            let r = Array(periodDauern.suffix(3))
            switch r.count {
            case 0:  return avgPeriod
            case 1:  return r[0]
            case 2:  return r[0] * 0.4 + r[1] * 0.6
            default: return r[0] * 0.2 + r[1] * 0.3 + r[2] * 0.5
            }
        }()

        // 4) Eisprung-Evidenz pro Zyklus: BBT > LH-Test > Schleim-Peak.
        func evidenz(start: Int, bisExklusiv: Int, periodenEnde: Int, naechsterStart: Int?)
            -> (nr: Int, quelle: EisprungQuelle)? {
            let imZyklus = alleNrs.filter { $0 >= start && $0 < bisExklusiv }.compactMap { tage[$0] }
            if let bbt = bbtEisprung(imZyklus) { return (bbt, .temperatur) }
            if let lh = imZyklus.first(where: { $0.lh == .positiv && $0.nr >= start + 3 }) {
                return (lh.nr + 1, .lhTest)
            }
            // Schleim: nur Tage ≥ 4 Tage nach Periodenende (Ausschluss von Restblutung/Ausfluss)
            let feucht = imZyklus.filter { $0.schleim.istFruchtbar && $0.nr > periodenEnde + 3 }.map { $0.nr }
            if let peak = feucht.max() {
                if let ns = naechsterStart {
                    if peak <= ns - 8 { return (peak, .schleim) }
                } else if heuteNr - peak >= 2 {
                    return (peak, .schleim)   // Peak abgeschlossen (≥ 2 Tage kein fertiler Schleim mehr)
                }
            }
            return nil
        }

        var evid: [Int: (nr: Int, quelle: EisprungQuelle)] = [:]
        var lutealWerte: [Int] = []
        for i in starts.indices {
            let naechster: Int? = i + 1 < starts.count ? starts[i + 1] : nil
            let ende = naechster ?? (heuteNr + 1)
            let pEnde = starts[i] + periodenSpanne(ab: starts[i]) - 1
            guard let e = evidenz(start: starts[i], bisExklusiv: ende, periodenEnde: pEnde, naechsterStart: naechster) else { continue }
            if let ns = naechster {
                let l = ns - e.nr - 1
                guard ZyklusGrenzen.gueltigeLutealphase.contains(l) else { continue }
                lutealWerte.append(l)
            }
            evid[i] = e
        }
        let lutealGelernt = lutealWerte.count >= 2
        let luteal = lutealGelernt
            ? Int(median(lutealWerte.map { Double($0) }).rounded())
            : ZyklusGrenzen.standardLutealphase

        // 5) Status
        let naechstePeriodeNr = letzterStart + zyklusLenInt
        let zyklustagHeute = heuteNr - letzterStart + 1
        let status: ZyklusStatus
        if zyklustagHeute > 91 {
            status = .keineAktuellenDaten
        } else if heuteNr > naechstePeriodeNr {
            status = .ueberfaellig(tage: heuteNr - naechstePeriodeNr)
        } else {
            status = .normal
        }
        let hatPrognose = status != .keineAktuellenDaten && zyklustagHeute >= 1

        let unsicherheit: Int = n >= 3
            ? min(max(Int(sd.rounded(.up)), 1), 7)
            : (n == 0 ? 4 : 3)

        // Kalendermethode (nur bei unregelmäßigem Zyklus): frühester fertiler Tag = kürzester − 18,
        // spätester = längster − 11 (Zyklustage, 1-basiert).
        let kalenderFenster: (kurz: Int, lang: Int)?
        if regel == .unregelmaessig, let k = letzteLaengen.min(), let l = letzteLaengen.max() {
            kalenderFenster = (Int(k), Int(l))
        } else {
            kalenderFenster = nil
        }

        func fenster(start: Int, ov: Int, eng: Bool) -> ClosedRange<Int> {
            if eng { return (ov - 5)...ov }
            if let k = kalenderFenster {
                let von = min(start + k.kurz - 18 - 1, ov - 5)
                let bis = max(start + k.lang - 11 - 1, ov)
                return von...bis
            }
            let d = (regel == .regelmaessig && qualitaet >= .gut) ? 1 : 2
            return (ov - 5 - d)...(ov + d)
        }

        // 6) Zyklen aufbauen
        var infos: [ZyklusInfo] = []
        var fruchtbarNrs = Set<Int>()
        var ovNrs = Set<Int>()
        var aktuellerEisprungNr: Int? = nil
        var aktuelleQuelle: EisprungQuelle? = nil

        for i in starts.indices {
            let s = starts[i]
            let naechster: Int? = i + 1 < starts.count ? starts[i + 1] : nil
            let pT = periodenSpanne(ab: s)
            let pEnde = s + pT - 1
            var ov: Int
            var quelle: EisprungQuelle
            var eng = true

            if let e = evid[i] {
                ov = e.nr
                quelle = e.quelle
                eng = e.quelle == .temperatur || e.quelle == .lhTest || naechster != nil
            } else if let ns = naechster {
                ov = ns - (luteal + 1)
                quelle = .kalender
            } else {
                ov = naechstePeriodeNr - (luteal + 1)
                quelle = .kalender
                eng = false
                // Fertiler Schleim kurz vor/um den prognostizierten Eisprung: Eisprung nicht vor dem letzten feuchten Tag.
                let feucht = alleNrs
                    .filter { $0 >= s && $0 > pEnde + 3 && tage[$0]?.schleim.istFruchtbar == true }
                if let w = feucht.max(), w > ov {
                    ov = w
                    quelle = .schleim
                }
            }
            ov = max(ov, s + 5)

            let istAktuell = naechster == nil
            if istAktuell {
                aktuellerEisprungNr = ov
                aktuelleQuelle = quelle
            }
            let ueberspringen = istAktuell && !hatPrognose
            if !ueberspringen {
                ovNrs.insert(ov)
                for t in fenster(start: s, ov: ov, eng: eng) { fruchtbarNrs.insert(t) }
            }

            infos.append(ZyklusInfo(
                start: ctx.datum(s),
                naechsterStart: naechster.map { ctx.datum($0) },
                laenge: naechster.map { $0 - s },
                periodenTage: pT,
                eisprung: ueberspringen ? nil : ctx.datum(ov),
                eisprungQuelle: quelle,
                lutealLaenge: naechster.map { $0 - ov - 1 },
                abgeschlossen: naechster != nil,
                fuerStatistikGueltig: bereinigtIdx.contains(i)
            ))
        }

        // 7) Zukünftige Zyklen (nur mit aktueller Datenlage). Überfällige Periode: frühestens heute.
        var vorhergesagtePeriodeNrs = Set<Int>()
        var naechsteOvNr: Int? = nil
        if hatPrognose {
            let anker = max(naechstePeriodeNr, heuteNr)
            let periodLen = max(Int(adaptPeriod.rounded()), 3)
            for k in 0..<4 {   // 4 künftige Zyklen → Kalender bleibt ~4 Monate voraus befüllt
                let start = anker + k * zyklusLenInt
                let ov = max(start + zyklusLenInt - (luteal + 1), start + 5)
                ovNrs.insert(ov)
                for t in fenster(start: start, ov: ov, eng: false) { fruchtbarNrs.insert(t) }
                for d in 0..<periodLen { vorhergesagtePeriodeNrs.insert(start + d) }
                if k == 0 { naechsteOvNr = ov }
            }
        }

        // 8) Beobachtungen: fertiler Schleim und LH-Test machen den Tag selbst fertil.
        let blutungsSet = Set(blutungsNrs)
        for nr in alleNrs {
            guard let t = tage[nr] else { continue }
            if t.schleim.istFruchtbar {
                let nahePeriode = adaptZyklus >= 24 && (0...3).contains { blutungsSet.contains(nr - $0) }
                if !nahePeriode { fruchtbarNrs.insert(nr) }
            }
            if t.lh == .positiv {
                fruchtbarNrs.insert(nr)
                fruchtbarNrs.insert(nr + 1)
            }
        }

        // 9) Anzeige-Größen
        let vorhergesagteOv: Date? = {
            guard hatPrognose else { return nil }
            if let cur = aktuellerEisprungNr, cur >= heuteNr { return ctx.datum(cur) }
            return naechsteOvNr.map { ctx.datum($0) }
        }()

        var naechstesFenster: ClosedRange<Date>? = nil
        let zukunft = fruchtbarNrs.filter { $0 >= heuteNr }.sorted()
        if hatPrognose, let erster = zukunft.first {
            var ende = erster
            for t in zukunft.dropFirst() {
                if t - ende <= 1 { ende = t } else { break }
            }
            naechstesFenster = ctx.datum(erster)...ctx.datum(ende)
        }

        var hinweise: [String] = []
        if n >= 3 {
            if adaptZyklus < 24 {
                hinweise.append("Deine Zyklen sind kurz (unter 24 Tage). Halten sie an oder treten Beschwerden auf, lass das ärztlich abklären.")
            } else if adaptZyklus > 38 {
                hinweise.append("Deine Zyklen sind lang (über 38 Tage). Halten sie an oder treten Beschwerden auf, lass das ärztlich abklären.")
            }
            if regel == .unregelmaessig {
                hinweise.append("Deine Zykluslänge schwankt um mehr als 9 Tage. Prognosen sind dadurch ungenauer; das fruchtbare Fenster wird breiter angezeigt.")
            }
        }
        if periodDauern.count >= 2 && avgPeriod > 8 {
            hinweise.append("Deine Periode dauert im Schnitt länger als 8 Tage. Bei starken Blutungen oder Beschwerden bitte ärztlich abklären.")
        }
        if case .ueberfaellig(let t) = status, t >= 7 {
            hinweise.append("Deine Periode ist seit \(t) Tagen überfällig. Mögliche Ursachen sind u. a. Stress, Zyklusschwankungen oder eine Schwangerschaft.")
        }

        let aktuellerTag: Int? = (zyklustagHeute >= 1 && zyklustagHeute <= 91) ? zyklustagHeute : nil

        return ZyklusAnalyse(
            zykluslaenge: mittel,
            periodendauer: avgPeriod,
            variation: sd,
            aktuellerZyklustag: aktuellerTag,
            naechstePeriodeStart: hatPrognose ? ctx.datum(naechstePeriodeNr) : nil,
            vorhergesagteOvulation: vorhergesagteOv,
            zyklusStarts: starts.map { ctx.datum($0) },
            periodeTageSet: periodeSet,
            fruchtbareTageSet: Set(fruchtbarNrs.map { ctx.datum($0) }),
            ovulationsTageSet: Set(ovNrs.map { ctx.datum($0) }),
            gelernterOvulationsOffset: lutealGelernt ? max(zyklusLenInt - luteal, 1) : nil,
            adaptierteZykluslaenge: adaptZyklus,
            adaptiertePeriodendauer: adaptPeriod,
            medianZykluslaenge: med,
            spanne: spanneWert,
            gueltigeZyklen: n,
            regelmaessigkeit: regel,
            datenQualitaet: qualitaet,
            unsicherheitTage: unsicherheit,
            naechstePeriodeFruehestens: hatPrognose ? ctx.datum(naechstePeriodeNr - unsicherheit) : nil,
            naechstePeriodeSpaetestens: hatPrognose ? ctx.datum(naechstePeriodeNr + unsicherheit) : nil,
            lutealphase: luteal,
            lutealphaseGelernt: lutealGelernt,
            eisprungQuelle: aktuelleQuelle,
            eisprungBestaetigt: aktuelleQuelle?.istBestaetigt ?? false,
            status: status,
            hinweise: hinweise,
            zyklen: infos,
            vorhergesagtePeriodeTageSet: Set(vorhergesagtePeriodeNrs.map { ctx.datum($0) }),
            naechstesFruchtbaresFenster: naechstesFenster
        )
    }

    // MARK: - Tag state

    static func tagZustand(datum: Date, analyse: ZyklusAnalyse, kalender: Calendar = .current) -> ZyklusTagZustand {
        let kal = kalender
        let tag = kal.startOfDay(for: datum)
        var z = ZyklusTagZustand()

        if analyse.periodeTageSet.contains(tag) {
            z.periode = true
            if let vortag = kal.date(byAdding: .day, value: -1, to: tag),
               let morgen = kal.date(byAdding: .day, value: 1, to: tag) {
                z.verbundenLinks = analyse.periodeTageSet.contains(vortag)
                z.verbundenRechts = analyse.periodeTageSet.contains(morgen)
            }
        }

        if !z.periode && analyse.vorhergesagtePeriodeTageSet.contains(tag) { z.vorhergesagtePeriode = true }
        if !z.periode && analyse.fruchtbareTageSet.contains(tag) { z.fruchtbar = true }
        if analyse.ovulationsTageSet.contains(tag) { z.ovulation = true }

        return z
    }

    // MARK: - Phasen

    enum Zyklusphase: String, CaseIterable {
        case menstruation = "Menstruation"
        case follikelphase = "Follikelphase"
        case ovulation = "Ovulation"
        case lutealphase = "Lutealphase"
        case praemenstruell = "Prämenstruell"
    }

    /// Phase eines Tages anhand des *tatsächlichen* Verlaufs des jeweiligen Zyklus
    /// (echte Periodendauer, bestätigter/geschätzter Eisprung, echte Zykluslänge).
    /// nil: vor dem ersten Zyklus oder weit jenseits des plausiblen Zyklusendes.
    static func phase(for date: Date, analyse: ZyklusAnalyse, kalender: Calendar = .current) -> Zyklusphase? {
        let kal = kalender
        let tag = kal.startOfDay(for: date)
        guard let info = analyse.zyklen.last(where: { $0.start <= tag }) else { return nil }
        let zt = (kal.dateComponents([.day], from: info.start, to: tag).day ?? 0) + 1
        let laenge = info.laenge ?? max(Int(analyse.adaptierteZykluslaenge.rounded()), 15)

        if info.naechsterStart == nil && (zt > laenge + 14 || zt > 90) { return nil }
        if zt <= info.periodenTage { return .menstruation }

        let ovZt: Int
        if let ov = info.eisprung {
            ovZt = (kal.dateComponents([.day], from: info.start, to: ov).day ?? 0) + 1
        } else {
            ovZt = laenge - analyse.lutealphase
        }
        if zt < ovZt - 1 { return .follikelphase }
        if zt <= ovZt + 1 { return .ovulation }
        if zt > laenge - 3 { return .praemenstruell }
        return .lutealphase
    }

    /// Perimenstruelles Fenster nach ICHD-3 (Menstruationsmigräne): Tag −2 bis +3 um den Blutungsbeginn.
    static func istPerimenstruell(_ date: Date, analyse: ZyklusAnalyse, kalender: Calendar = .current) -> Bool {
        let tag = kalender.startOfDay(for: date)
        return analyse.zyklusStarts.contains { start in
            let d = kalender.dateComponents([.day], from: start, to: tag).day ?? 99
            return (-2...3).contains(d)
        }
    }

    static func perimenstruelleAnfaelle(anfaelle: [MigraeneEintrag], analyse: ZyklusAnalyse) -> (imFenster: Int, gesamt: Int) {
        guard !analyse.zyklusStarts.isEmpty else { return (0, 0) }
        let treffer = anfaelle.filter { istPerimenstruell($0.datum, analyse: analyse) }.count
        return (treffer, anfaelle.count)
    }

    // MARK: - Pain–cycle correlation

    /// Durchschnittlicher Schmerz je Phase. Aggregiert pro Tag (kein Mehrfachgewicht bei mehreren
    /// Einträgen) und ignoriert Einträge ohne Schmerzwert (z. B. Haut).
    static func schmerzJePhase(
        painEntries: [PainEntry],
        analyse: ZyklusAnalyse
    ) -> [(phase: Zyklusphase, avgSchmerz: Double, anzahl: Int)] {
        guard !analyse.zyklusStarts.isEmpty else { return [] }
        let kal = Calendar.current
        var proTag: [Date: [Int]] = [:]
        for e in painEntries where e.schmerzstaerke > 0 {
            proTag[kal.startOfDay(for: e.datum), default: []].append(e.schmerzstaerke)
        }
        var map: [Zyklusphase: [Double]] = [:]
        for (tag, werte) in proTag {
            guard let p = phase(for: tag, analyse: analyse, kalender: kal) else { continue }
            map[p, default: []].append(Double(werte.reduce(0, +)) / Double(werte.count))
        }
        return Zyklusphase.allCases.compactMap { p in
            guard let w = map[p], !w.isEmpty else { return nil }
            return (phase: p, avgSchmerz: w.reduce(0, +) / Double(w.count), anzahl: w.count)
        }
    }

    static func migraeneJePhase(
        anfaelle: [MigraeneEintrag],
        analyse: ZyklusAnalyse
    ) -> [(phase: Zyklusphase, anzahl: Int, avgStaerke: Double)] {
        guard !analyse.zyklusStarts.isEmpty else { return [] }
        let kal = Calendar.current
        var map: [Zyklusphase: [Int]] = [:]
        for anfall in anfaelle {
            guard let p = phase(for: anfall.datum, analyse: analyse, kalender: kal) else { continue }
            map[p, default: []].append(anfall.staerke)
        }
        return Zyklusphase.allCases.compactMap { p in
            guard let w = map[p], !w.isEmpty else { return nil }
            return (phase: p, anzahl: w.count, avgStaerke: Double(w.reduce(0, +)) / Double(w.count))
        }
    }
}
