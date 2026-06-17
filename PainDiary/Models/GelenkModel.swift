import SwiftUI

// MARK: - Joint State

enum GelenkZustand: Int, CaseIterable {
    case keiner      = 0
    case schmerzhaft = 1
    case geschwollen = 2
    case beides      = 3

    var farbe: Color {
        switch self {
        case .keiner:      return Color(.systemGray5)
        case .schmerzhaft: return .red
        case .geschwollen: return .blue
        case .beides:      return .purple
        }
    }

    var textfarbe: Color {
        self == .keiner ? .secondary : .white
    }

    var kuerzel: String {
        switch self {
        case .keiner:      return "–"
        case .schmerzhaft: return "S"
        case .geschwollen: return "G"
        case .beides:      return "SG"
        }
    }

    var label: String {
        switch self {
        case .keiner:      return "Keine"
        case .schmerzhaft: return "Schmerzhaft"
        case .geschwollen: return "Geschwollen"
        case .beides:      return "Schmerzhaft & Geschwollen"
        }
    }

    var naechster: GelenkZustand {
        switch self {
        case .keiner:      return .schmerzhaft
        case .schmerzhaft: return .geschwollen
        case .geschwollen: return .beides
        case .beides:      return .keiner
        }
    }
}

// MARK: - Joint Definition

enum GelenkGruppe: String, CaseIterable {
    case fingerRechts  = "Rechte Hand"
    case fingerLinks   = "Linke Hand"
    case armRechts     = "Rechter Arm"
    case armLinks      = "Linker Arm"
    case wirbelsaeule  = "Wirbelsäule"
    case beinRechts    = "Rechtes Bein"
    case beinLinks     = "Linkes Bein"
    case sonstige      = "Sonstige"
}

struct Gelenk: Identifiable {
    let id: String
    let kurzname: String
    let langname: String
    let gruppe: GelenkGruppe
    let istDAS28: Bool
}

// All joints — DAS28 covers 28 joints (bilateral MCPs 1-5, PIPs 1-5, wrist, elbow, shoulder, knee)
let alleGelenke: [Gelenk] = {
    var list: [Gelenk] = []

    // Right hand MCPs
    for i in 1...5 {
        list.append(Gelenk(id: "R_MCP\(i)", kurzname: "Grund.\(i)", langname: "MCP \(i) rechts", gruppe: .fingerRechts, istDAS28: true))
    }
    // Right hand PIPs
    for i in 1...5 {
        list.append(Gelenk(id: "R_PIP\(i)", kurzname: "Mittel.\(i)", langname: "PIP \(i) rechts", gruppe: .fingerRechts, istDAS28: true))
    }
    // Left hand MCPs
    for i in 1...5 {
        list.append(Gelenk(id: "L_MCP\(i)", kurzname: "Grund.\(i)", langname: "MCP \(i) links", gruppe: .fingerLinks, istDAS28: true))
    }
    // Left hand PIPs
    for i in 1...5 {
        list.append(Gelenk(id: "L_PIP\(i)", kurzname: "Mittel.\(i)", langname: "PIP \(i) links", gruppe: .fingerLinks, istDAS28: true))
    }
    // Arms
    list.append(Gelenk(id: "R_HG",  kurzname: "Handgel.", langname: "Handgelenk rechts",  gruppe: .armRechts, istDAS28: true))
    list.append(Gelenk(id: "R_E",   kurzname: "Ellbog.",  langname: "Ellbogen rechts",     gruppe: .armRechts, istDAS28: true))
    list.append(Gelenk(id: "R_S",   kurzname: "Schulter", langname: "Schulter rechts",     gruppe: .armRechts, istDAS28: true))
    list.append(Gelenk(id: "L_HG",  kurzname: "Handgel.", langname: "Handgelenk links",    gruppe: .armLinks,  istDAS28: true))
    list.append(Gelenk(id: "L_E",   kurzname: "Ellbog.",  langname: "Ellbogen links",      gruppe: .armLinks,  istDAS28: true))
    list.append(Gelenk(id: "L_S",   kurzname: "Schulter", langname: "Schulter links",      gruppe: .armLinks,  istDAS28: true))
    // Spine
    list.append(Gelenk(id: "HWS",   kurzname: "Hals",  langname: "Halswirbelsäule",     gruppe: .wirbelsaeule, istDAS28: false))
    list.append(Gelenk(id: "BWS",   kurzname: "Brust", langname: "Brustwirbelsäule",    gruppe: .wirbelsaeule, istDAS28: false))
    list.append(Gelenk(id: "LWS",   kurzname: "Lende", langname: "Lendenwirbelsäule",   gruppe: .wirbelsaeule, istDAS28: false))
    // Right leg
    list.append(Gelenk(id: "R_HUE", kurzname: "Hüfte", langname: "Hüfte rechts",     gruppe: .beinRechts, istDAS28: false))
    list.append(Gelenk(id: "R_K",   kurzname: "Knie",  langname: "Knie rechts",       gruppe: .beinRechts, istDAS28: true))
    list.append(Gelenk(id: "R_OSG", kurzname: "Sprung.", langname: "Sprunggelenk rechts", gruppe: .beinRechts, istDAS28: false))
    // Left leg
    list.append(Gelenk(id: "L_HUE", kurzname: "Hüfte", langname: "Hüfte links",      gruppe: .beinLinks, istDAS28: false))
    list.append(Gelenk(id: "L_K",   kurzname: "Knie",  langname: "Knie links",        gruppe: .beinLinks, istDAS28: true))
    list.append(Gelenk(id: "L_OSG", kurzname: "Sprung.", langname: "Sprunggelenk links", gruppe: .beinLinks, istDAS28: false))
    // Other
    list.append(Gelenk(id: "R_KFG", kurzname: "Kiefer", langname: "Kiefergelenk rechts", gruppe: .sonstige, istDAS28: false))
    list.append(Gelenk(id: "L_KFG", kurzname: "Kiefer", langname: "Kiefergelenk links",  gruppe: .sonstige, istDAS28: false))

    return list
}()

