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

/// Akzentfarbe des aktuellen Screens (kommt aus `auroraScreen(_:)`), färbt den Karten-Schatten.
private struct GlasAkzentKey: EnvironmentKey {
    static let defaultValue: Color = .black
}

extension EnvironmentValues {
    var glasAkzent: Color {
        get { self[GlasAkzentKey.self] }
        set { self[GlasAkzentKey.self] = newValue }
    }
}

/// Der eine Glas-Stil der App („Zyklus-Glas"): `.ultraThinMaterial`, 1-pt-Kontur, weicher Akzent-Schatten.
struct GlassCardModifier: ViewModifier {
    var radius: CGFloat = 24
    var tint: Color? = nil
    var padding: CGFloat? = nil
    var schatten: Bool = true

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var scheme
    @Environment(\.glasAkzent) private var akzent

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
                    }
                    if let tint { form.fill(tint.opacity(scheme == .dark ? 0.12 : 0.08)) }
                }
            }
            .overlay {
                form.strokeBorder(Color.white.opacity(scheme == .dark ? 0.22 : 0.35), lineWidth: 1)
            }
            .clipShape(form)
            .shadow(color: schatten ? akzent.opacity(akzent == .black ? 0.06 : 0.10) : .clear, radius: 14, x: 0, y: 6)
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
    func auroraScreen(_ theme: AuroraTheme = .neutral, schmerzLevel: Int? = nil) -> some View {
        environment(\.glasAkzent, theme.akzent)
            .background(AuroraBackground(theme: theme, schmerzLevel: schmerzLevel).ignoresSafeArea())
    }

    /// Liste auf Aurora-Hintergrund mit Glas-Zeilen.
    func glassList(_ theme: AuroraTheme = .neutral, schmerzLevel: Int? = nil) -> some View {
        self
            .scrollContentBackground(.hidden)
            .environment(\.glasAkzent, theme.akzent)
            .background(AuroraBackground(theme: theme, schmerzLevel: schmerzLevel).ignoresSafeArea())
    }

    /// Glas-Leisten für Navigation und Tab-Bar.
    func glassBars() -> some View {
        self
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .tabBar)
    }
}

// MARK: - Aurora-Hintergrund

/// Thematische Hintergründe pro Bereich. `.neutral` ist der ursprüngliche Aurora-Verlauf.
enum AuroraTheme {
    case neutral, schmerz, medikamente, statistik, migraene, zyklus, rheuma, haut, diabetes, wellness

    /// Akzent für Karten-Schatten.
    var akzent: Color {
        switch self {
        case .neutral:     return .teal
        case .schmerz:     return .blue
        case .medikamente: return .orange
        case .statistik:   return .indigo
        case .migraene:    return .purple
        case .zyklus:      return .pink
        case .rheuma:      return .teal
        case .haut:        return .orange
        case .diabetes:    return .blue
        case .wellness:    return .mint
        }
    }

    /// Migräne ist reizempfindlich: kein bewegter Hintergrund.
    var animiert: Bool { self != .migraene }

    /// Fünf Farbtöne (Ecken oben links/rechts, unten links/rechts, Mitte) und Stärke im hellen Modus.
    fileprivate var farbtoene: (a: RGB, b: RGB, c: RGB, d: RGB, m: RGB, staerke: Double)? {
        switch self {
        case .neutral:     return nil
        case .schmerz:     return (RGB(0.30, 0.62, 0.95), RGB(0.35, 0.85, 0.75), RGB(0.40, 0.50, 0.95), RGB(0.45, 0.85, 0.80), RGB(0.35, 0.75, 0.90), 0.22)
        case .medikamente: return (RGB(1.00, 0.72, 0.50), RGB(1.00, 0.85, 0.45), RGB(1.00, 0.62, 0.45), RGB(1.00, 0.80, 0.55), RGB(1.00, 0.76, 0.52), 0.30)
        case .statistik:   return (RGB(0.45, 0.45, 0.95), RGB(0.65, 0.45, 0.95), RGB(0.55, 0.55, 1.00), RGB(0.75, 0.55, 0.95), RGB(0.58, 0.50, 0.95), 0.24)
        case .migraene:    return (RGB(0.55, 0.50, 0.75), RGB(0.45, 0.50, 0.65), RGB(0.50, 0.45, 0.70), RGB(0.55, 0.55, 0.70), RGB(0.50, 0.50, 0.70), 0.18)
        case .zyklus:      return (RGB(1.00, 0.55, 0.69), RGB(1.00, 0.75, 0.55), RGB(0.74, 0.65, 1.00), RGB(1.00, 0.60, 0.75), RGB(0.95, 0.65, 0.80), 0.30)
        case .rheuma:      return (RGB(0.20, 0.75, 0.75), RGB(0.55, 0.80, 1.00), RGB(0.30, 0.70, 0.85), RGB(0.50, 0.85, 0.90), RGB(0.40, 0.78, 0.85), 0.24)
        case .haut:        return (RGB(1.00, 0.70, 0.45), RGB(0.95, 0.80, 0.60), RGB(0.90, 0.72, 0.55), RGB(1.00, 0.78, 0.60), RGB(0.97, 0.75, 0.55), 0.26)
        case .diabetes:    return (RGB(0.35, 0.65, 1.00), RGB(0.30, 0.85, 0.95), RGB(0.45, 0.70, 1.00), RGB(0.40, 0.80, 0.95), RGB(0.38, 0.75, 1.00), 0.24)
        case .wellness:    return (RGB(0.40, 0.85, 0.70), RGB(0.65, 0.85, 0.60), RGB(0.45, 0.80, 0.65), RGB(0.60, 0.85, 0.70), RGB(0.50, 0.85, 0.68), 0.26)
        }
    }

