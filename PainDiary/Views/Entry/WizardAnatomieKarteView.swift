import SwiftUI

struct WizardAnatomieKarteView: View {
    @Binding var koerperstelle: String
    @State private var vorne = true
    @State private var drehwinkel: Double = 0

    private var ausgewaehlt: Set<String> {
        Set(koerperstelle.components(separatedBy: ", ").filter { !$0.isEmpty })
    }

    var body: some View {
        VStack(spacing: 14) {
            Text("Wo hast du Schmerzen?")
                .font(.title2.bold())

            Picker("", selection: $vorne) {
                Text("Vorne").tag(true)
                Text("Hinten").tag(false)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 50)

            AnatomieKoerperView(vorne: vorne, ausgewaehlt: ausgewaehlt, onTap: toggle)
                .frame(height: 420)
                .rotation3DEffect(.degrees(drehwinkel), axis: (0, 1, 0))
                .gesture(
                    DragGesture(minimumDistance: 40)
                        .onEnded { v in
                            guard abs(v.translation.width) > abs(v.translation.height) else { return }
                            flipAnimation(nachLinks: v.translation.width < 0)
                        }
                )

            if ausgewaehlt.isEmpty {
                Text("Tippe auf eine Körperstelle")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(height: 30)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(ausgewaehlt.sorted(), id: \.self) { r in
                            Button { toggle(r) } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                                    Text(r).font(.caption)
                                }
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color.red.opacity(0.12))
                                .foregroundStyle(.red)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 30)
            }

            Label("Wischen zum Umdrehen", systemImage: "arrow.left.and.right")
                .font(.caption2).foregroundStyle(.tertiary)
        }
    }

    private func flipAnimation(nachLinks: Bool) {
        withAnimation(.easeIn(duration: 0.18)) { drehwinkel = nachLinks ? -90 : 90 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            vorne.toggle()
            drehwinkel = nachLinks ? 90 : -90
            withAnimation(.easeOut(duration: 0.18)) { drehwinkel = 0 }
        }
    }

    private func toggle(_ name: String) {
        var s = ausgewaehlt
        if s.contains(name) { s.remove(name) } else { s.insert(name) }
        koerperstelle = s.sorted().joined(separator: ", ")
    }
}

// MARK: - Anatomical Body Map

private struct AnatomieKoerperView: View {
    let vorne: Bool
    let ausgewaehlt: Set<String>
    let onTap: (String) -> Void

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let regions = vorne ? BodyRegion.vorne : BodyRegion.hinten
            ZStack {
                ForEach(regions) { region in
                    let sel = ausgewaehlt.contains(region.name)
                    BodyRegionView(region: region, size: size, selected: sel) {
                        onTap(region.name)
                    }
                }
            }
        }
    }
}

private struct BodyRegionView: View {
    let region: BodyRegion
    let size: CGSize
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        let shape = BodyRegionShape(fn: region.fn, size: size)
        shape
            .fill(selected ? Color.red.opacity(0.38) : Color(.systemGray5))
            .overlay(
                shape.stroke(
                    selected ? Color.red.opacity(0.60) : Color.secondary.opacity(0.22),
                    lineWidth: 1.3
                )
            )
            .contentShape(shape)
            .onTapGesture(perform: onTap)
            .animation(.spring(response: 0.2), value: selected)
    }
}

private struct BodyRegionShape: Shape {
    let fn: (CGSize) -> Path
    let size: CGSize
    func path(in rect: CGRect) -> Path { fn(size) }
}

// MARK: - Body Region Definitions

private struct BodyRegion: Identifiable {
    var id: String { name }
    let name: String
    let fn: (CGSize) -> Path

    // Horizontally mirrors a path (left ↔ right)
    static func mirrored(_ f: @escaping (CGSize) -> Path) -> (CGSize) -> Path {
        { size in
            let t = CGAffineTransform(translationX: size.width, y: 0).scaledBy(x: -1, y: 1)
            return f(size).applying(t)
        }
    }

    // MARK: – Head & neck

    static func kopf(_ s: CGSize) -> Path {
        Path(ellipseIn: CGRect(x: s.width*0.372, y: s.height*0.004,
                               width: s.width*0.256, height: s.height*0.114))
    }

    static func nacken(_ s: CGSize) -> Path {
        let w = s.width * 0.108, h = s.height * 0.044
        return Path(roundedRect: CGRect(x: (s.width - w) / 2, y: s.height * 0.115,
                                        width: w, height: h), cornerRadius: w / 2)
    }

