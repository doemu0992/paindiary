import Foundation

/// Persistenz der Einblicke-Konfiguration (UserDefaults, JSON) inkl. einmaliger Migration der alten Kachel-Auswahl.
enum EinblickeKonfigurationSpeicher {
    private static let schluessel = "einblickeKonfig"

    static func laden() -> EinblickeKonfiguration {
        if let data = UserDefaults.standard.data(forKey: schluessel),
           let k = try? JSONDecoder().decode(EinblickeKonfiguration.self, from: data) {
            return k.normalisiert
        }
        // Migration: Sichtbarkeit der bisherigen Kacheln übernehmen
        let alt = [KachelKonfiguration].laden()
        let sichtbarkeit = Dictionary(alt.map { ($0.typ.rawValue, $0.sichtbar) }, uniquingKeysWith: { a, b in a || b })
        let neu = EinblickeKonfiguration.ausAlterKonfiguration(sichtbarkeit: sichtbarkeit)
        speichern(neu)
        return neu
    }

    static func speichern(_ konfiguration: EinblickeKonfiguration) {
        if let data = try? JSONEncoder().encode(konfiguration) {
            UserDefaults.standard.set(data, forKey: schluessel)
        }
    }
}
