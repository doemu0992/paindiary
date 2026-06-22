import SwiftUI

struct GelenkHandView: View {
    let statusDict: [String: GelenkZustand]
    let onTap: (String, String) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            SingleHandView(
                prefix: "L",
                label: "Linke Hand",
                fingerOrder: [5, 4, 3, 2, 1],
                statusDict: statusDict,
                onTap: onTap
            )
            Divider()
            SingleHandView(
                prefix: "R",
                label: "Rechte Hand",
                fingerOrder: [1, 2, 3, 4, 5],
                statusDict: statusDict,
                onTap: onTap
            )
        }
    }
}

private struct SingleHandView: View {
    let prefix: String
    let label: String
    let fingerOrder: [Int]
    let statusDict: [String: GelenkZustand]
    let onTap: (String, String) -> Void

    private let dotSize: CGFloat = 28
    private let fingerKurzNamen = ["Dau.", "Zeig.", "Mitt.", "Ring.", "Kl."]
    private let fingerLangNamen = ["Daumen", "Zeigefinger", "Mittelfinger", "Ringfinger", "Kleinfinger"]

    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let colW = w / CGFloat(fingerOrder.count)

                ZStack {
                    Canvas { ctx, size in
                        drawHandShape(ctx: ctx, size: size)
                    }

                    // Column labels
                    ForEach(fingerOrder.indices, id: \.self) { col in
                        Text(fingerKurzNamen[fingerOrder[col] - 1])
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: colW)
                            .position(x: colW * (CGFloat(col) + 0.5), y: h * 0.05)
                    }

                    // PIP row
                    ForEach(fingerOrder.indices, id: \.self) { col in
                        let finger = fingerOrder[col]
                        let id = "\(prefix)_PIP\(finger)"
                        jointButton(id: id, name: fingerLangNamen[finger - 1] + " Mittelgelenk")
                            .position(x: colW * (CGFloat(col) + 0.5), y: h * 0.33)
                    }

                    // MCP row
                    ForEach(fingerOrder.indices, id: \.self) { col in
                        let finger = fingerOrder[col]
                        let id = "\(prefix)_MCP\(finger)"
                        jointButton(id: id, name: fingerLangNamen[finger - 1] + " Grundgelenk")
                            .position(x: colW * (CGFloat(col) + 0.5), y: h * 0.62)
                    }
                }
            }
            .frame(height: 170)
        }
        .frame(maxWidth: .infinity)
    }

    private func jointButton(id: String, name: String) -> some View {
        let zustand = statusDict[id] ?? .keiner
        return Button { onTap(id, name) } label: {
            ZStack {
                Circle()
                    .fill(zustand == .keiner ? Color(.systemGray4) : zustand.farbe)
                    .frame(width: dotSize, height: dotSize)
                    .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                    .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)
                if zustand != .keiner {
                    Text(zustand.kuerzel == "SG" ? "S+G" : zustand.kuerzel)
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
    }

    private func drawHandShape(ctx: GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        let n = CGFloat(fingerOrder.count)
        let colW = w / n
        let fingerW = colW * 0.65
        let palmColor = Color(.systemGray5)
        let palmTop = h * 0.52

        for col in 0..<Int(n) {
            let cx = colW * (CGFloat(col) + 0.5)
            let rect = CGRect(x: cx - fingerW / 2, y: h * 0.10,
                              width: fingerW, height: palmTop - h * 0.10 + 8)
            ctx.fill(Path(roundedRect: rect, cornerRadius: fingerW / 2), with: .color(palmColor))
        }

        let palmRect = CGRect(x: colW * 0.18, y: palmTop,
                              width: w - colW * 0.36, height: h * 0.44)
        ctx.fill(Path(roundedRect: palmRect, cornerRadius: 10), with: .color(palmColor))
    }
}
