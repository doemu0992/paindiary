import SwiftUI
import SceneKit

struct KoerperKarte3DView: UIViewRepresentable {
    var ausgewaehlt: Set<String>
    var onTap: (String) -> Void
    var proportionen: BodyProportionen
    var tintColor: UIColor = .systemRed

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = KoerperSzene.bauen(proportionen: proportionen)
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = true
        scnView.backgroundColor = .clear
        scnView.antialiasingMode = .multisampling4X

        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleTap(_:)))
        scnView.addGestureRecognizer(tap)
        context.coordinator.scnView = scnView
        context.coordinator.onTap = onTap
        return scnView
    }

    func updateUIView(_ scnView: SCNView, context: Context) {
        context.coordinator.onTap = onTap
        KoerperSzene.aktualisiereAuswahl(in: scnView.scene!, ausgewaehlt: ausgewaehlt, tintColor: tintColor)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject {
        weak var scnView: SCNView?
        var onTap: ((String) -> Void)?

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let scnView = scnView else { return }
            let loc = gesture.location(in: scnView)
            let hits = scnView.hitTest(loc, options: [
                .searchMode: SCNHitTestSearchMode.closest.rawValue
            ])
            if let hit = hits.first, let name = hit.node.name, !name.isEmpty {
                onTap?(name)
            }
        }
    }
}

// MARK: - Scene builder

enum KoerperSzene {

