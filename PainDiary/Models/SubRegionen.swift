import Foundation

enum SubRegionen {
    /// Pain-oriented sub-regions (includes internal anatomy)
    static let map: [String: [String]] = [
        "Kopf": ["Stirn", "Stirn links", "Stirn rechts",
                 "Schläfe links", "Schläfe rechts",
                 "Scheitel", "Hinterkopf", "Nacken",
                 "Auge links", "Auge rechts",
                 "Hinter dem Auge links", "Hinter dem Auge rechts",
                 "Nase", "Wange links", "Wange rechts",
                 "Kinn", "Oberkiefer", "Unterkiefer"],
        "Hals": ["Kehlkopf", "Schilddrüse", "Hals links", "Hals rechts"],
        "Brust": ["Herz", "Brustbein", "Rippen links", "Rippen rechts",
                  "Schlüsselbein links", "Schlüsselbein rechts"],
        "Bauch": ["Oberbauch", "Unterbauch", "Magen", "Darm", "Flanke links", "Flanke rechts"],
        "Hüfte": ["Hüfte links", "Hüfte rechts", "Leiste links", "Leiste rechts", "Beckenboden"],
        "Rücken oben": ["Wirbelsäule oben", "Schulterblatt links", "Schulterblatt rechts"],
        "Rücken unten": ["Wirbelsäule unten", "Niere links", "Niere rechts", "Kreuzbein"],
        "Gesäss": ["Steissbein", "Gesäss links", "Gesäss rechts"],
        "Schulter links":  ["Schultergelenk links",  "Schulterblatt links",  "Schlüsselbein links"],
        "Schulter rechts": ["Schultergelenk rechts", "Schulterblatt rechts", "Schlüsselbein rechts"],
        "Unterschenkel links":  ["Wade links",  "Schienbein links"],
        "Unterschenkel rechts": ["Wade rechts", "Schienbein rechts"],
        "Hand links":  ["Daumen links",  "Zeigefinger links",  "Mittelfinger links",  "Ringfinger links",  "Kleiner Finger links",
                        "Handfläche links",  "Handgelenk links"],
        "Hand rechts": ["Daumen rechts", "Zeigefinger rechts", "Mittelfinger rechts", "Ringfinger rechts", "Kleiner Finger rechts",
                        "Handfläche rechts", "Handgelenk rechts"],
        "Fuss links":  ["Großzehe links",  "2. Zehe links",  "3. Zehe links",  "4. Zehe links",  "Kleiner Zehe links",
                        "Fußsohle links",  "Ferse links",  "Fußspann links"],
        "Fuss rechts": ["Großzehe rechts", "2. Zehe rechts", "3. Zehe rechts", "4. Zehe rechts", "Kleiner Zehe rechts",
                        "Fußsohle rechts", "Ferse rechts", "Fußspann rechts"]
    ]

    /// Skin-surface-only sub-regions (no internal anatomy, no bones)
    static let hautMap: [String: [String]] = [
        "Kopf": ["Stirn", "Schläfe links", "Schläfe rechts", "Wange links", "Wange rechts",
                 "Nase", "Kinn", "Augenbereich", "Ohr links", "Ohr rechts",
                 "Haaransatz", "Scheitel", "Hinterkopf"],
        "Hals": ["Hals vorne", "Hals links", "Hals rechts"],
        "Brust": ["Obere Brust", "Untere Brust", "Brust links", "Brust rechts", "Décolleté"],
        "Bauch": ["Oberbauch", "Unterbauch", "Nabel", "Flanke links", "Flanke rechts"],
        "Rücken oben": ["Mitte oben", "Schulterblatt links", "Schulterblatt rechts"],
        "Rücken unten": ["Lende links", "Lende rechts", "Kreuzbereich"],
        "Hüfte": ["Hüfte links", "Hüfte rechts", "Leiste links", "Leiste rechts"],
        "Gesäss": ["Gesäss links", "Gesäss rechts"],
        "Schulter links":  ["Schulter vorne links",  "Schulter hinten links",  "Achselhöhle links"],
        "Schulter rechts": ["Schulter vorne rechts", "Schulter hinten rechts", "Achselhöhle rechts"],
        "Unterschenkel links":  ["Wade links",  "Schienbein links"],
        "Unterschenkel rechts": ["Wade rechts", "Schienbein rechts"],
        "Hand links":  ["Daumen links",  "Zeigefinger links",  "Mittelfinger links",  "Ringfinger links",  "Kleiner Finger links",
                        "Handfläche links",  "Handrücken links",  "Handgelenk links"],
        "Hand rechts": ["Daumen rechts", "Zeigefinger rechts", "Mittelfinger rechts", "Ringfinger rechts", "Kleiner Finger rechts",
                        "Handfläche rechts", "Handrücken rechts", "Handgelenk rechts"],
        "Fuss links":  ["Großzehe links",  "2. Zehe links",  "3. Zehe links",  "4. Zehe links",  "Kleiner Zehe links",
                        "Fußsohle links",  "Ferse links",  "Fußspann links",  "Knöchel links"],
        "Fuss rechts": ["Großzehe rechts", "2. Zehe rechts", "3. Zehe rechts", "4. Zehe rechts", "Kleiner Zehe rechts",
                        "Fußsohle rechts", "Ferse rechts", "Fußspann rechts", "Knöchel rechts"]
    ]
}
