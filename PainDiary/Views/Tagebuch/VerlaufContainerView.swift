import SwiftUI

enum VerlaufSegment: String, CaseIterable, Identifiable {
    case liste = "Liste"
    case einblicke = "Einblicke"
    var id: String { rawValue }
}

/// Glas-Segmented-Control (44 pt) für „Liste | Einblicke".
struct VerlaufSegmentPicker: View {
    @Binding var auswahl: VerlaufSegment
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 4) {
            ForEach(VerlaufSegment.allCases) { seg in
                let aktiv = auswahl == seg
                Button {
                    withAnimation(.spring(duration: 0.3)) { auswahl = seg }
                } label: {
                    Text(seg.rawValue)
                        .font(.subheadline.weight(aktiv ? .bold : .regular))
                        .foregroundStyle(aktiv ? Color.primary : Color.secondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background {
                            if aktiv {
                                Capsule()
                                    .fill(Color.white.opacity(0.55))
                                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.8), lineWidth: 1))
                                    .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
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

/// Tab „Verlauf": Tagebuch-Liste und Einblicke (frühere Dashboard-Kacheln) in einem Screen.
struct VerlaufContainerView: View {
    @State private var segment: VerlaufSegment = .liste

    var body: some View {
        Group {
            switch segment {
            case .liste:     PainEntryListView(segment: $segment)
            case .einblicke: DashboardView(segment: $segment)
            }
        }
    }
}
