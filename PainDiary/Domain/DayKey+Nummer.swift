import Foundation

/// Laufende Tagesnummer für Tagesarithmetik (Zyklus-Engine): Tage seit 1970-01-01 im proleptisch
/// gregorianischen Kalender. Reine Integer-Arithmetik (Howard Hinnants `days_from_civil`) — unabhängig von
/// Gerätezeitzone, Sommerzeit und Calendar-Einstellungen. Zwei aufeinanderfolgende Kalendertage
/// unterscheiden sich immer um genau 1.
extension DayKey {
    nonisolated var laufendeNummer: Int {
        let y = monat <= 2 ? jahr - 1 : jahr
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let mp = (monat + 9) % 12                       // März = 0 … Februar = 11
        let doy = (153 * mp + 2) / 5 + tag - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }

    nonisolated init(laufendeNummer nummer: Int) {
        let z = nummer + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1_460 + doe / 36_524 - doe / 146_096) / 365
        let y = yoe + era * 400
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        self.init(jahr: m <= 2 ? y + 1 : y, monat: m, tag: d)
    }
}
