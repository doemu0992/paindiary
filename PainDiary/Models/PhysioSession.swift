import Foundation
import SwiftData

enum PhysioTyp: String, CaseIterable {
    case physiotherapie  = "Physiotherapie"
    case ergotherapie    = "Ergotherapie"
    case selbstuebungen  = "Selbstübungen"
    case wassergymnastik = "Wassergymnastik"
    case yoga            = "Yoga / Dehnen"
    case kraft           = "Krafttraining"
    case nordic          = "Nordic Walking / Gehen"

    var symbol: String {
        switch self {
        case .physiotherapie:  return "figure.walk.motion"
        case .ergotherapie:    return "hand.raised.fill"
        case .selbstuebungen:  return "figure.flexibility"
        case .wassergymnastik: return "figure.pool.swim"
        case .yoga:            return "figure.mind.and.body"
        case .kraft:           return "dumbbell.fill"
        case .nordic:          return "figure.hiking"
        }
    }
}

@Model final class PhysioSession {
    var datum: Date = Date()
    var typ: String = PhysioTyp.physiotherapie.rawValue
    var dauerMinuten: Int = 30
    var uebungen: String = ""
    var schmerzVorher: Int = 0
    var schmerzNachher: Int = 0
    var notizen: String = ""

    init(datum: Date = .now, typ: String = PhysioTyp.physiotherapie.rawValue) {
        self.datum = datum
        self.typ = typ
    }

    var typSymbol: String {
        PhysioTyp(rawValue: typ)?.symbol ?? "figure.walk"
    }
}
