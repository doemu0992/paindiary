import SwiftUI

// MARK: - Glass-Farben

extension Color {
    /// Adaptive Glas-Füllung (heller Schleier auf Aurora-Hintergrund) – Ersatz für `secondarySystemGroupedBackground`.
    static let glassFill = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.08)
            : UIColor(white: 1, alpha: 0.55)
    })
}

// MARK: - GlassCard

/// Frosted-Glass-Hintergrund mit Gradient-Rand und mehrstufigem Schatten.
struct GlassCardModifier: ViewModifier {
    var radius: CGFloat = 24
    var tint: Color? = nil
    var padding: CGFloat? = nil
    var schatten: Bool = true

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let form = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .padding(padding ?? 0)
            .background {
                ZStack {
                    if reduceTransparency {
                        form.fill(Color(.secondarySystemGroupedBackground))
                    } else {
                        form.fill(.ultraThinMaterial)
                        form.fill(Color.white.opacity(scheme == .dark ? 0.04 : 0.28))
                    }
                    if let tint { form.fill(tint.opacity(scheme == .dark ? 0.12 : 0.08)) }
                }
            }
            .overlay {
                form.strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(scheme == .dark ? 0.35 : 0.75), .white.opacity(0.05)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            }
            .clipShape(form)
            .modifier(GlassShadow(aktiv: schatten))
    }
}

private struct GlassShadow: ViewModifier {
    let aktiv: Bool
    func body(content: Content) -> some View {
        if aktiv {
            content
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                .shadow(color: .black.opacity(0.05), radius: 16, x: 0, y: 8)
                .shadow(color: .black.opacity(0.05), radius: 40, x: 0, y: 20)
        } else {
            content
        }
    }
}

extension View {
    /// Komplette Glas-Karte (Padding + Material + Rand + Schatten).
    func glassCard(radius: CGFloat = 24, tint: Color? = nil, padding: CGFloat = 20) -> some View {
        modifier(GlassCardModifier(radius: radius, tint: tint, padding: padding))
    }

    /// Nur der Glas-Hintergrund (Padding bleibt beim Aufrufer) – Drop-in für `.background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(...))`.
    func glassBackground(radius: CGFloat = 16, tint: Color? = nil) -> some View {
        modifier(GlassCardModifier(radius: radius, tint: tint, padding: nil, schatten: false))
    }

    /// Glas-Füllung ohne Clip/Rand – Drop-in für `.background(Color(.secondarySystemGroupedBackground))` vor `.clipShape`.
    func glassFill() -> some View {
        background(.ultraThinMaterial).background(Color.glassFill.opacity(0.5))
    }

    /// Aurora-Hintergrund für Screens (ScrollView/List/VStack).
    func auroraScreen(schmerzLevel: Int? = nil) -> some View {
        background(AuroraBackground(schmerzLevel: schmerzLevel).ignoresSafeArea())
    }

    /// Liste auf Aurora-Hintergrund mit Glas-Zeilen.
    func glassList(schmerzLevel: Int? = nil) -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(AuroraBackground(schmerzLevel: schmerzLevel).ignoresSafeArea())
    }

    /// Glas-Leisten für Navigation und Tab-Bar.
    func glassBars() -> some View {
        self
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .tabBar)
    }
}

// MARK: - Aurora-Hintergrund

struct AuroraBackground: View {
    /// 0–10; ab 7 wandert ein Punkt zu einem warmen Pfirsich-Ton (kein Alarm-Rot).
    var schmerzLevel: Int? = nil

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var warm: Bool { (schmerzLevel ?? 0) >= 7 }

