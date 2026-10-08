import Foundation

/// Die vier Gruppen der Einblicke (feste Reihenfolge auf dem Screen).
nonisolated enum EinblickeGruppe: String, CaseIterable, Codable, Sendable {
    case wochenuebersicht, kennzahlen, module, analyse

    var titel: String {
        switch self {
        case .wochenuebersicht: return "Wochenübersicht"
        case .kennzahlen:       return "Kennzahlen"
        case .module:           return "Module (Carousel)"
        case .analyse:          return "Analyse"
        }
    }
}

/// Ein ein-/ausblendbarer, sortierbarer Baustein der Einblicke.
nonisolated enum EinblickeBlock: String, CaseIterable, Codable, Sendable {
    // Wochenübersicht
    case hero
    // Kennzahlen
    case schuebe, ausloeser, stimmungStress, schlaf, medikamente, adherenz
    // Module
    case modulSchmerz, modulMigraene, modulRheuma, modulHaut, modulDiabetes, modulZyklus, modulWellness
    // Analyse
    case analyse, midas

    var gruppe: EinblickeGruppe {
        switch self {
        case .hero: return .wochenuebersicht
        case .schuebe, .ausloeser, .stimmungStress, .schlaf, .medikamente, .adherenz: return .kennzahlen
        case .modulSchmerz, .modulMigraene, .modulRheuma, .modulHaut, .modulDiabetes, .modulZyklus, .modulWellness: return .module
        case .analyse, .midas: return .analyse
        }
    }

    var titel: String {
        switch self {
        case .hero:           return "Hero: Letzte 7 Tage"
        case .schuebe:        return "Schübe"
        case .ausloeser:      return "Häufigster Auslöser"
        case .stimmungStress: return "Stimmung & Stress"
        case .schlaf:         return "Schlaf"
        case .medikamente:    return "Medikamente heute"
        case .adherenz:       return "Adherenz"
        case .modulSchmerz:   return "Schmerz"
        case .modulMigraene:  return "Migräne"
        case .modulRheuma:    return "Rheuma"
        case .modulHaut:      return "Haut"
        case .modulDiabetes:  return "Diabetes"
        case .modulZyklus:    return "Zyklus"
        case .modulWellness:  return "Wellness"
        case .analyse:        return "Wetter · Stress · Schlaf · Korrelation"
        case .midas:          return "MIDAS-Score"
        }
    }
}

/// Reihenfolge und Sichtbarkeit der Einblicke-Bausteine (ersetzt die 19-Kachel-Konfiguration).
nonisolated struct EinblickeKonfiguration: Codable, Equatable, Sendable {
    var reihenfolge: [EinblickeBlock]
    var ausgeblendet: Set<EinblickeBlock>

    static let standard = EinblickeKonfiguration(reihenfolge: EinblickeBlock.allCases, ausgeblendet: [])

    /// Alle Bausteine einer Gruppe in der gewählten Reihenfolge (auch ausgeblendete).
    func alle(in gruppe: EinblickeGruppe) -> [EinblickeBlock] {
        normalisiert.reihenfolge.filter { $0.gruppe == gruppe }
    }

    /// Nur die sichtbaren Bausteine einer Gruppe.
    func sichtbar(in gruppe: EinblickeGruppe) -> [EinblickeBlock] {
        alle(in: gruppe).filter { !ausgeblendet.contains($0) }
    }

    func istSichtbar(_ block: EinblickeBlock) -> Bool { !ausgeblendet.contains(block) }

    mutating func umschalten(_ block: EinblickeBlock) {
        if ausgeblendet.contains(block) { ausgeblendet.remove(block) } else { ausgeblendet.insert(block) }
    }

    /// Verschiebt Bausteine innerhalb einer Gruppe (Indizes beziehen sich auf `alle(in:)`).
    mutating func verschiebe(in gruppe: EinblickeGruppe, von: IndexSet, nach: Int) {
        var teil = alle(in: gruppe)
        teil.move(fromOffsets: von, toOffset: nach)
        var iterator = teil.makeIterator()
        reihenfolge = normalisiert.reihenfolge.map { $0.gruppe == gruppe ? (iterator.next() ?? $0) : $0 }
    }

    /// Ergänzt fehlende Bausteine (App-Updates) am Ende und entfernt Duplikate.
    var normalisiert: EinblickeKonfiguration {
        var gesehen = Set<EinblickeBlock>()
        var liste = reihenfolge.filter { gesehen.insert($0).inserted }
        for block in EinblickeBlock.allCases where !gesehen.contains(block) { liste.append(block) }
        return EinblickeKonfiguration(reihenfolge: liste, ausgeblendet: ausgeblendet)
    }

    // MARK: Migration aus der alten Kachel-Konfiguration

    /// Übernimmt die Sichtbarkeit der alten Kacheln (`KachelTyp.rawValue` → sichtbar). Fehlende = sichtbar.
    static func ausAlterKonfiguration(sichtbarkeit: [String: Bool]) -> EinblickeKonfiguration {
        var aus = Set<EinblickeBlock>()
        func verstecken(_ block: EinblickeBlock, wennAlle typen: [String]) {
            let bekannte = typen.compactMap { sichtbarkeit[$0] }
            if !bekannte.isEmpty, !bekannte.contains(true) { aus.insert(block) }
        }
        verstecken(.hero, wennAlle: ["schmerzUebersicht", "schmerzverlauf"])
        verstecken(.stimmungStress, wennAlle: ["stimmungStress"])
        verstecken(.medikamente, wennAlle: ["medikamente"])
        verstecken(.adherenz, wennAlle: ["medikamente"])
        verstecken(.modulSchmerz, wennAlle: ["schmerzKachel"])
        verstecken(.modulMigraene, wennAlle: ["migraeneKachel"])
        verstecken(.modulRheuma, wennAlle: ["rheumaKachel"])
        verstecken(.modulHaut, wennAlle: ["hautveraenderung"])
        verstecken(.modulDiabetes, wennAlle: ["diabetesKachel"])
        verstecken(.modulZyklus, wennAlle: ["zyklus"])
        verstecken(.modulWellness, wennAlle: ["wellnessKachel", "schlafKachel"])
        verstecken(.analyse, wennAlle: ["wetterSchmerz", "stressSchmerz", "schlafSchmerz"])
        verstecken(.midas, wennAlle: ["midasKachel"])
        return EinblickeKonfiguration(reihenfolge: EinblickeBlock.allCases, ausgeblendet: aus)
    }
}