    /// 3×3-Mesh-Farben für den Modus.
    fileprivate func mesh(dunkel: Bool, warm: Bool) -> [Color]? {
        guard let t = farbtoene else { return nil }
        let basis = dunkel ? RGB(0.06, 0.07, 0.12) : RGB(1, 1, 1)
        let anteil = dunkel ? 0.26 : t.staerke
        func f(_ x: RGB) -> RGB { basis.mischen(x, anteil) }
        let a = f(t.a), b = f(t.b), c = f(t.c), d = f(t.d)
        var m = f(t.m)
        if warm { m = dunkel ? RGB(0.30, 0.16, 0.20) : RGB(1.00, 0.89, 0.84) }
        return [a, a.mischen(b, 0.5), b,
                a.mischen(c, 0.5), m, b.mischen(d, 0.5),
                c, c.mischen(d, 0.5), d].map(\.color)
    }
}

fileprivate struct RGB {
    let r: Double, g: Double, b: Double
    init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }
    func mischen(_ o: RGB, _ t: Double) -> RGB { RGB(r + (o.r - r) * t, g + (o.g - g) * t, b + (o.b - b) * t) }
    var color: Color { Color(red: r, green: g, blue: b) }
}

struct AuroraBackground: View {
    var theme: AuroraTheme = .neutral
    /// 0–10; ab 7 wandert ein Punkt zu einem warmen Pfirsich-Ton (kein Alarm-Rot).
    var schmerzLevel: Int? = nil

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var warm: Bool { (schmerzLevel ?? 0) >= 7 }

    private var farben: [Color] {
        if let themed = theme.mesh(dunkel: scheme == .dark, warm: warm) { return themed }
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
            if reduceMotion || !theme.animiert {
                mesh(phase: 0)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 15.0)) { ctx in
                    mesh(phase: ctx.date.timeIntervalSinceReferenceDate)
                }
            }
        } else {
            LinearGradient(colors: [farben[0], farben[4], farben[8]], startPoint: .topLeading, endPoint: .bottomTrailing)
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

// MARK: - Wizard-Bausteine

extension View {
    /// Primär-Aktion in Wizards (Weiter / Speichern): Tint-Verlauf, heller Rand, weicher Glow.
    /// Drop-in für `.background(tint, in: RoundedRectangle(cornerRadius: N))`.
    func glassTintBackground(_ tint: Color, radius: CGFloat = 12) -> some View {
        let form = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return self
            .background(form.fill(LinearGradient(colors: [tint, tint.opacity(0.8)], startPoint: .top, endPoint: .bottom)))
            .overlay(
                form.strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1
                )
            )
            .shadow(color: tint.opacity(0.28), radius: 10, x: 0, y: 5)
    }
}

/// Glas-Fortschrittsbalken (Capsule, 3 pt) in Modul-Tint.
struct GlassProgressBar: View {
    var tint: Color
    /// 0...1
    var fortschritt: CGFloat
    var schritt: Int = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.ultraThinMaterial)
                    .overlay(Capsule().fill(tint.opacity(0.15)))
                Capsule()
                    .fill(LinearGradient(colors: [tint.opacity(0.7), tint], startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * fortschritt)
                    .shadow(color: tint.opacity(0.5), radius: 4)
                    .animation(.easeInOut(duration: 0.3), value: schritt)
            }
        }
        .frame(height: 3)
        .accessibilityHidden(true)
    }
}
