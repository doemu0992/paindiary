import Foundation

enum SubRegionen {
    static let map: [String: [String]] = [
        "Kopf":         ["Stirn", "Hinterkopf", "Schläfe links", "Schläfe rechts",
                         "Auge links", "Auge rechts", "Nase", "Kiefer", "Zahn"],
        "Hals":         ["Kehlkopf", "Schilddrüse", "Hals links", "Hals rechts"],
        "Brust":        ["Herz", "Brustbein", "Rippen links", "Rippen rechts",
                         "Schlüsselbein links", "Schlüsselbein rechts"],
        "Bauch":        ["Oberbauch", "Unterbauch", "Magen", "Darm",
                         "Flanke links", "Flanke rechts"],
        "Rücken oben":  ["Wirbelsäule oben", "Schulterblatt links", "Schulterblatt rechts"],
        "Rücken unten": ["Wirbelsäule unten", "Niere links", "Niere rechts", "Kreuzbein"],
        "Hüfte":        ["Hüfte links", "Hüfte rechts", "Leiste links", "Leiste rechts"],
        "Gesäss":       ["Steissbein", "Gesäss links", "Gesäss rechts"],
    ]
}
