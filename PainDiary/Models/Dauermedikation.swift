import Foundation
import SwiftData

enum MedikamentTyp: String, CaseIterable {
    case tablette   = "Tablette"
    case kapsel     = "Kapsel"
    case spritze    = "Spritze / Injektion"
    case injPen     = "Injektions-Pen"
    case tropfen    = "Tropfen"
    case spray      = "Spray / Inhalator"
    case pulver     = "Pulver / Sachet"
    case brausetab  = "Brausetablette"
    case pflaster   = "Pflaster / Patch"
    case gel        = "Gel / Creme / Salbe"
    case zaepfchen  = "Zäpfchen"
    case sonstige   = "Sonstige"

    var symbol: String {
        switch self {
        case .tablette:          return "pill.fill"
        case .kapsel:            return "capsule.fill"
        case .spritze, .injPen:  return "syringe"
        case .tropfen:           return "drop.fill"
        case .spray:             return "lungs.fill"
        case .pulver:            return "shaker.package.fill"
        case .brausetab:         return "bubbles.and.sparkles"
        case .pflaster:          return "bandage.fill"
        case .gel:               return "tube.horizontal.fill"
        case .zaepfchen:         return "thermometer.medium"
        case .sonstige:          return "cross.case.fill"
        }
    }

    var istInjektion: Bool { self == .spritze || self == .injPen }
}

@Model final class Dauermedikation {
    var notifID: String = UUID().uuidString
    var name: String = ""
    var dosierung: String = ""
    var frequenz: String = ""
    var startDatum: Date = Date()
    var aktiv: Bool = true
    var endDatum: Date? = nil
    var erinnerungAktiv: Bool = false
    // Komma-getrennte Zeiten "HH:mm,HH:mm" — leer = Standard je nach Frequenz
    var erinnerungsZeiten: String = ""
    // Stunden bis Wirksamkeits-Abfrage nach Einnahme (2 / 24 / 48)
    var wirkungsAbfrageStunden: Int = 2
    var medikamentTyp: String = MedikamentTyp.tablette.rawValue
    var einnahmeHinweis: String = ""
    var vorrat: Int? = nil
    var vorratSchwelle: Int = 7
    var ablaufDatum: Date? = nil

    var typSymbol: String {
        MedikamentTyp(rawValue: medikamentTyp)?.symbol ?? "pill.fill"
    }

    init(name: String = "", dosierung: String = "", frequenz: String = "",
         startDatum: Date = .now, aktiv: Bool = true) {
        self.name = name
        self.dosierung = dosierung
        self.frequenz = frequenz
        self.startDatum = startDatum
        self.aktiv = aktiv
    }
}
