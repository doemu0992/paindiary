import Foundation

enum SubRegionen {
    static let map: [String: [String]] = [
        "Kopf":              ["Stirn", "Scheitel", "Hinterkopf",
                              "Schläfe links", "Schläfe rechts",
                              "Auge links", "Auge rechts",
                              "Nase", "Wange links", "Wange rechts",
                              "Oberkiefer", "Unterkiefer", "Zahn"],
        "Hals":              ["Kehlkopf", "Schilddrüse", "Hals links", "Hals rechts"],
        "Brust":             ["Herz", "Brustbein", "Rippen links", "Rippen rechts",
                              "Schlüsselbein links", "Schlüsselbein rechts"],
        "Bauch":             ["Oberbauch", "Unterbauch", "Magen", "Darm",
                              "Flanke links", "Flanke rechts"],
        "Rücken oben":       ["Wirbelsäule oben", "Schulterblatt links", "Schulterblatt rechts"],
        "Rücken unten":      ["Wirbelsäule unten", "Niere links", "Niere rechts", "Kreuzbein"],
        "Hüfte":             ["Hüfte links", "Hüfte rechts", "Leiste links", "Leiste rechts",
                              "Beckenboden"],
        "Gesäss":            ["Steissbein", "Gesäss links", "Gesäss rechts"],
        "Schulter links":    ["Schultergelenk", "Schulterblatt", "Schlüsselbein"],
        "Schulter rechts":   ["Schultergelenk", "Schulterblatt", "Schlüsselbein"],
        "Unterschenkel links":  ["Wade", "Schienbein"],
        "Unterschenkel rechts": ["Wade", "Schienbein"],
        "Hand links":        ["Daumen", "Zeigefinger", "Mittelfinger", "Ringfinger",
                              "Kleiner Finger", "Handfläche", "Handgelenk"],
        "Hand rechts":       ["Daumen", "Zeigefinger", "Mittelfinger", "Ringfinger",
                              "Kleiner Finger", "Handfläche", "Handgelenk"],
        "Fuss links":        ["Großzehe", "2. Zehe", "3. Zehe", "4. Zehe", "Kleiner Zehe",
                              "Fußsohle", "Ferse", "Fußspann"],
        "Fuss rechts":       ["Großzehe", "2. Zehe", "3. Zehe", "4. Zehe", "Kleiner Zehe",
                              "Fußsohle", "Ferse", "Fußspann"],
    ]
}
