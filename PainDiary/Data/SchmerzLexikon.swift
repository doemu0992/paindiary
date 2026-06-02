import Foundation

struct RegionData {
    let charakter: [String]
    let symptome: [String]
    let ausloeser: [String]
}

class SchmerzLexikon {
    static let db: [String: RegionData] = [
        "Kopf": RegionData(
            charakter: ["Pochend", "Pulsierend", "Stechend", "Dumpf drückend", "Einseitig", "Beidseitig"],
            symptome: ["Lichtempfindlichkeit", "Lärmempfindlichkeit", "Übelkeit", "Sehstörungen (Aura)"],
            ausloeser: ["Stress", "Wetterumschwung", "Schlafmangel", "Bildschirmarbeit", "Dehydration"]
        ),
        "Nacken": RegionData(
            charakter: ["Verspannt", "Ziehend", "Stechend", "Brennend", "Steif"],
            symptome: ["Strahlt in den Arm aus", "Kopfschmerzen", "Eingeschränkte Drehung"],
            ausloeser: ["Bildschirmarbeit", "Zugluft", "Falsche Schlafposition", "Stress"]
        ),
        "Rücken": RegionData(
            charakter: ["Ziehend", "Dumpf", "Stechend", "Krampfartig", "Brennend"],
            symptome: ["Strahlt ins Bein aus", "Taubheitsgefühl", "Schlimmer bei Bewegung"],
            ausloeser: ["Langes Sitzen", "Schwer gehoben", "Falsche Haltung"]
        ),
        "Bauch": RegionData(
            charakter: ["Krampfartig", "Stechend", "Dumpf", "Brennend", "Blähend"],
            symptome: ["Übelkeit", "Sodbrennen", "Appetitlosigkeit"],
            ausloeser: ["Essen", "Periode", "Stress", "Infekt"]
        ),
        "Gelenke": RegionData(
            charakter: ["Anlaufschmerz", "Belastungsschmerz", "Ruheschmerz", "Knirschend"],
            symptome: ["Geschwollen", "Morgensteifigkeit", "Rötung"],
            ausloeser: ["Sport", "Wetterumschwung", "Kälte", "Fehltritt"]
        )
    ]
}