    // MARK: – Shoulders (left; mirrored for right)

    static func schulterLinks(_ s: CGSize) -> Path {
        let (sw, sh) = (s.width, s.height)
        var p = Path()
        p.move(to:    CGPoint(x: sw*0.296, y: sh*0.154))
        p.addCurve(to: CGPoint(x: sw*0.138, y: sh*0.175),
                   control1: CGPoint(x: sw*0.243, y: sh*0.148),
                   control2: CGPoint(x: sw*0.176, y: sh*0.154))
        p.addCurve(to: CGPoint(x: sw*0.142, y: sh*0.226),
                   control1: CGPoint(x: sw*0.098, y: sh*0.182),
                   control2: CGPoint(x: sw*0.098, y: sh*0.220))
        p.addCurve(to: CGPoint(x: sw*0.296, y: sh*0.228),
                   control1: CGPoint(x: sw*0.180, y: sh*0.240),
                   control2: CGPoint(x: sw*0.248, y: sh*0.234))
        p.closeSubpath()
        return p
    }

    // MARK: – Torso

    static func brust(_ s: CGSize) -> Path {
        let (sw, sh) = (s.width, s.height)
        var p = Path()
        p.move(to:    CGPoint(x: sw*0.296, y: sh*0.154))
        p.addLine(to: CGPoint(x: sw*0.704, y: sh*0.154))
        p.addCurve(to: CGPoint(x: sw*0.692, y: sh*0.298),
                   control1: CGPoint(x: sw*0.724, y: sh*0.198),
                   control2: CGPoint(x: sw*0.708, y: sh*0.272))
        p.addLine(to: CGPoint(x: sw*0.308, y: sh*0.298))
        p.addCurve(to: CGPoint(x: sw*0.296, y: sh*0.154),
                   control1: CGPoint(x: sw*0.292, y: sh*0.272),
                   control2: CGPoint(x: sw*0.276, y: sh*0.198))
        p.closeSubpath()
        return p
    }

    static func bauch(_ s: CGSize) -> Path {
        let (sw, sh) = (s.width, s.height)
        var p = Path()
        p.move(to:    CGPoint(x: sw*0.308, y: sh*0.298))
        p.addLine(to: CGPoint(x: sw*0.692, y: sh*0.298))
        p.addCurve(to: CGPoint(x: sw*0.714, y: sh*0.440),
                   control1: CGPoint(x: sw*0.708, y: sh*0.340),
                   control2: CGPoint(x: sw*0.724, y: sh*0.412))
        p.addLine(to: CGPoint(x: sw*0.286, y: sh*0.440))
        p.addCurve(to: CGPoint(x: sw*0.308, y: sh*0.298),
                   control1: CGPoint(x: sw*0.276, y: sh*0.412),
                   control2: CGPoint(x: sw*0.292, y: sh*0.340))
        p.closeSubpath()
        return p
    }

    static func huefte(_ s: CGSize) -> Path {
        let (sw, sh) = (s.width, s.height)
        var p = Path()
        p.move(to:    CGPoint(x: sw*0.286, y: sh*0.440))
        p.addLine(to: CGPoint(x: sw*0.714, y: sh*0.440))
        p.addCurve(to: CGPoint(x: sw*0.738, y: sh*0.538),
                   control1: CGPoint(x: sw*0.734, y: sh*0.462),
                   control2: CGPoint(x: sw*0.750, y: sh*0.510))
        p.addLine(to: CGPoint(x: sw*0.262, y: sh*0.538))
        p.addCurve(to: CGPoint(x: sw*0.286, y: sh*0.440),
                   control1: CGPoint(x: sw*0.250, y: sh*0.510),
                   control2: CGPoint(x: sw*0.266, y: sh*0.462))
        p.closeSubpath()
        return p
    }

    // MARK: – Arms (left; mirrored for right)

    static func oberarmLinks(_ s: CGSize) -> Path {
        let (sw, sh) = (s.width, s.height)
        let rw = sw * 0.044, rh = sh * 0.092
        return Path(roundedRect: CGRect(x: sw*0.168 - rw, y: sh*0.222, width: rw*2, height: rh*2),
                    cornerRadius: rw)
    }

    static func unterarmLinks(_ s: CGSize) -> Path {
        let (sw, sh) = (s.width, s.height)
        let rw = sw * 0.037, rh = sh * 0.078
        return Path(roundedRect: CGRect(x: sw*0.140 - rw, y: sh*0.400, width: rw*2, height: rh*2),
                    cornerRadius: rw)
    }