// MARK: - Encode / Decode

struct GelenkStatusCoder {
    static func decode(_ s: String) -> [String: GelenkZustand] {
        guard !s.isEmpty else { return [:] }
        var result: [String: GelenkZustand] = [:]
        for teil in s.components(separatedBy: ",") {
            let parts = teil.components(separatedBy: ":")
            guard parts.count == 2,
                  let wert = Int(parts[1]),
                  let zustand = GelenkZustand(rawValue: wert),
                  zustand != .keiner else { continue }
            result[parts[0]] = zustand
        }
        return result
    }

    static func encode(_ dict: [String: GelenkZustand]) -> String {
        dict.filter { $0.value != .keiner }
            .sorted { $0.key < $1.key }
            .map { "\($0.key):\($0.value.rawValue)" }
            .joined(separator: ",")
    }
}

// MARK: - DAS28 Calculation

struct DAS28Rechner {
    static func tjc28(_ dict: [String: GelenkZustand]) -> Int {
        let das28IDs = Set(alleGelenke.filter(\.istDAS28).map(\.id))
        return dict.filter { das28IDs.contains($0.key) && ($0.value == .schmerzhaft || $0.value == .beides) }.count
    }

    static func sjc28(_ dict: [String: GelenkZustand]) -> Int {
        let das28IDs = Set(alleGelenke.filter(\.istDAS28).map(\.id))
        return dict.filter { das28IDs.contains($0.key) && ($0.value == .geschwollen || $0.value == .beides) }.count
    }

    // DAS28-CRP formula
    static func das28crp(tjc: Int, sjc: Int, crp: Double, gh: Int) -> Double {
        0.56 * sqrt(Double(tjc)) + 0.28 * sqrt(Double(sjc)) +
        0.36 * log(crp + 1) + 0.014 * Double(gh) + 0.96
    }

    // DAS28-ESR formula
    static func das28esr(tjc: Int, sjc: Int, bsg: Double, gh: Int) -> Double {
        0.56 * sqrt(Double(tjc)) + 0.28 * sqrt(Double(sjc)) +
        0.70 * log(max(bsg, 1)) + 0.014 * Double(gh)
    }

    static func aktivitaetsText(_ score: Double) -> String {
        switch score {
        case ..<2.6:  return "Remission"
        case 2.6..<3.2: return "Niedrige Aktivität"
        case 3.2..<5.1: return "Mässige Aktivität"
        default:      return "Hohe Aktivität"
        }
    }

    static func aktivitaetsFarbe(_ score: Double) -> Color {
        switch score {
        case ..<2.6:  return .green
        case 2.6..<3.2: return .mint
        case 3.2..<5.1: return .orange
        default:      return .red
        }
    }
}
