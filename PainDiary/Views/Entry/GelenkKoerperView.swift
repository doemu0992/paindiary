import SwiftUI
import SceneKit

struct GelenkKoerperView: UIViewRepresentable {
    let statusDict: [String: GelenkZustand]
    let onTap: (String, String) -> Void

    // Scene node name → gelenkId
    static let nodeZuGelenkId: [String: String] = [
        "Schulter links":  "L_S",
        "Schulter rechts": "R_S",
        "Ellbogen links":  "L_E",
        "Ellbogen rechts": "R_E",
        "Hand links":      "L_HG",
        "Hand rechts":     "R_HG",
        "Knie links":      "L_K",
        "Knie rechts":     "R_K",
        "Knöchel links":   "L_OSG",
        "Knöchel rechts":  "R_OSG",
        "L_HUE":           "L_HUE",
        "R_HUE":           "R_HUE",
        "HWS":             "HWS",
        "BWS":             "BWS",
        "LWS":             "LWS",
        "L_KFG":           "L_KFG",
        "R_KFG":           "R_KFG",
    ]

    static let gelenkIdZuName: [String: String] = [
        "L_S":   "Schulter links",
        "R_S":   "Schulter rechts",
        "L_E":   "Ellbogen links",
        "R_E":   "Ellbogen rechts",
        "L_HG":  "Handgelenk links",
        "R_HG":  "Handgelenk rechts",
        "L_K":   "Knie links",
        "R_K":   "Knie rechts",
        "L_OSG": "Sprunggelenk links",
        "R_OSG": "Sprunggelenk rechts",
        "L_HUE": "Hüfte links",
        "R_HUE": "Hüfte rechts",
        "HWS":   "Halswirbelsäule",
        "BWS":   "Brustwirbelsäule",
        "LWS":   "Lendenwirbelsäule",
        "L_KFG": "Kiefergelenk links",
        "R_KFG": "Kiefergelenk rechts",
    ]