    private var farben: [Color] {
        if scheme == .dark {
            let c = warm ? Color(red: 0.30, green: 0.16, blue: 0.20) : Color(red: 0.12, green: 0.21, blue: 0.24)
            return [
                Color(red: 0.055, green: 0.07, blue: 0.14), Color(red: 0.06, green: 0.16, blue: 0.18), Color(red: 0.12, green: 0.08, blue: 0.21),
                Color(red: 0.07, green: 0.10, blue: 0.20), c,                                        Color(red: 0.11, green: 0.09, blue: 0.22),
                Color(red: 0.06, green: 0.13, blue: 0.17), Color(red: 0.08, green: 0.08, blue: 0.19), Color(red: 0.12, green: 0.08, blue: 0.20)
            ]
        } else {
            let c = warm ? Color(red: 1.00, green: 0.89, blue: 0.84) : Color(red: 0.89, green: 0.97, blue: 0.95)
            return [
                Color(red: 0.89, green: 0.97, blue: 0.95), Color(red: 0.89, green: 0.93, blue: 1.00), Color(red: 0.93, green: 0.91, blue: 0.98),
                Color(red: 0.90, green: 0.94, blue: 1.00), c,                                         Color(red: 0.92, green: 0.91, blue: 0.98),
                Color(red: 0.90, green: 0.97, blue: 0.94), Color(red: 0.91, green: 0.93, blue: 1.00), Color(red: 0.94, green: 0.92, blue: 0.99)
            ]
        }
    }

