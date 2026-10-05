import Foundation
import SwiftData

/// Zentrale Löschlogik: räumt **vor** dem Löschen Benachrichtigungen und Dateien auf (siehe CLAUDE.md „Löschen-Standard").
/// Alle Views löschen über diesen Service statt direkt über `modelContext.delete`.
@MainActor
struct EintragLoeschService {
    let context: ModelContext
    var benachrichtigungen: NotificationManager = .shared

    func loesche(_ eintrag: PainEntry) {
        if eintrag.istHautEintrag, !eintrag.fotoDateiname.isEmpty {
            FotoManager.loeschen(dateiname: eintrag.fotoDateiname)
        }
        context.delete(eintrag)
    }

    func loesche(_ anfall: MigraeneEintrag) {
        benachrichtigungen.loescheMigraeneErinnerungen(fuer: anfall.datum)
        context.delete(anfall)
    }

    func loesche(_ med: Dauermedikation) {
        benachrichtigungen.loescheErinnerungen(fuer: med)
        context.delete(med)
    }

    func loesche(_ injektion: BiologikaInjektion) {
        benachrichtigungen.loescheBiologikaErinnerung(injektion: injektion)
        context.delete(injektion)
    }

    func loesche(_ log: EinnahmeLog) {
        benachrichtigungen.loescheWirkungsAbfrage(fuer: log)
        context.delete(log)
    }
}
