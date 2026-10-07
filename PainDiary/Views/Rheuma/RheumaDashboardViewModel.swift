import Foundation
import Observation

@Observable
@MainActor
final class RheumaDashboardViewModel {
    private(set) var uebersicht = RheumaUebersicht()

    func aktualisiere(eintraege: [PainEntry], jetzt: Date = Date()) {
        let punkte = eintraege
            .filter { $0.eintragsArt == .rheuma }
            .map {
                RheumaMesspunkt(datum: $0.datum, tag: $0.tag, staerke: $0.schmerzstaerke,
                                istSchub: $0.istSchub, morgensteifigkeit: $0.morgensteifigkeit)
            }
        uebersicht = RheumaUebersicht.berechne(punkte: punkte, heute: DayKey.heute(jetzt: jetzt))
    }
}
