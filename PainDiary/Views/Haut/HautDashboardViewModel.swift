import Foundation
import Observation

@Observable
@MainActor
final class HautDashboardViewModel {
    private(set) var uebersicht = HautUebersicht()

    func aktualisiere(eintraege: [PainEntry], jetzt: Date = Date()) {
        let punkte = eintraege
            .filter { $0.eintragsArt == .haut }
            .map { HautMesspunkt(datum: $0.datum, tag: $0.tag, stellen: ListenFeld.parse($0.hautStellen), arten: ListenFeld.parse($0.hautArt)) }
        uebersicht = HautUebersicht.berechne(punkte: punkte, heute: DayKey.heute(jetzt: jetzt))
    }
}
