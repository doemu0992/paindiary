import Foundation
import Observation

/// Bereitet Medikamente und Einnahme-Logs für das Dashboard auf (Tagesring, Adherenz, Streak).
@Observable
@MainActor
final class MedikamenteDashboardViewModel {
    private(set) var uebersicht = MedikationsUebersicht()

    func aktualisiere(medikamente: [Dauermedikation], logs: [EinnahmeLog], notif: NotificationManager? = nil, jetzt: Date = Date()) {
        let notif = notif ?? NotificationManager.shared
        let aktive = medikamente.filter(\.aktiv)
        let plan = aktive.map { MedikationsPlanEintrag(id: $0.notifID, dosenProTag: notif.anzahlDosen($0.frequenz)) }
        let einnahmen = logs.filter(\.eingenommen).map { log in
            EinnahmePunkt(
                medikamentID: aktive.first(where: { log.gehoertZu($0) })?.notifID ?? "",
                tag: DayKey(log.datum)
            )
        }
        uebersicht = MedikationsUebersicht.berechne(plan: plan, einnahmen: einnahmen, heute: DayKey.heute(jetzt: jetzt))
    }
}
