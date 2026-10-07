import Foundation
import WidgetKit

/// Schreibt den aktuellen Zyklusstand in die App Group und stößt Widgets an.
enum ZyklusWidgetService {
    @MainActor
    static func aktualisieren(eintraege: [ZyklusEintrag], pausiert: Bool) {
        let kal = Calendar.current
        let heute = kal.startOfDay(for: Date())
        let analyse = ZyklusRechner.analyse(eintraege: eintraege)

        var snapshot = ZyklusWidgetSnapshot.leer
        snapshot.stand = Date()
        snapshot.prognosenPausiert = pausiert

        if !analyse.zyklusStarts.isEmpty, let zt = analyse.aktuellerZyklustag {
            snapshot.zyklustag = zt
            let phase = ZyklusRechner.phase(for: heute, analyse: analyse, kalender: kal)
            snapshot.phase = phase?.rawValue ?? ""
            snapshot.phaseSymbol = symbol(phase)
            snapshot.fruchtbar = !pausiert && analyse.fruchtbareTageSet.contains(heute)
            snapshot.eisprungBestaetigt = analyse.zyklen.last?.eisprungQuelle.istBestaetigt ?? false

            if let np = analyse.naechstePeriodeStart {
                snapshot.naechstePeriode = np
                snapshot.tageBisPeriode = kal.dateComponents([.day], from: heute, to: kal.startOfDay(for: np)).day
            }
            snapshot.statusText = statusText(snapshot, analyse: analyse, heute: heute, kal: kal)
        }
        snapshot.speichern()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func symbol(_ phase: ZyklusRechner.Zyklusphase?) -> String {
        switch phase {
        case .menstruation:   return "drop.fill"
        case .follikelphase:  return "leaf.fill"
        case .ovulation:      return "sparkles"
        case .lutealphase:    return "moon.fill"
        case .praemenstruell: return "cloud.moon.fill"
        case nil:             return "drop"
        }
    }

    private static func statusText(_ s: ZyklusWidgetSnapshot, analyse: ZyklusAnalyse, heute: Date, kal: Calendar) -> String {
        if s.prognosenPausiert { return "Prognosen pausiert" }
        if s.fruchtbar { return "Fruchtbar" }
        if let tage = s.tageBisPeriode {
            if tage < 0 { return "Periode \(-tage) \(-tage == 1 ? "Tag" : "Tage") überfällig" }
            if tage == 0 { return "Periode heute erwartet" }
            if tage == 1 { return "Periode morgen erwartet" }
            return "Periode in \(tage) Tagen"
        }
        return s.phase
    }
}
