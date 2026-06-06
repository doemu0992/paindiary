import SwiftUI

struct WizardAnatomieKarteView: View {
    @Binding var koerperstelle: String
    @StateObject private var scanService = BodyScanService.shared
    @State private var vorne = true
    @State private var drehwinkel: Double = 0
    @State private var scanSetupAnzeigen = false

    private var ausgewaehlt: Set<String> {
        Set(koerperstelle.components(separatedBy: ", ").filter { !$0.isEmpty })
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Wo hast du Schmerzen?")
                    .font(.title2.bold())
                Spacer()
                Button {
                    scanSetupAnzeigen = true
                } label: {
                    Label(scanService.hatScan ? "Neu scannen" : "Körper scannen",
                          systemImage: scanService.hatScan ? "arrow.triangle.2.circlepath" : "camera.viewfinder")
                        .font(.caption)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.accentColor.opacity(0.12))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Picker("", selection: $vorne) {
                Text("Vorne").tag(true)
                Text("Hinten").tag(false)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 50)

            KoerperKarteView(
                vorne: vorne,
                ausgewaehlt: ausgewaehlt,
                onTap: toggle,
                scanBild: vorne ? scanService.vorneBild : scanService.hintenBild
            )
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
        .sheet(isPresented: $scanSetupAnzeigen) {
            BodyScanSetupView()
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

// MARK: - Body Map with SVG background or personal scan

private struct KoerperKarteView: View {
    let vorne: Bool
    let ausgewaehlt: Set<String>
    let onTap: (String) -> Void
    let scanBild: UIImage?

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                if let bild = scanBild {
                    Image(uiImage: bild)
                        .resizable()
                        .renderingMode(.original)
                        .scaledToFit()
                        .frame(width: w, height: h)
                } else {
                    Image(vorne ? "body_vorne" : "body_hinten")
                        .resizable()
                        .renderingMode(.original)
                        .scaledToFit()
                        .frame(width: w, height: h)
                }

                // Clickable region overlays
                ForEach(vorne ? RegionDef.vorne : RegionDef.hinten) { region in
                    let sel = ausgewaehlt.contains(region.name)
                    let shape = RegionShape(region: region, w: w, h: h)
                    shape
                        .fill(sel ? Color.red.opacity(0.40) : Color.clear)
                        .overlay(
                            shape.stroke(
                                sel ? Color.red.opacity(0.65) : Color.clear,
                                lineWidth: 1.5
                            )
                        )
                        .contentShape(shape)
                        .onTapGesture { onTap(region.name) }
                        .animation(.spring(response: 0.2), value: sel)
                }
            }
        }
    }
}

// MARK: - Region shape (Bezier paths matching SVG layout)

private struct RegionShape: Shape {
    let region: RegionDef
    let w: CGFloat
    let h: CGFloat

    func path(in rect: CGRect) -> Path {
        region.buildPath(w, h)
    }
}

// MARK: - Region definitions (proportional to SVG 200×520 viewBox)

private struct RegionDef: Identifiable {
    var id: String { name }
    let name: String
    let buildPath: (CGFloat, CGFloat) -> Path

    // Maps SVG coords (200×520) to view coords, accounting for scaledToFit letterboxing
    static func svgScale(w: CGFloat, h: CGFloat) -> (scale: CGFloat, dx: CGFloat, dy: CGFloat) {
        let s = min(w / 200.0, h / 520.0)
        return (s, (w - 200.0 * s) / 2, (h - 520.0 * s) / 2)
    }

    static func p(_ x: Double, _ y: Double, w: CGFloat, h: CGFloat) -> CGPoint {
        let (s, dx, dy) = svgScale(w: w, h: h)
        return CGPoint(x: dx + CGFloat(x) * s, y: dy + CGFloat(y) * s)
    }

    static func ellipseRegion(name: String, cx: Double, cy: Double, rx: Double, ry: Double) -> RegionDef {
        RegionDef(name: name) { w, h in
            let (s, dx, dy) = svgScale(w: w, h: h)
            return Path(ellipseIn: CGRect(
                x: dx + CGFloat(cx - rx) * s,
                y: dy + CGFloat(cy - ry) * s,
                width: CGFloat(rx * 2) * s,
                height: CGFloat(ry * 2) * s
            ))
        }
    }

