import Foundation
import Observation

/// Bereitet die Schmerz-Einträge für das Dashboard auf. Rechnet über `SchmerzUebersicht` (Domain),
/// die View enthält keine Berechnungslogik.
@Observable
@MainActor
final class SchmerzDashboardViewModel {
    private(set) var uebersicht = SchmerzUebersicht()

    func aktualisiere(eintraege: [PainEntry], jetzt: Date = Date()) {
        let punkte = eintraege
            .filter { $0.eintragsArt == .schmerz }
            .map {
                SchmerzMesspunkt(
                    datum: $0.datum,
                    tag: $0.tag,
                    staerke: $0.schmerzstaerke,
                    istSchub: $0.istSchub,
                    orte: $0.koerperstellenListe
                )
            }
        uebersicht = SchmerzUebersicht.berechne(punkte: punkte, heute: DayKey.heute(jetzt: jetzt))
    }
}
