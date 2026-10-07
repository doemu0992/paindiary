import Foundation
import WidgetKit
import ActivityKit

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
        liveActivityAktualisieren(snapshot)
    }

    // MARK: - Live Activity (Sperrbildschirm / Dynamic Island)

    /// Läuft nur an Tagen mit Anlass: fruchtbares Fenster oder Periode heute/morgen erwartet.
    /// ActivityKit erlaubt das Starten nur im Vordergrund — daher beim Öffnen/Ändern in der App.
    private static func liveActivityAktualisieren(_ s: ZyklusWidgetSnapshot) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        var art: String? = nil
        var inhalt: ZyklusLiveAttributes.ContentState? = nil
        if let tag = s.zyklustag, !s.prognosenPausiert {
            if s.fruchtbar {
                art = "fruchtbar"
                inhalt = .init(titel: "Fruchtbares Fenster",
                               detail: s.eisprungBestaetigt ? "Eisprung bestätigt" : "Eisprung geschätzt",
                               symbol: "sparkles", zyklustag: tag)
            } else if let t = s.tageBisPeriode, t >= 0, t <= 1 {
                art = "periode"
                inhalt = .init(titel: t == 0 ? "Periode heute erwartet" : "Periode morgen erwartet",
                               detail: "Prognose, kann abweichen", symbol: "drop.fill", zyklustag: tag)
            }
        }

        let laufende = Activity<ZyklusLiveAttributes>.activities
        guard let art, let inhalt else {
            for a in laufende { Task { await a.end(nil, dismissalPolicy: .immediate) } }
            return
        }
        let ende = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
        let inhaltMitAblauf = ActivityContent(state: inhalt, staleDate: ende)

        if let vorhanden = laufende.first(where: { $0.attributes.art == art }) {
            Task { await vorhanden.update(inhaltMitAblauf) }
            for a in laufende where a.id != vorhanden.id { Task { await a.end(nil, dismissalPolicy: .immediate) } }
        } else {
            for a in laufende { Task { await a.end(nil, dismissalPolicy: .immediate) } }
            _ = try? Activity.request(attributes: ZyklusLiveAttributes(art: art), content: inhaltMitAblauf)
        }
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