    static func bauen(proportionen: BodyProportionen) -> SCNScene {
        let scene = SCNScene()
        let root = scene.rootNode

        // Camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 0.9, 2.8)
        cameraNode.look(at: SCNVector3(0, 0.9, 0))
        root.addChildNode(cameraNode)

        // Lights
        let light = SCNNode()
        light.light = SCNLight()
        light.light!.type = .omni
        light.position = SCNVector3(1, 2, 3)
        root.addChildNode(light)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light!.type = .ambient
        ambient.light!.color = UIColor(white: 0.4, alpha: 1)
        root.addChildNode(ambient)

        let directional = SCNNode()
        directional.light = SCNLight()
        directional.light!.type = .directional
        directional.light!.intensity = 800
        directional.eulerAngles = SCNVector3(-0.5, 0.5, 0)
        root.addChildNode(directional)

        let s = proportionen.schulterBreite
        let b = proportionen.beckenBreite
        let h = proportionen.koerperGroesse

        let scale = CGFloat(h / 1.75)

        // Head
        addPart(to: root, name: "Kopf",
                geo: SCNSphere(radius: 0.12 * scale),
                pos: SCNVector3(0, 1.72 * scale, 0))

        // Neck
        addPart(to: root, name: "Hals",
                geo: SCNCapsule(capRadius: 0.04 * scale, height: 0.12 * scale),
                pos: SCNVector3(0, 1.55 * scale, 0))

        // Chest (front)
        addPart(to: root, name: "Brust",
                geo: SCNCapsule(capRadius: CGFloat(s) * 0.45 * scale, height: 0.26 * scale),
                pos: SCNVector3(0, 1.35 * scale, 0.02 * scale),
                euler: SCNVector3(Float.pi / 2, 0, 0))

        // Back upper
        addPart(to: root, name: "Rücken oben",
                geo: SCNCapsule(capRadius: CGFloat(s) * 0.42 * scale, height: 0.24 * scale),
                pos: SCNVector3(0, 1.35 * scale, -0.02 * scale),
                euler: SCNVector3(Float.pi / 2, 0, 0))

        // Abdomen (front)
        addPart(to: root, name: "Bauch",
                geo: SCNCapsule(capRadius: CGFloat(b) * 0.48 * scale, height: 0.22 * scale),
                pos: SCNVector3(0, 1.10 * scale, 0.02 * scale),
                euler: SCNVector3(Float.pi / 2, 0, 0))

        // Back lower
        addPart(to: root, name: "Rücken unten",
                geo: SCNCapsule(capRadius: CGFloat(b) * 0.45 * scale, height: 0.20 * scale),
                pos: SCNVector3(0, 1.10 * scale, -0.02 * scale),
                euler: SCNVector3(Float.pi / 2, 0, 0))

        // Hips (front)
        addPart(to: root, name: "Hüfte",
                geo: SCNCapsule(capRadius: CGFloat(b) * 0.50 * scale, height: 0.18 * scale),
                pos: SCNVector3(0, 0.88 * scale, 0.02 * scale),
                euler: SCNVector3(Float.pi / 2, 0, 0))

        // Buttocks
        addPart(to: root, name: "Gesäss",
                geo: SCNCapsule(capRadius: CGFloat(b) * 0.48 * scale, height: 0.18 * scale),
                pos: SCNVector3(0, 0.88 * scale, -0.02 * scale),
                euler: SCNVector3(Float.pi / 2, 0, 0))

        // Shoulders
        let sw = CGFloat(s) * 0.55 * scale
        addPart(to: root, name: "Schulter links",
                geo: SCNSphere(radius: 0.085 * scale),
                pos: SCNVector3(-sw, 1.43 * scale, 0))
        addPart(to: root, name: "Schulter rechts",
                geo: SCNSphere(radius: 0.085 * scale),
                pos: SCNVector3(sw, 1.43 * scale, 0))

        // Upper arms
        addPart(to: root, name: "Oberarm links",
                geo: SCNCapsule(capRadius: 0.055 * scale, height: 0.25 * scale),
                pos: SCNVector3(-sw - 0.01 * scale, 1.23 * scale, 0))
        addPart(to: root, name: "Oberarm rechts",
                geo: SCNCapsule(capRadius: 0.055 * scale, height: 0.25 * scale),
                pos: SCNVector3(sw + 0.01 * scale, 1.23 * scale, 0))

        // Forearms
        let fax = sw + 0.015 * scale
        addPart(to: root, name: "Unterarm links",
                geo: SCNCapsule(capRadius: 0.045 * scale, height: 0.22 * scale),
                pos: SCNVector3(-fax, 0.98 * scale, 0))
        addPart(to: root, name: "Unterarm rechts",
                geo: SCNCapsule(capRadius: 0.045 * scale, height: 0.22 * scale),
                pos: SCNVector3(fax, 0.98 * scale, 0))

        // Hands
        let hx = sw + 0.02 * scale
        addPart(to: root, name: "Hand links",
                geo: SCNBox(width: 0.09 * scale, height: 0.11 * scale, length: 0.04 * scale, chamferRadius: 0.01 * scale),
                pos: SCNVector3(-hx, 0.81 * scale, 0))
        addPart(to: root, name: "Hand rechts",
                geo: SCNBox(width: 0.09 * scale, height: 0.11 * scale, length: 0.04 * scale, chamferRadius: 0.01 * scale),
                pos: SCNVector3(hx, 0.81 * scale, 0))

        // Thighs
        let tx = CGFloat(b) * 0.28 * scale
        addPart(to: root, name: "Oberschenkel links",
                geo: SCNCapsule(capRadius: 0.085 * scale, height: 0.32 * scale),
                pos: SCNVector3(-tx, 0.58 * scale, 0))
        addPart(to: root, name: "Oberschenkel rechts",
                geo: SCNCapsule(capRadius: 0.085 * scale, height: 0.32 * scale),
                pos: SCNVector3(tx, 0.58 * scale, 0))

        // Lower legs
        addPart(to: root, name: "Unterschenkel links",
                geo: SCNCapsule(capRadius: 0.065 * scale, height: 0.30 * scale),
                pos: SCNVector3(-tx, 0.23 * scale, 0))
        addPart(to: root, name: "Unterschenkel rechts",
                geo: SCNCapsule(capRadius: 0.065 * scale, height: 0.30 * scale),
                pos: SCNVector3(tx, 0.23 * scale, 0))

        // Feet
        addPart(to: root, name: "Fuss links",
                geo: SCNBox(width: 0.10 * scale, height: 0.06 * scale, length: 0.22 * scale, chamferRadius: 0.02 * scale),
                pos: SCNVector3(-tx, 0.03 * scale, 0.04 * scale))
        addPart(to: root, name: "Fuss rechts",
                geo: SCNBox(width: 0.10 * scale, height: 0.06 * scale, length: 0.22 * scale, chamferRadius: 0.02 * scale),
                pos: SCNVector3(tx, 0.03 * scale, 0.04 * scale))

        return scene
    }

    private static func addPart(to root: SCNNode, name: String, geo: SCNGeometry,
                                 pos: SCNVector3, euler: SCNVector3 = SCNVector3(0, 0, 0)) {
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor.systemGray4
        mat.specular.contents = UIColor.white
        mat.lightingModel = .phong
        mat.isDoubleSided = true
        geo.materials = [mat]

        let node = SCNNode(geometry: geo)
        node.name = name
        node.position = pos
        node.eulerAngles = euler
        root.addChildNode(node)
    }

    static func aktualisiereAuswahl(in scene: SCNScene, ausgewaehlt: Set<String>, tintColor: UIColor) {
        scene.rootNode.enumerateChildNodes { node, _ in
            guard let name = node.name, !name.isEmpty else { return }
            let selected = ausgewaehlt.contains(name)
            node.geometry?.firstMaterial?.diffuse.contents = selected
                ? tintColor.withAlphaComponent(0.8)
                : UIColor.systemGray4
            node.geometry?.firstMaterial?.emission.contents = selected
                ? tintColor.withAlphaComponent(0.3)
                : UIColor.black
        }
    }
}

// MARK: - SCNVector3 helpers

private extension SCNVector3 {
    init(_ x: CGFloat, _ y: CGFloat, _ z: CGFloat) {
        self.init(Float(x), Float(y), Float(z))
    }
}
