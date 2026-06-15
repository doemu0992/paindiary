import Foundation
import SwiftData

@Model final class Laborwert {
    var datum: Date = Date()
    var typ: String = ""
    var wert: Double = 0
    var einheit: String = ""
    var referenzMin: Double? = nil
    var referenzMax: Double? = nil
    var notizen: String = ""

    init(datum: Date = .now, typ: String, wert: Double, einheit: String) {
        self.datum = datum
        self.typ = typ
        self.wert = wert
        self.einheit = einheit
    }

    var istErhoeht: Bool? {
        guard let max = referenzMax else { return nil }
        return wert > max
    }

    var istErniedrigt: Bool? {
        guard let min = referenzMin else { return nil }
        return wert < min
    }
}

// MARK: - Standard Lab Value Types

struct LaborwertTyp {
    let name: String
    let einheit: String
    let referenzMin: Double?
    let referenzMax: Double?

    static let rheuma: [LaborwertTyp] = [
        LaborwertTyp(name: "CRP",          einheit: "mg/L",  referenzMin: 0,    referenzMax: 5),
        LaborwertTyp(name: "BSG",          einheit: "mm/h",  referenzMin: 0,    referenzMax: 20),
        LaborwertTyp(name: "Rheumafaktor", einheit: "IU/mL", referenzMin: 0,    referenzMax: 14),
        LaborwertTyp(name: "Anti-CCP",     einheit: "U/mL",  referenzMin: 0,    referenzMax: 7),
        LaborwertTyp(name: "ANA",          einheit: "Titer", referenzMin: nil,  referenzMax: nil),
        LaborwertTyp(name: "Hämoglobin",   einheit: "g/dL",  referenzMin: 12.0, referenzMax: 17.5),
        LaborwertTyp(name: "Leukozyten",   einheit: "G/L",   referenzMin: 4.0,  referenzMax: 10.0),
        LaborwertTyp(name: "Thrombozyten", einheit: "G/L",   referenzMin: 150,  referenzMax: 400),
        LaborwertTyp(name: "Kreatinin",    einheit: "mg/dL", referenzMin: 0.5,  referenzMax: 1.2),
        LaborwertTyp(name: "HbA1c",        einheit: "%",     referenzMin: nil,  referenzMax: 5.7),
    ]
}
