import Foundation
import Observation

@Observable
@MainActor
final class MigraeneDashboardViewModel {
    private(set) var uebersicht = MigraeneUebersicht()

    func aktualisiere(anfaelle: [MigraeneEintrag], jetzt: Date = Date()) {
        let punkte = anfaelle.map {
            MigraeneMesspunkt(
                datum: $0.datum, tag: $0.tag, staerke: $0.staerke, dauerMinuten: $0.dauer,
                ausloeser: $0.ausloeserListe, nahmAkutmedikament: !$0.akutmedikament.isEmpty
            )
        }
        uebersicht = MigraeneUebersicht.berechne(punkte: punkte, heute: DayKey.heute(jetzt: jetzt))
    }
}
