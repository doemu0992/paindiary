import Foundation

/// Datenbrücke App → Widget/Live Activity (über die App Group).
/// Diese Datei muss in BEIDEN Targets liegen (PainDiary + Widget-Extension, Target Membership).
/// Enthält bewusst keine SwiftData-/UI-Abhängigkeiten.
nonisolated struct ZyklusWidgetSnapshot: Codable, Equatable {
    static let gruppe = "group.com.doemu0992.sleepbuddy"
    static let schluessel = "zyklusWidgetSnapshot"

    var stand: Date
    var zyklustag: Int?
    var phase: String            // Rohwert der Zyklusphase, "" = unbekannt
    var phaseSymbol: String
    var statusText: String       // z. B. „Fruchtbar · Eisprung in 2 Tagen"
    var naechstePeriode: Date?
    var tageBisPeriode: Int?
    var fruchtbar: Bool
    var eisprungBestaetigt: Bool
    var prognosenPausiert: Bool

    static let leer = ZyklusWidgetSnapshot(
        stand: .distantPast, zyklustag: nil, phase: "", phaseSymbol: "drop",
        statusText: "Noch keine Daten", naechstePeriode: nil, tageBisPeriode: nil,
        fruchtbar: false, eisprungBestaetigt: false, prognosenPausiert: false)

    static func laden() -> ZyklusWidgetSnapshot {
        guard let defaults = UserDefaults(suiteName: gruppe),
              let daten = defaults.data(forKey: schluessel),
              let s = try? JSONDecoder().decode(ZyklusWidgetSnapshot.self, from: daten) else { return .leer }
        return s
    }

    func speichern() {
        guard let defaults = UserDefaults(suiteName: Self.gruppe),
              let daten = try? JSONEncoder().encode(self) else { return }
        defaults.set(daten, forKey: Self.schluessel)
    }
}

#if canImport(ActivityKit)
import ActivityKit

/// Live Activity „Fruchtbares Fenster" / „Periode bald".
/// Gleiche Kopie liegt in `PainDiary_Live_Widget/` (die Typen müssen in beiden Targets identisch sein).
nonisolated struct ZyklusLiveAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var titel: String
        var detail: String
        var symbol: String
        var zyklustag: Int
    }
    var art: String   // "fruchtbar" | "periode"
}
#endif
