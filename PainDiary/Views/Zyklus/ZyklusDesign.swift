import SwiftUI

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

// MARK: - Hintergrund (Mesh-artiger Verlauf: Rosé · Pfirsich · Lavendel)

struct ZyklusHintergrund: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let dunkel = scheme == .dark
        ZStack {
            (dunkel ? Color(red: 0.10, green: 0.06, blue: 0.10) : Color(red: 0.99, green: 0.93, blue: 0.95))
            RadialGradient(colors: [Color(red: 1.00, green: 0.55, blue: 0.69).opacity(dunkel ? 0.35 : 0.65), .clear],
                           center: .topLeading, startRadius: 0, endRadius: 440)
            RadialGradient(colors: [Color(red: 1.00, green: 0.75, blue: 0.55).opacity(dunkel ? 0.25 : 0.55), .clear],
                           center: .topTrailing, startRadius: 0, endRadius: 380)
            RadialGradient(colors: [Color(red: 0.74, green: 0.65, blue: 1.00).opacity(dunkel ? 0.32 : 0.55), .clear],
                           center: .leading, startRadius: 0, endRadius: 460)
            RadialGradient(colors: [Color(red: 1.00, green: 0.60, blue: 0.75).opacity(dunkel ? 0.30 : 0.55), .clear],
                           center: .bottomTrailing, startRadius: 0, endRadius: 460)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Frosted-Glass-Karte

struct ZyklusGlas: ViewModifier {
    var radius: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: Color.pink.opacity(0.10), radius: 14, x: 0, y: 6)
    }
}

extension View {
    func zyklusGlas(radius: CGFloat = 24) -> some View {
        modifier(ZyklusGlas(radius: radius))
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
