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

            KoerperKarteView(
                vorne: vorne,
                ausgewaehlt: ausgewaehlt,
                onTap: toggle
            )
            .frame(height: 400)
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

// MARK: - Body Map Canvas + Regions

private struct KoerperKarteView: View {
    let vorne: Bool
    let ausgewaehlt: Set<String>
    let onTap: (String) -> Void

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Canvas { ctx, size in
                    zeichneKoerper(ctx: ctx, size: size)
                }

                ForEach(vorne ? RegionDef.vorne : RegionDef.hinten) { region in
                    let fr = region.frame(w: w, h: h)
                    RoundedRectangle(cornerRadius: min(fr.width, fr.height) * 0.45)
                        .fill(
                            ausgewaehlt.contains(region.name)
                                ? Color.red.opacity(0.42)
                                : Color.white.opacity(0.001)
                        )
                        .frame(width: fr.width, height: fr.height)
                        .position(x: fr.midX, y: fr.midY)
                        .onTapGesture { onTap(region.name) }
                        .animation(.spring(response: 0.2), value: ausgewaehlt.contains(region.name))
                }
            }
        }
    }

    private func zeichneKoerper(ctx: GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        let c = ctx
        let fill = GraphicsContext.Shading.color(Color(.systemGray5))
        let stroke = GraphicsContext.Shading.color(Color.secondary.opacity(0.22))

        func form(_ rect: CGRect, corner: CGFloat = 12) {
            let p = Path(roundedRect: rect, cornerRadius: corner)
            c.fill(p, with: fill)
            c.stroke(p, with: stroke, lineWidth: 1.2)
        }
        func ellipse(_ rect: CGRect) {
            let p = Path(ellipseIn: rect)
            c.fill(p, with: fill)
            c.stroke(p, with: stroke, lineWidth: 1.2)
        }

        // Head
        ellipse(CGRect(x: w*0.375, y: h*0.008, width: w*0.25, height: h*0.108))
        // Neck
        form(CGRect(x: w*0.440, y: h*0.110, width: w*0.120, height: h*0.042), corner: 5)
        // Shoulders (left + right)
        ellipse(CGRect(x: w*0.140, y: h*0.144, width: w*0.190, height: h*0.074))
        ellipse(CGRect(x: w*0.670, y: h*0.144, width: w*0.190, height: h*0.074))
        // Torso
        form(CGRect(x: w*0.300, y: h*0.148, width: w*0.400, height: h*0.300), corner: 16)
        // Upper arms
        form(CGRect(x: w*0.112, y: h*0.210, width: w*0.115, height: h*0.190), corner: 14)
        form(CGRect(x: w*0.773, y: h*0.210, width: w*0.115, height: h*0.190), corner: 14)
        // Forearms
        form(CGRect(x: w*0.086, y: h*0.392, width: w*0.098, height: h*0.158), corner: 12)
        form(CGRect(x: w*0.816, y: h*0.392, width: w*0.098, height: h*0.158), corner: 12)
        // Hands
        ellipse(CGRect(x: w*0.080, y: h*0.543, width: w*0.108, height: h*0.068))
        ellipse(CGRect(x: w*0.812, y: h*0.543, width: w*0.108, height: h*0.068))
        // Hips
        form(CGRect(x: w*0.268, y: h*0.432, width: w*0.464, height: h*0.108), corner: 14)
        // Thighs
        form(CGRect(x: w*0.282, y: h*0.520, width: w*0.188, height: h*0.218), corner: 16)
        form(CGRect(x: w*0.530, y: h*0.520, width: w*0.188, height: h*0.218), corner: 16)
        // Calves
        form(CGRect(x: w*0.292, y: h*0.730, width: w*0.162, height: h*0.188), corner: 14)
        form(CGRect(x: w*0.546, y: h*0.730, width: w*0.162, height: h*0.188), corner: 14)
        // Feet
        form(CGRect(x: w*0.266, y: h*0.908, width: w*0.200, height: h*0.068), corner: 10)
        form(CGRect(x: w*0.534, y: h*0.908, width: w*0.200, height: h*0.068), corner: 10)
    }
}

// MARK: - Region Definitions

private struct RegionDef: Identifiable {
    let id = UUID()
    let name: String
    let cx: Double
    let cy: Double
    let rw: Double
    let rh: Double

    func frame(w geoW: CGFloat, h geoH: CGFloat) -> CGRect {
        CGRect(
            x: geoW * (cx - rw / 2),
            y: geoH * (cy - rh / 2),
            width: geoW * rw,
            height: geoH * rh
        )
    }

