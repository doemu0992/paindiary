import Foundation

// MARK: - Kachel-Typen

enum KachelTyp: String, Codable, CaseIterable {
    // Standard (default Dashboard)
    case schmerzUebersicht
    case schmerzverlauf
    case stimmungStress
    case medikamente
    case zyklus
    case hautveraenderung
    case schnellLinks
    // Analyse
    case wetterSchmerz
    case stressSchmerz
    case schlafSchmerz
    case midasKachel
    // Module
    case schmerzKachel
    case migraeneKachel
    case rheumaKachel
    case diabetesKachel
    // Konfigurierbar
    case konfigKorrelation

    var titel: String {
        switch self {
        case .schmerzUebersicht:   return "Schmerzübersicht"
        case .schmerzverlauf:      return "Schmerzverlauf"
        case .stimmungStress:      return "Stimmung & Stress"
        case .medikamente:         return "Medikamente heute"
        case .zyklus:              return "Zyklus-Tracker"
        case .hautveraenderung:    return "Hautveränderungen"
        case .schnellLinks:        return "Schnelllinks"
        case .wetterSchmerz:       return "Wetter & Schmerz"
        case .stressSchmerz:       return "Stress & Schmerz"
        case .schlafSchmerz:       return "Schlaf & Schmerz"
        case .midasKachel:         return "MIDAS-Score"
        case .schmerzKachel:       return "Schmerztagebuch"
        case .migraeneKachel:      return "Migräne-Verlauf"
        case .rheumaKachel:        return "Rheuma & Gelenke"
        case .diabetesKachel:      return "Diabetes-Verlauf"
        case .konfigKorrelation:   return "Eigene Korrelation"
        }
    }

    var symbol: String {
        switch self {
        case .schmerzUebersicht:   return "waveform.path.ecg"
        case .schmerzverlauf:      return "chart.line.uptrend.xyaxis"
        case .stimmungStress:      return "heart.text.square.fill"
        case .medikamente:         return "pill.fill"
        case .zyklus:              return "drop.circle.fill"
        case .hautveraenderung:    return "allergens"
        case .schnellLinks:        return "link"
        case .wetterSchmerz:       return "cloud.sun.fill"
        case .stressSchmerz:       return "bolt.fill"
        case .schlafSchmerz:       return "moon.zzz.fill"
        case .midasKachel:         return "brain.head.profile"
        case .schmerzKachel:       return "waveform.path.ecg"
        case .migraeneKachel:      return "bolt.horizontal.fill"
        case .rheumaKachel:        return "figure.arms.open"
        case .diabetesKachel:      return "drop.fill"
        case .konfigKorrelation:   return "slider.horizontal.3"
        }
    }

    var abschnitt: String {
        switch self {
        case .schmerzUebersicht, .medikamente, .zyklus, .hautveraenderung:
            return "Heute"
        case .schmerzverlauf:
            return "Verlauf"
        case .stimmungStress, .schnellLinks:
            return "Zuletzt"
        case .schmerzKachel, .migraeneKachel, .rheumaKachel, .diabetesKachel:
            return "Module"
        case .wetterSchmerz, .stressSchmerz, .schlafSchmerz,
             .midasKachel, .konfigKorrelation:
            return "Analyse"
        }
    }

    // Basiskacheln können nur ausgeblendet, nicht gelöscht werden
    static let basisKacheln: Set<KachelTyp> = [
        .schmerzUebersicht, .schmerzverlauf, .stimmungStress,
        .medikamente, .zyklus, .hautveraenderung, .schnellLinks
    ]
}

// MARK: - Kachel-Konfiguration

struct KachelKonfiguration: Codable, Identifiable, Hashable, Equatable {
    var id: String
    var typ: KachelTyp
    var sichtbar: Bool = true
    var xVariable: String = ""
    var yVariable: String = "schmerzstaerke"
    var benutzertitel: String = ""
    // Korrelations-Filter
    var filterRegionen: [String] = []
    var filterSchmerzarten: [String] = []
    var filterMedikament: String = ""
    var filterZeitraum: Int = 0       // 0 = alles, 7 / 30 / 90 Tage
    var filterMinStaerke: Int = 0     // 0 = kein Filter
    var diagrammTyp: String = "auto"  // "auto" | "balken" | "scatter"

    var anzeigeTitel: String {
        benutzertitel.isEmpty ? typ.titel : benutzertitel
    }

    static let standard: [KachelKonfiguration] = [
        KachelKonfiguration(id: KachelTyp.schmerzUebersicht.rawValue,  typ: .schmerzUebersicht),
        KachelKonfiguration(id: KachelTyp.medikamente.rawValue,        typ: .medikamente),
        KachelKonfiguration(id: KachelTyp.zyklus.rawValue,             typ: .zyklus),
        KachelKonfiguration(id: KachelTyp.hautveraenderung.rawValue,   typ: .hautveraenderung),
        KachelKonfiguration(id: KachelTyp.schmerzverlauf.rawValue,     typ: .schmerzverlauf),
        KachelKonfiguration(id: KachelTyp.stimmungStress.rawValue,     typ: .stimmungStress),
        KachelKonfiguration(id: KachelTyp.schnellLinks.rawValue,       typ: .schnellLinks),
    ]
}

// MARK: - Persistenz

extension Array where Element == KachelKonfiguration {
    static func laden() -> [KachelKonfiguration] {
        guard let data = UserDefaults.standard.data(forKey: "dashboardKonfig"),
              let decoded = try? JSONDecoder().decode([KachelKonfiguration].self, from: data)
        else { return KachelKonfiguration.standard }

        // Bei App-Updates fehlende Basiskacheln ans Ende anhängen
        var result = decoded
        for k in KachelKonfiguration.standard where !result.contains(where: { $0.id == k.id }) {
            result.append(k)
        }
        return result
    }

    func speichern() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "dashboardKonfig")
        }
    }
}
