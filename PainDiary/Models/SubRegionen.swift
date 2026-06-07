import Foundation

enum SubRegionen {
    /// Pain-oriented sub-regions (includes internal anatomy)
    static let map: [String: [String]] = [
        "Kopf": ["Stirn", "Scheitel", "Hinterkopf", "Schläfe links", "Schläfe rechts",
                 "Auge links", "Auge rechts", "Nase", "Wange links", "Wange rechts",
                 "Kinn", "Oberkiefer", "Unterkiefer"],
        "Nacken": ["Kehlkopf", "Schilddrüse", "Hals links", "Hals rechts"],
        "Brust": ["Herz", "Brustbein", "Rippen links", "Rippen rechts",
                  "Schlüsselbein links", "Schlüsselbein rechts"],
        "Bauch": ["Oberbauch", "Unterbauch", "Magen", "Darm", "Flanke links", "Flanke rechts"],
        "Hüfte": ["Hüfte links", "Hüfte rechts", "Leiste links", "Leiste rechts", "Beckenboden"],
        "Rücken oben": ["Wirbelsäule oben", "Schulterblatt links", "Schulterblatt rechts"],
        "Rücken unten": ["Wirbelsäule unten", "Niere links", "Niere rechts", "Kreuzbein"],
        "Gesäss": ["Steissbein", "Gesäss links", "Gesäss rechts"],
        "Schulter links": ["Schultergelenk", "Schulterblatt", "Schlüsselbein"],
        "Schulter rechts": ["Schultergelenk", "Schulterblatt", "Schlüsselbein"],
        "Unterschenkel links": ["Wade", "Schienbein"],
        "Unterschenkel rechts": ["Wade", "Schienbein"],
        "Hand links": ["Daumen", "Zeigefinger", "Mittelfinger", "Ringfinger", "Kleiner Finger",
                       "Handfläche", "Handgelenk"],
        "Hand rechts": ["Daumen", "Zeigefinger", "Mittelfinger", "Ringfinger", "Kleiner Finger",
                        "Handfläche", "Handgelenk"],
        "Fuss links": ["Großzehe", "2. Zehe", "3. Zehe", "4. Zehe", "Kleiner Zehe",
                       "Fußsohle", "Ferse", "Fußspann"],
        "Fuss rechts": ["Großzehe", "2. Zehe", "3. Zehe", "4. Zehe", "Kleiner Zehe",
                        "Fußsohle", "Ferse", "Fußspann"]
    ]

    /// Skin-surface-only sub-regions (no internal anatomy, no bones)
    static let hautMap: [String: [String]] = [
        "Kopf": ["Stirn", "Schläfe links", "Schläfe rechts", "Wange links", "Wange rechts",
                 "Nase", "Kinn", "Augenbereich", "Ohr links", "Ohr rechts",
                 "Haaransatz", "Scheitel", "Hinterkopf"],
        "Nacken": ["Hals vorne", "Hals links", "Hals rechts"],
        "Brust": ["Obere Brust", "Untere Brust", "Brust links", "Brust rechts", "Décolleté"],
        "Bauch": ["Oberbauch", "Unterbauch", "Nabel", "Flanke links", "Flanke rechts"],
        "Rücken oben": ["Mitte oben", "Schulterblatt links", "Schulterblatt rechts"],
        "Rücken unten": ["Lende links", "Lende rechts", "Kreuzbereich"],
        "Hüfte": ["Hüfte links", "Hüfte rechts", "Leiste links", "Leiste rechts"],
        "Gesäss": ["Gesäss links", "Gesäss rechts"],
        "Schulter links": ["Schulter vorne", "Schulter hinten", "Achselhöhle"],
        "Schulter rechts": ["Schulter vorne", "Schulter hinten", "Achselhöhle"],
        "Unterschenkel links": ["Wade", "Schienbein"],
        "Unterschenkel rechts": ["Wade", "Schienbein"],
        "Hand links": ["Daumen", "Zeigefinger", "Mittelfinger", "Ringfinger", "Kleiner Finger",
                       "Handfläche", "Handrücken", "Handgelenk"],
        "Hand rechts": ["Daumen", "Zeigefinger", "Mittelfinger", "Ringfinger", "Kleiner Finger",
                        "Handfläche", "Handrücken", "Handgelenk"],
        "Fuss links": ["Großzehe", "2. Zehe", "3. Zehe", "4. Zehe", "Kleiner Zehe",
                       "Fußsohle", "Ferse", "Fußspann", "Knöchel"],
        "Fuss rechts": ["Großzehe", "2. Zehe", "3. Zehe", "4. Zehe", "Kleiner Zehe",
                        "Fußsohle", "Ferse", "Fußspann", "Knöchel"]
    ]
}
