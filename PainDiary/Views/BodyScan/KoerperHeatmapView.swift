import SwiftUI
import SceneKit

/// Read-only body model that colours each region by relative frequency (0.0–1.0).
struct KoerperHeatmapView: UIViewRepresentable {
    /// Maps body-part node names to a relative intensity in 0.0 ... 1.0
    let intensitaeten: [String: Double]
    var tintColor: UIColor = .systemRed
    let proportionen: BodyProportionen

    func makeUIView(context: Context) -> SCNView {
        let v = SCNView()
        v.scene = BodySceneBuilder.build(proportionen)
        v.backgroundColor = .clear
        v.autoenablesDefaultLighting = false
        v.allowsCameraControl = false
        v.antialiasingMode = .multisampling4X

        let pan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        v.addGestureRecognizer(pan)
        context.coordinator.scnView = v
        return v
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        uiView.scene?.rootNode.enumerateChildNodes { node, _ in
            guard let name = node.name else { return }
            let direct = intensitaeten[name] ?? 0
            let viaSubRegion = SubRegionen.map[name]?
                .compactMap { intensitaeten[$0] }.max() ?? 0
            let intensity = max(direct, viaSubRegion)

            node.geometry?.materials.forEach { mat in
                if intensity > 0 {
                    mat.diffuse.contents  = tintColor.withAlphaComponent(0.18 + intensity * 0.62)
                    mat.emission.contents = tintColor.withAlphaComponent(intensity * 0.28)
                } else {
                    mat.diffuse.contents  = BodySceneBuilder.hautfarbe
                    mat.emission.contents = UIColor.black
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject {
        weak var scnView: SCNView?

        @objc func handlePan(_ g: UIPanGestureRecognizer) {
            guard let v = scnView else { return }
            if let body = v.scene?.rootNode.childNode(withName: "body", recursively: false) {
                let t = g.translation(in: v)
                body.eulerAngles.y += Float(t.x) * 0.013
                g.setTranslation(.zero, in: v)
            }
        }
    }
}