    static let vorne: [RegionDef] = [
        RegionDef(name: "Kopf",                  cx: 0.500, cy: 0.062, rw: 0.260, rh: 0.108),
        RegionDef(name: "Nacken",                cx: 0.500, cy: 0.132, rw: 0.130, rh: 0.048),
        RegionDef(name: "Brust",                 cx: 0.500, cy: 0.220, rw: 0.385, rh: 0.100),
        RegionDef(name: "Bauch",                 cx: 0.500, cy: 0.340, rw: 0.385, rh: 0.100),
        RegionDef(name: "Schulter links",        cx: 0.232, cy: 0.182, rw: 0.170, rh: 0.074),
        RegionDef(name: "Schulter rechts",       cx: 0.768, cy: 0.182, rw: 0.170, rh: 0.074),
        RegionDef(name: "Oberarm links",         cx: 0.170, cy: 0.305, rw: 0.118, rh: 0.190),
        RegionDef(name: "Oberarm rechts",        cx: 0.830, cy: 0.305, rw: 0.118, rh: 0.190),
        RegionDef(name: "Unterarm links",        cx: 0.135, cy: 0.471, rw: 0.102, rh: 0.158),
        RegionDef(name: "Unterarm rechts",       cx: 0.865, cy: 0.471, rw: 0.102, rh: 0.158),
        RegionDef(name: "Hand links",            cx: 0.134, cy: 0.577, rw: 0.112, rh: 0.068),
        RegionDef(name: "Hand rechts",           cx: 0.866, cy: 0.577, rw: 0.112, rh: 0.068),
        RegionDef(name: "Hüfte",                 cx: 0.500, cy: 0.486, rw: 0.450, rh: 0.108),
        RegionDef(name: "Oberschenkel links",    cx: 0.376, cy: 0.630, rw: 0.192, rh: 0.218),
        RegionDef(name: "Oberschenkel rechts",   cx: 0.624, cy: 0.630, rw: 0.192, rh: 0.218),
        RegionDef(name: "Unterschenkel links",   cx: 0.373, cy: 0.824, rw: 0.168, rh: 0.188),
        RegionDef(name: "Unterschenkel rechts",  cx: 0.627, cy: 0.824, rw: 0.168, rh: 0.188),
        RegionDef(name: "Fuss links",            cx: 0.366, cy: 0.942, rw: 0.205, rh: 0.068),
        RegionDef(name: "Fuss rechts",           cx: 0.634, cy: 0.942, rw: 0.205, rh: 0.068),
    ]

    static let hinten: [RegionDef] = [
        RegionDef(name: "Kopf",                  cx: 0.500, cy: 0.062, rw: 0.260, rh: 0.108),
        RegionDef(name: "Nacken",                cx: 0.500, cy: 0.132, rw: 0.130, rh: 0.048),
        RegionDef(name: "Rücken oben",           cx: 0.500, cy: 0.220, rw: 0.385, rh: 0.100),
        RegionDef(name: "Rücken unten",          cx: 0.500, cy: 0.340, rw: 0.385, rh: 0.100),
        RegionDef(name: "Schulter links",        cx: 0.232, cy: 0.182, rw: 0.170, rh: 0.074),
        RegionDef(name: "Schulter rechts",       cx: 0.768, cy: 0.182, rw: 0.170, rh: 0.074),
        RegionDef(name: "Oberarm links",         cx: 0.170, cy: 0.305, rw: 0.118, rh: 0.190),
        RegionDef(name: "Oberarm rechts",        cx: 0.830, cy: 0.305, rw: 0.118, rh: 0.190),
        RegionDef(name: "Unterarm links",        cx: 0.135, cy: 0.471, rw: 0.102, rh: 0.158),
        RegionDef(name: "Unterarm rechts",       cx: 0.865, cy: 0.471, rw: 0.102, rh: 0.158),
        RegionDef(name: "Hand links",            cx: 0.134, cy: 0.577, rw: 0.112, rh: 0.068),
        RegionDef(name: "Hand rechts",           cx: 0.866, cy: 0.577, rw: 0.112, rh: 0.068),
        RegionDef(name: "Gesäss",                cx: 0.500, cy: 0.486, rw: 0.450, rh: 0.108),
        RegionDef(name: "Oberschenkel links",    cx: 0.376, cy: 0.630, rw: 0.192, rh: 0.218),
        RegionDef(name: "Oberschenkel rechts",   cx: 0.624, cy: 0.630, rw: 0.192, rh: 0.218),
        RegionDef(name: "Unterschenkel links",   cx: 0.373, cy: 0.824, rw: 0.168, rh: 0.188),
        RegionDef(name: "Unterschenkel rechts",  cx: 0.627, cy: 0.824, rw: 0.168, rh: 0.188),
        RegionDef(name: "Fuss links",            cx: 0.366, cy: 0.942, rw: 0.205, rh: 0.068),
        RegionDef(name: "Fuss rechts",           cx: 0.634, cy: 0.942, rw: 0.205, rh: 0.068),
    ]
}