    var body: some View {
        if #available(iOS 18.0, *) {
            if reduceMotion {
                mesh(phase: 0)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 15.0)) { ctx in
                    mesh(phase: ctx.date.timeIntervalSinceReferenceDate)
                }
            }
        } else {
            LinearGradient(colors: [farben[0], farben[1], farben[2]], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    @available(iOS 18.0, *)
    private func mesh(phase t: Double) -> some View {
        // 60-s-Loop, sehr kleine Auslenkung der Mittelpunkte
        let w = t * (2 * .pi / 60)
        let dx = Float(sin(w)) * 0.06
        let dy = Float(cos(w)) * 0.06
        let punkte: [SIMD2<Float>] = [
            SIMD2<Float>(0, 0), SIMD2<Float>(0.5 + dx, 0), SIMD2<Float>(1, 0),
            SIMD2<Float>(0, 0.5 - dy), SIMD2<Float>(0.5 + dy, 0.5 + dx), SIMD2<Float>(1, 0.5 + dy),
            SIMD2<Float>(0, 1), SIMD2<Float>(0.5 - dx, 1), SIMD2<Float>(1, 1)
        ]
        return MeshGradient(
            width: 3, height: 3,
            points: punkte,
            colors: farben
        )
        .animation(.easeInOut(duration: 1.2), value: warm)
    }
}

// MARK: - Buttons

struct GlassPrimaryButtonStyle: ButtonStyle {
    var tint: Color = .accentColor
    var hoehe: CGFloat = 64

    func makeBody(configuration: Configuration) -> some View {
        let form = RoundedRectangle(cornerRadius: 22, style: .continuous)
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: hoehe)
            .background(
                form.fill(LinearGradient(colors: [tint, tint.opacity(0.78)], startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                form.strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.6), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1
                )
            )
            .shadow(color: tint.opacity(0.35), radius: 14, x: 0, y: 8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct GlassSecondaryButtonStyle: ButtonStyle {
    var hoehe: CGFloat = 56
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.bold())
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, minHeight: hoehe)
            .glassBackground(radius: 20)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GlassPrimaryButtonStyle {
    static func glassPrimary(tint: Color, hoehe: CGFloat = 64) -> GlassPrimaryButtonStyle { .init(tint: tint, hoehe: hoehe) }
}

extension ButtonStyle where Self == GlassSecondaryButtonStyle {
    static var glassSecondary: GlassSecondaryButtonStyle { .init() }
}

// MARK: - Chip

struct GlassChip: View {
    let titel: String
    var symbol: String? = nil
    var aktiv: Bool = false
    var tint: Color = .accentColor
    var aktion: () -> Void

    var body: some View {
        Button(action: aktion) {
            HStack(spacing: 6) {
                if let symbol { Image(systemName: symbol).font(.subheadline) }
                Text(titel).font(.subheadline.weight(aktiv ? .bold : .regular)).lineLimit(1)
            }
            .foregroundStyle(aktiv ? Color.white : Color.primary)
            .padding(.horizontal, 16)
            .frame(minHeight: 48)
            .background {
                if aktiv {
                    Capsule().fill(tint.gradient)
                } else {
                    Capsule().fill(.ultraThinMaterial)
                }
            }
            .overlay(Capsule().strokeBorder(Color.white.opacity(aktiv ? 0.4 : 0.5), lineWidth: 1))
            .shadow(color: aktiv ? tint.opacity(0.3) : .black.opacity(0.04), radius: aktiv ? 8 : 4, y: 3)
            .animation(.easeInOut(duration: 0.15), value: aktiv)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(aktiv ? .isSelected : [])
    }
}

// MARK: - Section-Label

struct GlassSectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .tracking(0.6)
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}

// MARK: - Schmerz-Hilfen

enum SchmerzSkala {
    static func wort(_ s: Int) -> String {
        switch s {
        case 0:     return "Kein Schmerz"
        case 1...3: return "Leicht"
        case 4...6: return "Mittel"
        case 7...8: return "Stark"
        default:    return "Unerträglich"
        }
    }
}

// MARK: - Gauge

struct SchmerzGauge: View {
    /// 0–10 (Nachkomma erlaubt für Durchschnitte)
    let wert: Double
    var groesse: CGFloat = 170
    var zahlGroesse: CGFloat = 72
    var nachkomma: Bool = false
    var platzhalter: Bool = false

    var body: some View {
        let farbe = platzhalter ? Color.secondary : SchmerzBadge.farbe(fuer: Int(wert.rounded()))
        ZStack {
            Circle().stroke(Color.primary.opacity(0.08), lineWidth: 14)
            Circle()
                .trim(from: 0, to: platzhalter ? 0 : max(0.02, min(wert / 10, 1)))
                .stroke(
                    AngularGradient(colors: [farbe.opacity(0.5), farbe], center: .center, startAngle: .degrees(0), endAngle: .degrees(360 * max(wert / 10, 0.02))),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: farbe.opacity(0.35), radius: 8)
                .animation(.spring(duration: 0.5), value: wert)
            Text(platzhalter ? "–" : (nachkomma ? String(format: "%.1f", wert) : "\(Int(wert.rounded()))"))
                .font(.system(size: zahlGroesse, weight: .bold, design: .rounded))
                .foregroundStyle(farbe)
                .contentTransition(.numericText())
                .minimumScaleFactor(0.5)
        }
        .frame(width: groesse, height: groesse)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Schmerzstärke")
        .accessibilityValue("\(String(format: "%.1f", wert)) von 10, \(SchmerzSkala.wort(Int(wert.rounded())))")
    }
}

// MARK: - Großer Schmerz-Slider

struct SchmerzSlider: View {
    @Binding var wert: Int
    private let trackHoehe: CGFloat = 20
    private let perle: CGFloat = 48

    var body: some View {
        GeometryReader { geo in
            let breite = geo.size.width - perle
            let x = breite * CGFloat(wert) / 10
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(LinearGradient(colors: [.green, .yellow, .orange, .red], startPoint: .leading, endPoint: .trailing))
                    .opacity(0.85)
                    .frame(height: trackHoehe)
                    .padding(.horizontal, perle / 2)
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.5), lineWidth: 1).frame(height: trackHoehe).padding(.horizontal, perle / 2))
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(Circle().fill(Color.white.opacity(0.6)))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.9), lineWidth: 1.5))
                    .overlay(Text("\(wert)").font(.system(.headline, design: .rounded).bold()).foregroundStyle(.primary))
                    .frame(width: perle, height: perle)
                    .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
                    .offset(x: x)
            }
            .frame(height: 64)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { g in
                    let neu = Int((((g.location.x - perle / 2) / max(breite, 1)) * 10).rounded())
                    let begrenzt = min(max(neu, 0), 10)
                    if begrenzt != wert {
                        wert = begrenzt
#if os(iOS)
                        UISelectionFeedbackGenerator().selectionChanged()
#endif
                    }
                }
            )
        }
        .frame(height: 64)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Schmerzstärke")
        .accessibilityValue("\(wert) von 10")
        .accessibilityAdjustableAction { richtung in
            switch richtung {
            case .increment: wert = min(wert + 1, 10)
            case .decrement: wert = max(wert - 1, 0)
            @unknown default: break
            }
        }
    }
}