    func makeUIView(context: Context) -> SCNView {
        let v = SCNView()
        v.scene = GelenkKoerperView.buildScene()
        v.backgroundColor = .clear
        v.autoenablesDefaultLighting = false
        v.allowsCameraControl = false
        v.antialiasingMode = .multisampling4X

        let pan = UIPanGestureRecognizer(target: context.coordinator,
                                          action: #selector(Coordinator.handlePan(_:)))
        v.addGestureRecognizer(pan)

        let pinch = UIPinchGestureRecognizer(target: context.coordinator,
                                               action: #selector(Coordinator.handlePinch(_:)))
        v.addGestureRecognizer(pinch)

        let doubleTap = UITapGestureRecognizer(target: context.coordinator,
                                                action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        v.addGestureRecognizer(doubleTap)

        let tap = UITapGestureRecognizer(target: context.coordinator,
                                          action: #selector(Coordinator.handleTap(_:)))
        tap.require(toFail: pan)
        tap.require(toFail: doubleTap)
        v.addGestureRecognizer(tap)

        context.coordinator.scnView = v
        return v
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        let hautfarbe = UIColor(red: 0.91, green: 0.87, blue: 0.83, alpha: 1.0)
        let dimmed    = UIColor(red: 0.82, green: 0.79, blue: 0.76, alpha: 1.0)

        uiView.scene?.rootNode.enumerateChildNodes { node, _ in
            guard let name = node.name, node.geometry != nil else { return }

            if let gelenkId = GelenkKoerperView.nodeZuGelenkId[name] {
                let zustand = statusDict[gelenkId] ?? .keiner
                let color: UIColor
                switch zustand {
                case .keiner:      color = UIColor(white: 0.72, alpha: 1)
                case .schmerzhaft: color = .systemRed
                case .geschwollen: color = .systemBlue
                case .beides:      color = .systemPurple
                }
                let glow: UIColor = zustand == .keiner ? .black : color.withAlphaComponent(0.35)
                node.geometry?.materials.forEach {
                    $0.diffuse.contents  = color
                    $0.emission.contents = glow
                }
            } else {
                node.geometry?.materials.forEach {
                    $0.diffuse.contents  = name.contains("Ohr") || name.contains("Oberschenkel")
                        || name.contains("Unterarm") || name.contains("Unterschenkel")
                        || name.contains("Fuss") ? dimmed : hautfarbe
                    $0.emission.contents = UIColor.black
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onTap: onTap) }

    // MARK: - Scene construction

    static func buildScene() -> SCNScene {
        let p = BodyProportionen.standard
        let scene = BodySceneBuilder.build(p)
        guard let body = scene.rootNode.childNode(withName: "body", recursively: false) else {
            return scene
        }

        let huefteTop = p.huefteHoehe
        let bauchTop  = huefteTop + p.bauchHoehe
        let brustTop  = bauchTop  + p.brustHoehe
        let kopfMitte = brustTop  + p.halsLaenge + p.kopfRadius
        let beinX     = p.huefteBreite * 0.28

        func addJointMarker(_ name: String, _ pos: SCNVector3, radius: Float = 0.032) {
            let geo = SCNSphere(radius: CGFloat(radius))
            let mat = SCNMaterial()
            mat.diffuse.contents  = UIColor(white: 0.72, alpha: 1)
            mat.emission.contents = UIColor.black
            mat.lightingModel     = .phong
            mat.specular.contents = UIColor(white: 0.28, alpha: 1)
            mat.shininess         = 30
            mat.isDoubleSided     = true
            geo.materials = [mat]
            let node = SCNNode(geometry: geo)
            node.name     = name
            node.position = pos
            body.addChildNode(node)
        }

        // Hip joints (lateral sides of hip block, front-facing)
        addJointMarker("L_HUE", SCNVector3(-p.huefteBreite * 0.44, p.huefteHoehe * 0.45, 0.04))
        addJointMarker("R_HUE", SCNVector3( p.huefteBreite * 0.44, p.huefteHoehe * 0.45, 0.04))

        // Spine (posterior z-offset so they appear on the back when rotated)
        addJointMarker("HWS", SCNVector3(0, brustTop + 0.018, -0.075))
        addJointMarker("BWS", SCNVector3(0, bauchTop + p.brustHoehe * 0.45, -0.090))
        addJointMarker("LWS", SCNVector3(0, huefteTop + p.bauchHoehe * 0.30, -0.082))

        // Jaw joints (front of lower head)
        let jawY: Float = kopfMitte - p.kopfRadius * 0.38
        let jawX: Float = p.kopfRadius * 0.72
        let jawZ: Float = p.kopfRadius * 0.72
        addJointMarker("L_KFG", SCNVector3(-jawX, jawY, jawZ), radius: 0.022)
        addJointMarker("R_KFG", SCNVector3( jawX, jawY, jawZ), radius: 0.022)

        return scene
    }

    // MARK: - Coordinator

    class Coordinator: NSObject {
        let onTap: (String, String) -> Void
        weak var scnView: SCNView?

        init(onTap: @escaping (String, String) -> Void) { self.onTap = onTap }

        @objc func handlePan(_ g: UIPanGestureRecognizer) {
            guard let v = scnView else { return }
            let t = g.translation(in: v)
            if let body = v.scene?.rootNode.childNode(withName: "body", recursively: false) {
                body.eulerAngles.y += Float(t.x) * 0.013
            }
            if let camNode = v.scene?.rootNode.childNodes.first(where: { $0.camera != nil }) {
                let newY = camNode.position.y + Float(t.y) * 0.004
                camNode.position.y = max(-1.0, min(1.0, newY))
            }
            g.setTranslation(.zero, in: v)
        }

        @objc func handlePinch(_ g: UIPinchGestureRecognizer) {
            guard let cam = scnView?.scene?.rootNode
                    .childNodes.first(where: { $0.camera != nil })?.camera else { return }
            let newFOV = cam.fieldOfView / CGFloat(g.scale)
            cam.fieldOfView = max(12, min(55, newFOV))
            g.scale = 1
        }

        @objc func handleDoubleTap(_ g: UITapGestureRecognizer) {
            guard let camNode = scnView?.scene?.rootNode
                    .childNodes.first(where: { $0.camera != nil }) else { return }
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.35
            camNode.camera?.fieldOfView = 44
            camNode.position.y = 0
            if let body = scnView?.scene?.rootNode.childNode(withName: "body", recursively: false) {
                body.eulerAngles.y = 0
            }
            SCNTransaction.commit()
        }

        @objc func handleTap(_ g: UITapGestureRecognizer) {
            guard let v = scnView else { return }
            let hits = v.hitTest(g.location(in: v), options: [
                SCNHitTestOption.firstFoundOnly: false,
                SCNHitTestOption.backFaceCulling: false,
            ])
            for hit in hits {
                guard let name = hit.node.name,
                      let gelenkId = GelenkKoerperView.nodeZuGelenkId[name] else { continue }
                let displayName = GelenkKoerperView.gelenkIdZuName[gelenkId] ?? name
#if os(iOS)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
                onTap(gelenkId, displayName)
                return
            }
        }
    }
}