    static func capsuleRegion(name: String, cx: Double, cy: Double, rw: Double, rh: Double) -> RegionDef {
        RegionDef(name: name) { w, h in
            let (s, dx, dy) = svgScale(w: w, h: h)
            let sw = CGFloat(rw * 2) * s
            let sh = CGFloat(rh * 2) * s
            return Path(roundedRect: CGRect(
                x: dx + CGFloat(cx - rw) * s,
                y: dy + CGFloat(cy - rh) * s,
                width: sw, height: sh
            ), cornerRadius: min(sw, sh) / 2)
        }
    }

    // MARK: Vorne

    static let vorne: [RegionDef] = [
        // Head — matches SVG ellipse exactly
        ellipseRegion(name: "Kopf", cx: 100, cy: 32, rx: 26, ry: 30),
        // Throat (front neck) — SVG path y=60–76, x=88–112
        capsuleRegion(name: "Hals", cx: 100, cy: 68, rw: 11, rh: 8),
        // Left shoulder
        RegionDef(name: "Schulter links") { w, h in
            var p = Path()
            p.move(to:    Self.p(90, 76, w: w, h: h))
            p.addCurve(to: Self.p(50, 118, w: w, h: h),
                       control1: Self.p(68, 76, w: w, h: h),
                       control2: Self.p(50, 95, w: w, h: h))
            p.addCurve(to: Self.p(68, 108, w: w, h: h),
                       control1: Self.p(50, 118, w: w, h: h),
                       control2: Self.p(58, 114, w: w, h: h))
            p.addCurve(to: Self.p(90, 98, w: w, h: h),
                       control1: Self.p(78, 102, w: w, h: h),
                       control2: Self.p(84, 99, w: w, h: h))
            p.closeSubpath()
            return p
        },
        // Right shoulder (mirrored)
        RegionDef(name: "Schulter rechts") { w, h in
            var p = Path()
            p.move(to:    Self.p(110, 76, w: w, h: h))
            p.addCurve(to: Self.p(150, 118, w: w, h: h),
                       control1: Self.p(132, 76, w: w, h: h),
                       control2: Self.p(150, 95, w: w, h: h))
            p.addCurve(to: Self.p(132, 108, w: w, h: h),
                       control1: Self.p(150, 118, w: w, h: h),
                       control2: Self.p(142, 114, w: w, h: h))
            p.addCurve(to: Self.p(110, 98, w: w, h: h),
                       control1: Self.p(122, 102, w: w, h: h),
                       control2: Self.p(116, 99, w: w, h: h))
            p.closeSubpath()
            return p
        },
        // Chest (upper torso)
        RegionDef(name: "Brust") { w, h in
            var p = Path()
            p.move(to:    Self.p(68, 108, w: w, h: h))
            p.addCurve(to: Self.p(70, 178, w: w, h: h),
                       control1: Self.p(60, 132, w: w, h: h),
                       control2: Self.p(64, 158, w: w, h: h))
            p.addLine(to: Self.p(130, 178, w: w, h: h))
            p.addCurve(to: Self.p(132, 108, w: w, h: h),
                       control1: Self.p(136, 158, w: w, h: h),
                       control2: Self.p(140, 132, w: w, h: h))
            p.addCurve(to: Self.p(112, 98, w: w, h: h),
                       control1: Self.p(128, 106, w: w, h: h),
                       control2: Self.p(121, 101, w: w, h: h))
            p.addLine(to: Self.p(90, 98, w: w, h: h))
            p.addCurve(to: Self.p(68, 108, w: w, h: h),
                       control1: Self.p(79, 101, w: w, h: h),
                       control2: Self.p(72, 106, w: w, h: h))
            p.closeSubpath()
            return p
        },
        // Abdomen
        RegionDef(name: "Bauch") { w, h in
            var p = Path()
            p.move(to:    Self.p(70, 178, w: w, h: h))
            p.addLine(to: Self.p(130, 178, w: w, h: h))
            p.addCurve(to: Self.p(122, 220, w: w, h: h),
                       control1: Self.p(136, 196, w: w, h: h),
                       control2: Self.p(130, 210, w: w, h: h))
            p.addLine(to: Self.p(78, 220, w: w, h: h))
            p.addCurve(to: Self.p(70, 178, w: w, h: h),
                       control1: Self.p(70, 210, w: w, h: h),
                       control2: Self.p(64, 196, w: w, h: h))
            p.closeSubpath()
            return p
        },
        // Hips
        RegionDef(name: "Hüfte") { w, h in
            var p = Path()
            p.move(to:    Self.p(78, 220, w: w, h: h))
            p.addLine(to: Self.p(122, 220, w: w, h: h))
            p.addCurve(to: Self.p(132, 262, w: w, h: h),
                       control1: Self.p(134, 234, w: w, h: h),
                       control2: Self.p(136, 252, w: w, h: h))
            p.addLine(to: Self.p(68, 262, w: w, h: h))
            p.addCurve(to: Self.p(78, 220, w: w, h: h),
                       control1: Self.p(64, 252, w: w, h: h),
                       control2: Self.p(66, 234, w: w, h: h))
            p.closeSubpath()
            return p
        },
        // Left upper arm
        RegionDef(name: "Oberarm links") { w, h in
            var p = Path()
            p.move(to:    Self.p(56, 118, w: w, h: h))
            p.addCurve(to: Self.p(40, 194, w: w, h: h),
                       control1: Self.p(40, 148, w: w, h: h),
                       control2: Self.p(36, 174, w: w, h: h))
            p.addCurve(to: Self.p(62, 194, w: w, h: h),
                       control1: Self.p(46, 202, w: w, h: h),
                       control2: Self.p(56, 202, w: w, h: h))
            p.addCurve(to: Self.p(68, 108, w: w, h: h),
                       control1: Self.p(66, 174, w: w, h: h),
                       control2: Self.p(68, 140, w: w, h: h))
            p.closeSubpath()
            return p
        },
        // Right upper arm
        RegionDef(name: "Oberarm rechts") { w, h in
            var p = Path()
            p.move(to:    Self.p(144, 118, w: w, h: h))
            p.addCurve(to: Self.p(160, 194, w: w, h: h),
                       control1: Self.p(160, 148, w: w, h: h),
                       control2: Self.p(164, 174, w: w, h: h))
            p.addCurve(to: Self.p(138, 194, w: w, h: h),
                       control1: Self.p(154, 202, w: w, h: h),
                       control2: Self.p(144, 202, w: w, h: h))
            p.addCurve(to: Self.p(132, 108, w: w, h: h),
                       control1: Self.p(134, 174, w: w, h: h),
                       control2: Self.p(132, 140, w: w, h: h))
            p.closeSubpath()
            return p
        },
        // Left forearm — SVG x=36–62, y=210–294
        capsuleRegion(name: "Unterarm links", cx: 49, cy: 252, rw: 12, rh: 40),
        // Right forearm
        capsuleRegion(name: "Unterarm rechts", cx: 151, cy: 252, rw: 12, rh: 40),
        // Hands — SVG ellipse cx=46/154, cy=308, rx=12, ry=18
        ellipseRegion(name: "Hand links", cx: 46, cy: 308, rx: 12, ry: 18),
        ellipseRegion(name: "Hand rechts", cx: 154, cy: 308, rx: 12, ry: 18),
        // Left thigh
        RegionDef(name: "Oberschenkel links") { w, h in
            var p = Path()
            p.move(to:    Self.p(68, 262, w: w, h: h))
            p.addCurve(to: Self.p(62, 358, w: w, h: h),
                       control1: Self.p(54, 298, w: w, h: h),
                       control2: Self.p(56, 336, w: w, h: h))
            p.addCurve(to: Self.p(88, 350, w: w, h: h),
                       control1: Self.p(70, 360, w: w, h: h),
                       control2: Self.p(80, 358, w: w, h: h))
            p.addCurve(to: Self.p(84, 262, w: w, h: h),
                       control1: Self.p(90, 328, w: w, h: h),
                       control2: Self.p(90, 294, w: w, h: h))
            p.closeSubpath()
            return p
        },
        // Right thigh
        RegionDef(name: "Oberschenkel rechts") { w, h in
            var p = Path()
            p.move(to:    Self.p(132, 262, w: w, h: h))
            p.addCurve(to: Self.p(138, 358, w: w, h: h),
                       control1: Self.p(146, 298, w: w, h: h),
                       control2: Self.p(144, 336, w: w, h: h))
            p.addCurve(to: Self.p(112, 350, w: w, h: h),
                       control1: Self.p(130, 360, w: w, h: h),
                       control2: Self.p(120, 358, w: w, h: h))
            p.addCurve(to: Self.p(116, 262, w: w, h: h),
                       control1: Self.p(110, 328, w: w, h: h),
                       control2: Self.p(110, 294, w: w, h: h))
            p.closeSubpath()
            return p
        },
        // Left calf
        RegionDef(name: "Unterschenkel links") { w, h in
            var p = Path()
            p.move(to:    Self.p(62, 358, w: w, h: h))
            p.addCurve(to: Self.p(64, 448, w: w, h: h),
                       control1: Self.p(54, 392, w: w, h: h),
                       control2: Self.p(58, 428, w: w, h: h))
            p.addCurve(to: Self.p(84, 440, w: w, h: h),
                       control1: Self.p(68, 452, w: w, h: h),
                       control2: Self.p(78, 448, w: w, h: h))
            p.addCurve(to: Self.p(88, 350, w: w, h: h),
                       control1: Self.p(88, 420, w: w, h: h),
                       control2: Self.p(90, 386, w: w, h: h))
            p.closeSubpath()
            return p
        },
        // Right calf
        RegionDef(name: "Unterschenkel rechts") { w, h in
            var p = Path()
            p.move(to:    Self.p(138, 358, w: w, h: h))
            p.addCurve(to: Self.p(136, 448, w: w, h: h),
                       control1: Self.p(146, 392, w: w, h: h),
                       control2: Self.p(142, 428, w: w, h: h))
            p.addCurve(to: Self.p(116, 440, w: w, h: h),
                       control1: Self.p(132, 452, w: w, h: h),
                       control2: Self.p(122, 448, w: w, h: h))
            p.addCurve(to: Self.p(112, 350, w: w, h: h),
                       control1: Self.p(112, 420, w: w, h: h),
                       control2: Self.p(110, 386, w: w, h: h))
            p.closeSubpath()
            return p
        },
        // Feet — SVG path x=56–92/108–144, y=448–474
        ellipseRegion(name: "Fuss links", cx: 74, cy: 461, rx: 18, ry: 13),
        ellipseRegion(name: "Fuss rechts", cx: 126, cy: 461, rx: 18, ry: 13),
    ]

