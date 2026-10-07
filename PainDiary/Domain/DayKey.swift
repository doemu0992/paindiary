import Foundation

/// Kalendertag ohne Zeitzonen-Bezug (yyyy-MM-dd).
///
/// Löst das Problem, dass ein absoluter Zeitpunkt (`Date`) je nach Zeitzone des Geräts
/// einem anderen Tag zugeordnet wird. Ein Eintrag wird mit seiner Erfassungs-Zeitzone
/// einem `DayKey` zugeordnet, danach ist der Tag stabil (Reisen, Sync, Zeitumstellung).
nonisolated struct DayKey: Hashable, Comparable, Codable, Sendable {
    let jahr: Int
    let monat: Int
    let tag: Int

    init(jahr: Int, monat: Int, tag: Int) {
        self.jahr = jahr
        self.monat = monat
        self.tag = tag
    }

    /// Tag eines Zeitpunkts in der angegebenen Zeitzone.
    init(_ datum: Date, zeitzone: TimeZone = .current) {
        var kal = Calendar(identifier: .gregorian)
        kal.timeZone = zeitzone
        let c = kal.dateComponents([.year, .month, .day], from: datum)
        self.init(jahr: c.year ?? 1970, monat: c.month ?? 1, tag: c.day ?? 1)
    }

    /// Kompakte Darstellung `yyyyMMdd` (z. B. 20261005). `nil` bei ungültigem Wert.
    init?(wert: Int) {
        let j = wert / 10_000
        let m = (wert / 100) % 100
        let t = wert % 100
        guard j >= 1900, (1...12).contains(m), (1...31).contains(t) else { return nil }
        self.init(jahr: j, monat: m, tag: t)
    }

    var wert: Int { jahr * 10_000 + monat * 100 + tag }

    /// Beginn dieses Tages in der angegebenen Zeitzone.
    func beginn(in zeitzone: TimeZone = .current) -> Date {
        var kal = Calendar(identifier: .gregorian)
        kal.timeZone = zeitzone
        let c = DateComponents(year: jahr, month: monat, day: tag)
        return kal.date(from: c) ?? Date(timeIntervalSince1970: 0)
    }

    /// Verschiebt um `tage` Kalendertage (zeitzonen- und sommerzeitunabhängig).
    func addiere(tage: Int) -> DayKey {
        var kal = Calendar(identifier: .gregorian)
        kal.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        // Mittag, damit keine Randeffekte entstehen
        let basis = kal.date(from: DateComponents(year: jahr, month: monat, day: tag, hour: 12)) ?? Date(timeIntervalSince1970: 0)
        let neu = kal.date(byAdding: .day, value: tage, to: basis) ?? basis
        let c = kal.dateComponents([.year, .month, .day], from: neu)
        return DayKey(jahr: c.year ?? jahr, monat: c.month ?? monat, tag: c.day ?? tag)
    }

    /// Anzahl Kalendertage von `self` bis `anderer` (negativ, wenn `anderer` früher liegt).
    func tage(bis anderer: DayKey) -> Int {
        var kal = Calendar(identifier: .gregorian)
        kal.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let a = kal.date(from: DateComponents(year: jahr, month: monat, day: tag, hour: 12)) ?? Date(timeIntervalSince1970: 0)
        let b = kal.date(from: DateComponents(year: anderer.jahr, month: anderer.monat, day: anderer.tag, hour: 12)) ?? a
        return Int((b.timeIntervalSince(a) / 86_400).rounded())
    }

    static func < (l: DayKey, r: DayKey) -> Bool { l.wert < r.wert }

    /// Heute in der aktuellen Zeitzone.
    static func heute(zeitzone: TimeZone = .current, jetzt: Date = Date()) -> DayKey {
        DayKey(jetzt, zeitzone: zeitzone)
    }
}
