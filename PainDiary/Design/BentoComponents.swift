import SwiftUI

// MARK: - Ansicht Heute | Verlauf

/// Gemeinsame Ansichten der Modul-Dashboards (Segment-Picker).
enum ModulAnsicht: String, CaseIterable {
    case heute = "Heute"
    case verlauf = "Verlauf"
}

// MARK: - Link-Zeile

/// Breite Glas-Zeile mit Icon, Titel und Chevron, die zu einem Unterbereich führt (z. B. „Kortison-Tagebuch").
struct GlassLinkZeile<Ziel: View>: View {
    let symbol: String
    let titel: String
    var untertitel: String? = nil
    var tint: Color = .accentColor
    @ViewBuilder var ziel: () -> Ziel

    var body: some View {
        NavigationLink(destination: ziel()) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(tint.opacity(0.18)))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.45), lineWidth: 1))
                VStack(alignment: .leading, spacing: 2) {
                    Text(titel).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    if let untertitel {
                        Text(untertitel).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
            }
            .frame(minHeight: 44)
            .glassCard(radius: 22, padding: 14)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Segment-Picker (Glas)

/// Glas-Segmented-Control (44 pt) für beliebige Auswahlwerte, z. B. „Heute | Verlauf".
struct GlassSegmentPicker<Wert: Hashable>: View {
    @Binding var auswahl: Wert
    let optionen: [Wert]
    let titel: (Wert) -> String

    @Namespace private var ns

    var body: some View {
        HStack(spacing: 4) {
            ForEach(optionen, id: \.self) { option in
                let aktiv = auswahl == option
                Button {
                    withAnimation(.spring(duration: 0.3)) { auswahl = option }
                } label: {
                    Text(titel(option))
                        .font(.subheadline.weight(aktiv ? .bold : .regular))
                        .foregroundStyle(aktiv ? Color.primary : Color.secondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background {
                            if aktiv {
                                Capsule()
                                    .fill(Color.white.opacity(0.35))
                                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.6), lineWidth: 1))
                                    .shadow(color: .black.opacity(0.10), radius: 6, y: 2)
                                    .matchedGeometryEffect(id: "segment", in: ns)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(aktiv ? .isSelected : [])
            }
        }
        .padding(4)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.4), lineWidth: 1))
    }
}

// MARK: - Pille

/// Kleine Info-Kapsel (Trend, Durchschnitt …).
struct GlassPille: View {
    let text: String
    var tint: Color? = nil

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background {
                Capsule().fill(.ultraThinMaterial)
                if let tint { Capsule().fill(tint.opacity(0.22)) }
            }
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.4), lineWidth: 1))
    }
}

// MARK: - Bento-Kachel

/// Quadratische Glas-Kachel fürs Bento-Raster: Icon oben, Inhalt (Kennwert/Sparkline) in der Mitte, Label unten.
struct BentoKachel<Inhalt: View>: View {
    let symbol: String
    let label: String
    var tint: Color = .accentColor
    /// Leuchtendes Icon (z. B. für Warn-/Schmerzwerte).
    var leuchtet: Bool = false
    @ViewBuilder var inhalt: () -> Inhalt

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(leuchtet ? Color.white : tint)
                .frame(width: 32, height: 32)
                .background {
                    Circle().fill(tint.opacity(leuchtet ? 0.55 : 0.18))
                }
                .overlay(Circle().strokeBorder(Color.white.opacity(0.45), lineWidth: 1))
                .shadow(color: leuchtet ? tint.opacity(0.8) : .clear, radius: 8)
                .accessibilityHidden(true)
            Spacer(minLength: 0)
            inhalt()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .glassCard(radius: 22, padding: 14)
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .combine)
    }
}

extension BentoKachel {
    /// Kachel mit großem Kennwert und optionaler Einheit.
    init(symbol: String, label: String, tint: Color = .accentColor, leuchtet: Bool = false, wert: String, einheit: String? = nil, klein: Bool = false) where Inhalt == KennwertInhalt {
        self.init(symbol: symbol, label: label, tint: tint, leuchtet: leuchtet) {
            KennwertInhalt(wert: wert, einheit: einheit, klein: klein)
        }
    }
}

struct KennwertInhalt: View {
    let wert: String
    var einheit: String?
    var klein = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(wert)
                .font(klein ? .system(.title3, design: .rounded).bold() : .system(size: 34, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(klein ? 2 : 1)
                .contentTransition(.numericText())
            if let einheit {
                Text(einheit)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Eintrags-Chip

/// Kompakter Glas-Chip für einen Eintrag: Kreis mit Zahl links, zwei Textzeilen rechts.
struct GlassEintragChip: View {
    var zahl: Int? = nil
    var symbol: String? = nil
    let titel: String
    let untertitel: String
    var tint: Color = .red
    var hervorgehoben = false
    /// Chip füllt die verfügbare Breite (Verlauf) statt sich dem Inhalt anzupassen (Streifen).
    var volleBreite = false

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let zahl {
                    Text("\(zahl)").font(.system(.subheadline, design: .rounded).bold())
                } else if let symbol {
                    Image(systemName: symbol).font(.system(size: 16, weight: .semibold))
                }
            }
                .foregroundStyle(hervorgehoben ? Color.white : tint)
                .frame(width: 40, height: 40)
                .background(Circle().fill(tint.opacity(hervorgehoben ? 0.55 : 0.2)))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.45), lineWidth: 1))
                .shadow(color: hervorgehoben ? tint.opacity(0.8) : .clear, radius: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(titel).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).lineLimit(1)
                Text(untertitel).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            if volleBreite {
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption2.bold())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 16)
        .frame(minHeight: 56)
        .frame(maxWidth: volleBreite ? .infinity : nil, alignment: .leading)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.4), lineWidth: 1))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(zahl.map { "\(titel), Stärke \($0) von 10, \(SchmerzSkala.wort($0)). \(untertitel)" } ?? "\(titel). \(untertitel)")
    }
}