    // MARK: Hinten (same structure, different region names for torso)

    static let hinten: [RegionDef] = [
        ellipseRegion(name: "Kopf", cx: 100, cy: 32, rx: 26, ry: 30),
        capsuleRegion(name: "Nacken", cx: 100, cy: 68, rw: 11, rh: 8),
        RegionDef(name: "Schulter links") { w, h in
            var p = Path()
            p.move(to:    Self.p(90, 76, w: w, h: h))
            p.addCurve(to: Self.p(50, 118, w: w, h: h),
                       control1: Self.p(68, 76, w: w, h: h),
                       control2: Self.p(50, 95, w: w, h: h))
            p.addCurve(to: Self.p(68, 108, w: w, h: h),
                       control1: Self.p(50, 118, w: w, h: h),
                       control2: Self.p(58, 114, w: w, h: h))
            p.addCurve(to: Self.p(90, 98, w: w, h: h),
                       control1: Self.p(78, 102, w: w, h: h),
                       control2: Self.p(84, 99, w: w, h: h))
            p.closeSubpath()
            return p
        },
        RegionDef(name: "Schulter rechts") { w, h in
            var p = Path()
            p.move(to:    Self.p(110, 76, w: w, h: h))
            p.addCurve(to: Self.p(150, 118, w: w, h: h),
                       control1: Self.p(132, 76, w: w, h: h),
                       control2: Self.p(150, 95, w: w, h: h))
            p.addCurve(to: Self.p(132, 108, w: w, h: h),
                       control1: Self.p(150, 118, w: w, h: h),
                       control2: Self.p(142, 114, w: w, h: h))
            p.addCurve(to: Self.p(110, 98, w: w, h: h),
                       control1: Self.p(122, 102, w: w, h: h),
                       control2: Self.p(116, 99, w: w, h: h))
            p.closeSubpath()
            return p
        },
        RegionDef(name: "Rücken oben") { w, h in
            var p = Path()
            p.move(to:    Self.p(68, 108, w: w, h: h))
            p.addCurve(to: Self.p(70, 196, w: w, h: h),
                       control1: Self.p(60, 140, w: w, h: h),
                       control2: Self.p(62, 172, w: w, h: h))
            p.addLine(to: Self.p(130, 196, w: w, h: h))
            p.addCurve(to: Self.p(132, 108, w: w, h: h),
                       control1: Self.p(138, 172, w: w, h: h),
                       control2: Self.p(140, 140, w: w, h: h))
            p.addCurve(to: Self.p(112, 98, w: w, h: h),
                       control1: Self.p(128, 106, w: w, h: h),
                       control2: Self.p(121, 101, w: w, h: h))
            p.addLine(to: Self.p(90, 98, w: w, h: h))
            p.addCurve(to: Self.p(68, 108, w: w, h: h),
                       control1: Self.p(79, 101, w: w, h: h),
                       control2: Self.p(72, 106, w: w, h: h))
            p.closeSubpath()
            return p
        },
        RegionDef(name: "Rücken unten") { w, h in
            var p = Path()
            p.move(to:    Self.p(70, 196, w: w, h: h))
            p.addLine(to: Self.p(130, 196, w: w, h: h))
            p.addLine(to: Self.p(126, 220, w: w, h: h))
            p.addLine(to: Self.p(74, 220, w: w, h: h))
            p.closeSubpath()
            return p
        },
        RegionDef(name: "Gesäss") { w, h in
            var p = Path()
            p.move(to:    Self.p(74, 220, w: w, h: h))
            p.addLine(to: Self.p(126, 220, w: w, h: h))
            p.addCurve(to: Self.p(136, 262, w: w, h: h),
                       control1: Self.p(136, 236, w: w, h: h),
                       control2: Self.p(138, 252, w: w, h: h))
            p.addLine(to: Self.p(64, 262, w: w, h: h))
            p.addCurve(to: Self.p(74, 220, w: w, h: h),
                       control1: Self.p(62, 252, w: w, h: h),
                       control2: Self.p(64, 236, w: w, h: h))
            p.closeSubpath()
            return p
        },
        RegionDef(name: "Oberarm links") { w, h in
            var p = Path()
            p.move(to:    Self.p(56, 118, w: w, h: h))
            p.addCurve(to: Self.p(40, 194, w: w, h: h),
                       control1: Self.p(40, 148, w: w, h: h),
                       control2: Self.p(36, 174, w: w, h: h))
            p.addCurve(to: Self.p(62, 194, w: w, h: h),
                       control1: Self.p(46, 202, w: w, h: h),
                       control2: Self.p(56, 202, w: w, h: h))
            p.addCurve(to: Self.p(68, 108, w: w, h: h),
                       control1: Self.p(66, 174, w: w, h: h),
                       control2: Self.p(68, 140, w: w, h: h))
            p.closeSubpath()
            return p
        },
        RegionDef(name: "Oberarm rechts") { w, h in
            var p = Path()
            p.move(to:    Self.p(144, 118, w: w, h: h))
            p.addCurve(to: Self.p(160, 194, w: w, h: h),
                       control1: Self.p(160, 148, w: w, h: h),
                       control2: Self.p(164, 174, w: w, h: h))
            p.addCurve(to: Self.p(138, 194, w: w, h: h),
                       control1: Self.p(154, 202, w: w, h: h),
                       control2: Self.p(144, 202, w: w, h: h))
            p.addCurve(to: Self.p(132, 108, w: w, h: h),
                       control1: Self.p(134, 174, w: w, h: h),
                       control2: Self.p(132, 140, w: w, h: h))
            p.closeSubpath()
            return p
        },
        capsuleRegion(name: "Unterarm links", cx: 49, cy: 252, rw: 12, rh: 40),
        capsuleRegion(name: "Unterarm rechts", cx: 151, cy: 252, rw: 12, rh: 40),
        ellipseRegion(name: "Hand links", cx: 46, cy: 308, rx: 12, ry: 18),
        ellipseRegion(name: "Hand rechts", cx: 154, cy: 308, rx: 12, ry: 18),
        RegionDef(name: "Oberschenkel links") { w, h in
            var p = Path()
            p.move(to:    Self.p(64, 262, w: w, h: h))
            p.addCurve(to: Self.p(58, 358, w: w, h: h),
                       control1: Self.p(50, 298, w: w, h: h),
                       control2: Self.p(52, 336, w: w, h: h))
            p.addCurve(to: Self.p(84, 350, w: w, h: h),
                       control1: Self.p(64, 362, w: w, h: h),
                       control2: Self.p(76, 360, w: w, h: h))
            p.addCurve(to: Self.p(80, 262, w: w, h: h),
                       control1: Self.p(88, 328, w: w, h: h),
                       control2: Self.p(86, 294, w: w, h: h))
            p.closeSubpath()
            return p
        },
        RegionDef(name: "Oberschenkel rechts") { w, h in
            var p = Path()
            p.move(to:    Self.p(136, 262, w: w, h: h))
            p.addCurve(to: Self.p(142, 358, w: w, h: h),
                       control1: Self.p(150, 298, w: w, h: h),
                       control2: Self.p(148, 336, w: w, h: h))
            p.addCurve(to: Self.p(116, 350, w: w, h: h),
                       control1: Self.p(136, 362, w: w, h: h),
                       control2: Self.p(124, 360, w: w, h: h))
            p.addCurve(to: Self.p(120, 262, w: w, h: h),
                       control1: Self.p(112, 328, w: w, h: h),
                       control2: Self.p(114, 294, w: w, h: h))
            p.closeSubpath()
            return p
        },
        RegionDef(name: "Unterschenkel links") { w, h in
            var p = Path()
            p.move(to:    Self.p(58, 358, w: w, h: h))
            p.addCurve(to: Self.p(60, 448, w: w, h: h),
                       control1: Self.p(50, 392, w: w, h: h),
                       control2: Self.p(54, 428, w: w, h: h))
            p.addCurve(to: Self.p(84, 440, w: w, h: h),
                       control1: Self.p(64, 452, w: w, h: h),
                       control2: Self.p(76, 448, w: w, h: h))
            p.addCurve(to: Self.p(84, 350, w: w, h: h),
                       control1: Self.p(86, 420, w: w, h: h),
                       control2: Self.p(88, 386, w: w, h: h))
            p.closeSubpath()
            return p
        },
        RegionDef(name: "Unterschenkel rechts") { w, h in
            var p = Path()
            p.move(to:    Self.p(142, 358, w: w, h: h))
            p.addCurve(to: Self.p(140, 448, w: w, h: h),
                       control1: Self.p(150, 392, w: w, h: h),
                       control2: Self.p(146, 428, w: w, h: h))
            p.addCurve(to: Self.p(116, 440, w: w, h: h),
                       control1: Self.p(136, 452, w: w, h: h),
                       control2: Self.p(124, 448, w: w, h: h))
            p.addCurve(to: Self.p(116, 350, w: w, h: h),
                       control1: Self.p(114, 420, w: w, h: h),
                       control2: Self.p(112, 386, w: w, h: h))
            p.closeSubpath()
            return p
        },
        ellipseRegion(name: "Fuss links", cx: 74, cy: 461, rx: 18, ry: 13),
        ellipseRegion(name: "Fuss rechts", cx: 126, cy: 461, rx: 18, ry: 13),
    ]
}
