import Foundation

/// Typ eines `PainEntry`. Ersetzt die Erkennung über Freitext (`koerperstelle == "Rheuma"`).
nonisolated enum EintragArt: String, Codable, CaseIterable, Sendable {
    case schmerz
    case rheuma
    case haut

    /// Altdaten-Regel: Rheuma-Einträge tragen den Marker „Rheuma" als Körperstelle,
    /// Hauteinträge das Flag `istHautEintrag`. Die Regel steht nur noch hier.
    static func ausLegacy(koerperstelle: String, istHautEintrag: Bool) -> EintragArt {
        if koerperstelle == EintragArt.rheumaMarker { return .rheuma }
        if istHautEintrag { return .haut }
        return .schmerz
    }

    /// Wert, den Rheuma-Einträge im Feld `koerperstelle` speichern (Abwärtskompatibilität).
    static let rheumaMarker = "Rheuma"
}
