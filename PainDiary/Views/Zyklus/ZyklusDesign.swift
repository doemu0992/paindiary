import SwiftUI

// MARK: - Sprache

/// Das Zyklus-Modul ist deutschsprachig. Ohne Vorgabe formatiert SwiftUI Datumsangaben in der Sprache der
/// App-Lokalisierung (hier Englisch: „October 2026", „Mon"). `ZyklusLocale.de` erzwingt Deutsch:
/// per `.environment(\.locale, ZyklusLocale.de)` für `Text(_, format:)` und per `.locale(ZyklusLocale.de)`
/// an jedem `formatted(...)`-Aufruf.
enum ZyklusLocale {
    static let de = Locale(identifier: "de_CH")
}

// MARK: - Farben

/// Zyklus-Modul: Tint `.pink`. Phasenfarben sind semantisch (Periode rot, Eisprung orange, fruchtbar teal).
enum ZyklusFarbe {
    static let periode  = Color(red: 0.94, green: 0.24, blue: 0.39)
    static let follikel = Color(red: 1.00, green: 0.70, blue: 0.54)
    static let fruchtbar = Color(red: 0.17, green: 0.83, blue: 0.75)
    static let eisprung = Color.orange
    static let luteal   = Color(red: 0.73, green: 0.64, blue: 1.00)
    static let praemenstruell = Color(red: 0.62, green: 0.50, blue: 0.95)

    static func farbe(_ phase: ZyklusRechner.Zyklusphase) -> Color {
        switch phase {
        case .menstruation:   return periode
        case .follikelphase:  return follikel
        case .ovulation:      return eisprung
        case .lutealphase:    return luteal
        case .praemenstruell: return praemenstruell
        }
    }
}

// MARK: - Unsicherheitsband (± Tage)

struct ZyklusUnsicherheitsBand: View {
    let spanne: Int
    let farbe: Color
    private let maxTage = 7

    var body: some View {
        GeometryReader { geo in
            let gesamt = CGFloat(2 * maxTage + 1)
            let breite = geo.size.width * CGFloat(2 * min(spanne, maxTage) + 1) / gesamt
            ZStack {
                Capsule().fill(Color.secondary.opacity(0.18))
                Capsule().fill(farbe.opacity(0.45)).frame(width: breite)
                Circle().fill(.white).frame(width: 12, height: 12)
                    .overlay(Circle().stroke(farbe, lineWidth: 2))
            }
        }
        .frame(height: 12)
        .accessibilityHidden(true)
    }
}
