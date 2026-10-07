import Foundation
import Observation

@Observable
@MainActor
final class DiabetesDashboardViewModel {
    private(set) var uebersicht = DiabetesUebersicht()

    func aktualisiere(messungen: [BlutzuckerEintrag], jetzt: Date = Date()) {
        let punkte = messungen.map {
            BlutzuckerMesspunkt(
                datum: $0.datum, tag: $0.tag, wert: $0.wert, messZeitpunkt: $0.messZeitpunkt,
                insulinEinheiten: $0.insulinEinheiten, bewertung: $0.bewertung
            )
        }
        uebersicht = DiabetesUebersicht.berechne(punkte: punkte, heute: DayKey.heute(jetzt: jetzt))
    }
}
