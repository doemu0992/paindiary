import Foundation

/// Gültige Wertebereiche der Erfassungsfelder. Eine Quelle für Formulare, Import und Repository.
nonisolated enum Wertebereich {
    static let schmerz = 0...10
    static let stimmung = 0...5        // 0 = nicht erfasst
    static let stress = 0...5          // 0 = nicht erfasst
    static let energie = 0...5         // 0 = nicht erfasst
    static let fatigue = 0...10        // 0 = nicht erfasst
    static let migraeneStaerke = 0...10
    static let schlafStunden = 0.0...24.0
    static let dauerMinuten = 0...(60 * 24 * 14)
    static let morgensteifigkeitMinuten = 0...1_440
    /// Blutzucker in mmol/L (plausibler Messbereich der gängigen Geräte)
    static let blutzucker = 0.5...40.0
}

nonisolated extension Comparable {
    /// Begrenzt den Wert auf den Bereich.
    func begrenzt(auf bereich: ClosedRange<Self>) -> Self {
        min(max(self, bereich.lowerBound), bereich.upperBound)
    }
}

/// Beschreibt eine automatische Korrektur (z. B. für Logging oder eine Nutzerhinweis).
nonisolated struct Korrektur: Equatable, Sendable {
    let feld: String
    let alt: String
    let neu: String
}

nonisolated enum ValidierungsFehler: Error, Equatable, LocalizedError, Sendable {
    case wertAusserhalb(feld: String)

    var errorDescription: String? {
        switch self {
        case .wertAusserhalb(let feld): return "Ungültiger Wert für „\(feld)“."
        }
    }
}

/// Rein funktionale Prüf-/Korrekturlogik. Modelle rufen sie über `Normalisierung` auf.
nonisolated enum Validierung {
    /// Begrenzt `wert` auf `bereich` und protokolliert die Korrektur.
    static func begrenze(_ wert: Int, feld: String, bereich: ClosedRange<Int>, korrekturen: inout [Korrektur]) -> Int {
        let neu = wert.begrenzt(auf: bereich)
        if neu != wert { korrekturen.append(Korrektur(feld: feld, alt: "\(wert)", neu: "\(neu)")) }
        return neu
    }

    static func begrenze(_ wert: Double, feld: String, bereich: ClosedRange<Double>, korrekturen: inout [Korrektur]) -> Double {
        guard wert.isFinite else {
            korrekturen.append(Korrektur(feld: feld, alt: "\(wert)", neu: "\(bereich.lowerBound)"))
            return bereich.lowerBound
        }
        let neu = wert.begrenzt(auf: bereich)
        if neu != wert { korrekturen.append(Korrektur(feld: feld, alt: "\(wert)", neu: "\(neu)")) }
        return neu
    }

    /// Ein Zeitpunkt in der Zukunft (mehr als 5 Minuten) wird auf „jetzt" gesetzt.
    static func begrenzeZukunft(_ datum: Date, jetzt: Date = Date(), korrekturen: inout [Korrektur]) -> Date {
        guard datum > jetzt.addingTimeInterval(300) else { return datum }
        korrekturen.append(Korrektur(feld: "datum", alt: "\(datum)", neu: "\(jetzt)"))
        return jetzt
    }

    /// Blutzucker außerhalb des Messbereichs ist ein Eingabefehler und wird nicht still korrigiert.
    static func pruefeBlutzucker(_ wert: Double) throws {
        guard wert.isFinite, Wertebereich.blutzucker.contains(wert) else {
            throw ValidierungsFehler.wertAusserhalb(feld: "Blutzucker")
        }
    }
}