    static func handLinks(_ s: CGSize) -> Path {
        Path(ellipseIn: CGRect(x: s.width*0.082, y: s.height*0.549,
                               width: s.width*0.116, height: s.height*0.068))
    }

    // MARK: – Legs (left; mirrored for right)

    static func oberschenkelLinks(_ s: CGSize) -> Path {
        let (sw, sh) = (s.width, s.height)
        let rw = sw * 0.078, rh = sh * 0.096
        return Path(roundedRect: CGRect(x: sw*0.374 - rw, y: sh*0.540, width: rw*2, height: rh*2),
                    cornerRadius: rw)
    }

    static func unterschenkelLinks(_ s: CGSize) -> Path {
        let (sw, sh) = (s.width, s.height)
        let rw = sw * 0.063, rh = sh * 0.088
        return Path(roundedRect: CGRect(x: sw*0.366 - rw, y: sh*0.738, width: rw*2, height: rh*2),
                    cornerRadius: rw)
    }

    static func fussLinks(_ s: CGSize) -> Path {
        Path(ellipseIn: CGRect(x: s.width*0.264, y: s.height*0.914,
                               width: s.width*0.194, height: s.height*0.068))
    }

    // MARK: – Region arrays

    static let vorne: [BodyRegion] = [
        BodyRegion(name: "Kopf",                 fn: kopf),
        BodyRegion(name: "Nacken",               fn: nacken),
        BodyRegion(name: "Brust",                fn: brust),
        BodyRegion(name: "Bauch",                fn: bauch),
        BodyRegion(name: "Hüfte",                fn: huefte),
        BodyRegion(name: "Schulter links",       fn: schulterLinks),
        BodyRegion(name: "Schulter rechts",      fn: mirrored(schulterLinks)),
        BodyRegion(name: "Oberarm links",        fn: oberarmLinks),
        BodyRegion(name: "Oberarm rechts",       fn: mirrored(oberarmLinks)),
        BodyRegion(name: "Unterarm links",       fn: unterarmLinks),
        BodyRegion(name: "Unterarm rechts",      fn: mirrored(unterarmLinks)),
        BodyRegion(name: "Hand links",           fn: handLinks),
        BodyRegion(name: "Hand rechts",          fn: mirrored(handLinks)),
        BodyRegion(name: "Oberschenkel links",   fn: oberschenkelLinks),
        BodyRegion(name: "Oberschenkel rechts",  fn: mirrored(oberschenkelLinks)),
        BodyRegion(name: "Unterschenkel links",  fn: unterschenkelLinks),
        BodyRegion(name: "Unterschenkel rechts", fn: mirrored(unterschenkelLinks)),
        BodyRegion(name: "Fuss links",           fn: fussLinks),
        BodyRegion(name: "Fuss rechts",          fn: mirrored(fussLinks)),
    ]

    static let hinten: [BodyRegion] = [
        BodyRegion(name: "Kopf",                 fn: kopf),
        BodyRegion(name: "Nacken",               fn: nacken),
        BodyRegion(name: "Rücken oben",          fn: brust),
        BodyRegion(name: "Rücken unten",         fn: bauch),
        BodyRegion(name: "Gesäss",               fn: huefte),
        BodyRegion(name: "Schulter links",       fn: schulterLinks),
        BodyRegion(name: "Schulter rechts",      fn: mirrored(schulterLinks)),
        BodyRegion(name: "Oberarm links",        fn: oberarmLinks),
        BodyRegion(name: "Oberarm rechts",       fn: mirrored(oberarmLinks)),
        BodyRegion(name: "Unterarm links",       fn: unterarmLinks),
        BodyRegion(name: "Unterarm rechts",      fn: mirrored(unterarmLinks)),
        BodyRegion(name: "Hand links",           fn: handLinks),
        BodyRegion(name: "Hand rechts",          fn: mirrored(handLinks)),
        BodyRegion(name: "Oberschenkel links",   fn: oberschenkelLinks),
        BodyRegion(name: "Oberschenkel rechts",  fn: mirrored(oberschenkelLinks)),
        BodyRegion(name: "Unterschenkel links",  fn: unterschenkelLinks),
        BodyRegion(name: "Unterschenkel rechts", fn: mirrored(unterschenkelLinks)),
        BodyRegion(name: "Fuss links",           fn: fussLinks),
        BodyRegion(name: "Fuss rechts",          fn: mirrored(fussLinks)),
    ]
}
