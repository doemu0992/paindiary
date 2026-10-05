import Foundation
import Observation

/// Aufbereitete Kennzahlen für den Heute-Screen. Rechnet über die Domain-Statistik (zeitzonensicher per `DayKey`),
/// die View enthält keine Berechnungslogik mehr.
@Observable
@MainActor
final class HeuteViewModel {

    struct WochenPunkt: Identifiable, Equatable {
        let datum: Date
        let wert: Double
        var id: Date { datum }
    }

    private(set) var heuteSchnitt: Double?
    private(set) var heuteAnzahl = 0
    private(set) var wocheDaten: [WochenPunkt] = []
    private(set) var trend: TrendErgebnis?
    private(set) var schubHinweis: SchubHinweis?
    private(set) var uebergebrauch: UebergebrauchStatus?

    /// Kurztext zum Wochentrend (z. B. „↓ 0.8 zur Vorwoche").
    var trendText: String? {
        guard let t = trend else { return nil }
        if abs(t.differenz) < 0.05 { return "= wie letzte Woche" }
        return "\(t.differenz < 0 ? "↓" : "↑") \(String(format: "%.1f", abs(t.differenz))) zur Vorwoche"
    }

    func aktualisiere(eintraege: [PainEntry], migraene: [MigraeneEintrag] = [], jetzt: Date = Date()) {
        let heute = DayKey.heute(jetzt: jetzt)
        let schmerz = eintraege.filter { $0.eintragsArt == .schmerz }
        let reihe = Statistik.tagesDurchschnitte(schmerz.map { (tag: $0.tag, wert: Double($0.schmerzstaerke)) })

        heuteSchnitt = reihe.first { $0.tag == heute }?.wert
        heuteAnzahl = schmerz.filter { $0.tag == heute }.count

        let wochenStart = heute.addiere(tage: -6)
        wocheDaten = reihe
            .filter { $0.tag >= wochenStart && $0.tag <= heute }
            .map { WochenPunkt(datum: $0.tag.beginn(), wert: $0.wert) }

        trend = Statistik.trend(reihe, heute: heute, tage: 7)
        schubHinweis = SchubErkennung.pruefe(reihe, heute: heute)

        // Akutmedikation (Migräne): Hinweis bei zu vielen Einnahmetagen im Monat
        let einnahmeTage = migraene.filter { !$0.akutmedikament.isEmpty }.map(\.tag)
        uebergebrauch = einnahmeTage.isEmpty ? nil : Uebergebrauch.pruefe(einnahmeTage: einnahmeTage, heute: heute)
    }
}
