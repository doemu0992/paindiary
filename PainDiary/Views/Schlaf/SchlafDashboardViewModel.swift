import Foundation
import Observation

@Observable
@MainActor
final class SchlafDashboardViewModel {
    private(set) var uebersicht = SchlafUebersicht()

    func aktualisiere(naechte: [SleepNightSummary], jetzt: Date = Date()) {
        let punkte = naechte.map {
            SchlafMesspunkt(
                datum: $0.date, tag: DayKey($0.date), qualitaet: $0.qualitaet,
                dauerStunden: $0.dauerStunden, tiefAnteil: $0.tiefPct, remAnteil: $0.remPct
            )
        }
        uebersicht = SchlafUebersicht.berechne(punkte: punkte, heute: DayKey.heute(jetzt: jetzt))
    }
}
