import SwiftUI

struct WizardAnatomieKarteView: View {
    @Binding var koerperstelle: String

    private let regionen = [
        KoerperRegion(name: "Kopf", symbol: "brain.head.profile", farbe: .purple, x: 0.5, y: 0.05),
        KoerperRegion(name: "Nacken", symbol: "rectangle.portrait", farbe: .indigo, x: 0.5, y: 0.12),
        KoerperRegion(name: "Schulter links", symbol: "figure.arms.open", farbe: .blue, x: 0.25, y: 0.18),
        KoerperRegion(name: "Schulter rechts", symbol: "figure.arms.open", farbe: .blue, x: 0.75, y: 0.18),
        KoerperRegion(name: "Brust", symbol: "heart", farbe: .red, x: 0.5, y: 0.22),
        KoerperRegion(name: "Rücken", symbol: "arrow.up.and.down.and.arrow.left.and.right", farbe: .orange, x: 0.5, y: 0.30),
        KoerperRegion(name: "Bauch", symbol: "circle", farbe: .yellow, x: 0.5, y: 0.38),
        KoerperRegion(name: "Arm links", symbol: "hand.raised", farbe: .teal, x: 0.15, y: 0.38),
        KoerperRegion(name: "Arm rechts", symbol: "hand.raised", farbe: .teal, x: 0.85, y: 0.38),
        KoerperRegion(name: "Gelenke", symbol: "figure.walk", farbe: .green, x: 0.5, y: 0.50),
        KoerperRegion(name: "Hüfte", symbol: "figure.stand", farbe: .brown, x: 0.5, y: 0.58),
        KoerperRegion(name: "Bein links", symbol: "figure.walk", farbe: .cyan, x: 0.3, y: 0.72),
        KoerperRegion(name: "Bein rechts", symbol: "figure.walk", farbe: .cyan, x: 0.7, y: 0.72),
        KoerperRegion(name: "Fuss links", symbol: "shoeprints.fill", farbe: .mint, x: 0.3, y: 0.92),
        KoerperRegion(name: "Fuss rechts", symbol: "shoeprints.fill", farbe: .mint, x: 0.7, y: 0.92),
    ]

    var body: some View {
        VStack(spacing: 20) {
            Text("Wo hast du Schmerzen?")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            GeometryReader { geo in
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.secondary.opacity(0.08))

                    ForEach(regionen) { region in
                        KoerperPunkt(
                            region: region,
                            ausgewaehlt: koerperstelle == region.name,
                            action: { koerperstelle = koerperstelle == region.name ? "" : region.name }
                        )
                        .position(
                            x: geo.size.width * region.x,
                            y: geo.size.height * region.y
                        )
                    }
                }
            }
            .frame(height: 380)
            .padding(.horizontal)

            if !koerperstelle.isEmpty {
                Label(koerperstelle, systemImage: "mappin.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.accentColor)
            } else {
                Text("Tippe auf eine Körperstelle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(regionen) { region in
                        ChipButton(
                            label: region.name,
                            ausgewaehlt: koerperstelle == region.name
                        ) {
                            koerperstelle = koerperstelle == region.name ? "" : region.name
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.horizontal)
    }
}

private struct KoerperRegion: Identifiable {
    let id = UUID()
    let name: String
    let symbol: String
    let farbe: Color
    let x: Double
    let y: Double
}

private struct KoerperPunkt: View {
    let region: KoerperRegion
    let ausgewaehlt: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(ausgewaehlt ? region.farbe : region.farbe.opacity(0.25))
                    .frame(width: ausgewaehlt ? 40 : 30, height: ausgewaehlt ? 40 : 30)
                    .shadow(color: ausgewaehlt ? region.farbe.opacity(0.5) : .clear, radius: 6)
                Image(systemName: region.symbol)
                    .font(.system(size: ausgewaehlt ? 14 : 10))
                    .foregroundStyle(ausgewaehlt ? .white : region.farbe)
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3), value: ausgewaehlt)
    }
}
