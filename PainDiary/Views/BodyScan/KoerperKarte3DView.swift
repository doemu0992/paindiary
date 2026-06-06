import SwiftUI
import SceneKit

// MARK: - SwiftUI wrapper

struct KoerperKarte3DView: UIViewRepresentable {
    let ausgewaehlt: Set<String>
    let onTap: (String) -> Void
    let proportionen: BodyProportionen

    func makeUIView(context: Context) -> SCNView {
        let v = SCNView()
        v.scene = BodySceneBuilder.build(proportionen)
        v.backgroundColor = .clear
        v.autoenablesDefaultLighting = false
        v.allowsCameraControl = false
        v.antialiasingMode = .multisampling4X

        let pan = UIPanGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handlePan(_:)))
        v.addGestureRecognizer(pan)

        let tap = UITapGestureRecognizer(target: context.coordinator,
                                          action: #selector(Coordinator.handleTap(_:)))
        tap.require(toFail: pan)
        v.addGestureRecognizer(tap)

        context.coordinator.scnView = v
        return v
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        uiView.scene?.rootNode.enumerateChildNodes { node, _ in
            guard let name = node.name else { return }
            node.geometry?.materials.forEach { mat in
                if ausgewaehlt.contains(name) {
                    mat.diffuse.contents  = UIColor.systemRed.withAlphaComponent(0.78)
                    mat.emission.contents = UIColor.systemRed.withAlphaComponent(0.18)
                } else {
                    mat.diffuse.contents  = BodySceneBuilder.hautfarbe
                    mat.emission.contents = UIColor.black
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onTap: onTap) }

    // MARK: Coordinator

    class Coordinator: NSObject {
        let onTap: (String) -> Void
        weak var scnView: SCNView?

        init(onTap: @escaping (String) -> Void) { self.onTap = onTap }

        @objc func handlePan(_ g: UIPanGestureRecognizer) {
            guard let v = scnView,
                  let body = v.scene?.rootNode.childNode(withName: "body", recursively: false)
            else { return }
            body.eulerAngles.y += Float(g.translation(in: v).x) * 0.013
            g.setTranslation(.zero, in: v)
        }

        @objc func handleTap(_ g: UITapGestureRecognizer) {
            guard let v = scnView else { return }
            let hits = v.hitTest(g.location(in: v), options: [
                SCNHitTestOption.firstFoundOnly: true,
                SCNHitTestOption.backFaceCulling: false
            ])
            guard let hit = hits.first, let name = hit.node.name else { return }
            // Use local Z to distinguish front from back on torso segments
            let resolved = hit.localCoordinates.z < 0 ? (backMap[name] ?? name) : name
            onTap(resolved)
        }

        private let backMap: [String: String] = [
            "Hals":  "Nacken",
            "Brust": "Rücken oben",
            "Bauch": "Rücken unten",
            "Hüfte": "Gesäss",
        ]
    }
}

// MARK: - Scene builder

enum BodySceneBuilder {
    static let hautfarbe = UIColor(red: 0.91, green: 0.87, blue: 0.83, alpha: 1.0)

    static func build(_ p: BodyProportionen) -> SCNScene {
        let scene = SCNScene()
        addLights(to: scene)
        addCamera(to: scene)

        let body = SCNNode()
        body.name = "body"
        addParts(to: body, p: p)

        // Center vertically
        let (lo, hi) = body.boundingBox
        body.position.y = -(lo.y + (hi.y - lo.y) / 2)

        scene.rootNode.addChildNode(body)
        return scene
    }

    // MARK: Lights

    private static func addLights(to scene: SCNScene) {
        func light(_ type: SCNLight.LightType, intensity: CGFloat, euler: SCNVector3 = .init()) -> SCNNode {
            let n = SCNNode()
            n.light = SCNLight()
            n.light!.type = type
            n.light!.intensity = intensity
            n.eulerAngles = euler
            return n
        }
        scene.rootNode.addChildNode(light(.ambient,      intensity: 420))
        scene.rootNode.addChildNode(light(.directional,  intensity: 850,
                                          euler: SCNVector3(-0.5,  0.55, 0)))
        scene.rootNode.addChildNode(light(.directional,  intensity: 320,
                                          euler: SCNVector3( 0.3, -0.80, 0)))
    }

    // MARK: Camera

    private static func addCamera(to scene: SCNScene) {
        let cam = SCNNode()
        cam.camera = SCNCamera()
        cam.camera!.fieldOfView = 38
        cam.camera!.zNear = 0.05
        cam.camera!.zFar  = 20
        cam.position = SCNVector3(0, 0, 2.8)
        scene.rootNode.addChildNode(cam)
    }

    // MARK: Body parts

    private static func addParts(to body: SCNNode, p: BodyProportionen) {
        // Key Y levels (hips at y = 0)
        let huefteTop  = p.huefteHoehe
        let bauchTop   = huefteTop + p.bauchHoehe
        let brustTop   = bauchTop  + p.brustHoehe
        let kopfMitte  = brustTop  + p.halsLaenge + p.kopfRadius

        let armX   = p.schulterBreite / 2 + 0.04   // arm column X
        let beinX  = p.huefteBreite   * 0.28        // leg column X
        let dh     = p.torsoTiefe / 2               // torso depth half

        // ── Head ──────────────────────────────────────────────────────
        body.addChildNode(n("Kopf",
            SCNSphere(radius: CGFloat(p.kopfRadius)),
            SCNVector3(0, kopfMitte, 0)))

        // ── Neck/Nacken (one box, front = "Hals", back = "Nacken") ────
        body.addChildNode(n("Hals",
            SCNBox(width:  CGFloat(p.torsoBreite * 0.38),
                   height: CGFloat(p.halsLaenge),
                   length: CGFloat(p.torsoTiefe  * 0.55),
                   chamferRadius: 0.03),
            SCNVector3(0, brustTop + p.halsLaenge / 2, 0)))

        // ── Chest (Brust / Rücken oben) ───────────────────────────────
        body.addChildNode(n("Brust",
            tBox(p.torsoBreite, p.brustHoehe, p.torsoTiefe),
            SCNVector3(0, bauchTop + p.brustHoehe / 2, 0)))

        // ── Abdomen (Bauch / Rücken unten) ────────────────────────────
        body.addChildNode(n("Bauch",
            tBox(p.torsoBreite * 0.90, p.bauchHoehe, p.torsoTiefe * 0.95),
            SCNVector3(0, huefteTop + p.bauchHoehe / 2, 0)))

        // ── Hip (Hüfte / Gesäss) ──────────────────────────────────────
        body.addChildNode(n("Hüfte",
            tBox(p.huefteBreite, p.huefteHoehe, p.torsoTiefe * 0.90),
            SCNVector3(0, p.huefteHoehe / 2, 0)))

        // ── Shoulders ─────────────────────────────────────────────────
        let sGeo = SCNSphere(radius: 0.062)
        body.addChildNode(n("Schulter links",  sGeo, SCNVector3(-armX + 0.03, brustTop - 0.01, 0)))
        body.addChildNode(n("Schulter rechts", sGeo, SCNVector3( armX - 0.03, brustTop - 0.01, 0)))

        // ── Upper arms ────────────────────────────────────────────────
        let oaGeo = SCNCapsule(capRadius: 0.040, height: CGFloat(p.oberarmLaenge))
        let oaY   = brustTop - 0.02 - p.oberarmLaenge / 2
        body.addChildNode(n("Oberarm links",  oaGeo, SCNVector3(-armX, oaY, 0)))
        body.addChildNode(n("Oberarm rechts", oaGeo, SCNVector3( armX, oaY, 0)))

        // ── Forearms ──────────────────────────────────────────────────
        let faGeo = SCNCapsule(capRadius: 0.033, height: CGFloat(p.unterarmLaenge))
        let faY   = oaY - p.oberarmLaenge / 2 - p.unterarmLaenge / 2
        body.addChildNode(n("Unterarm links",  faGeo, SCNVector3(-armX - 0.02, faY, 0)))
        body.addChildNode(n("Unterarm rechts", faGeo, SCNVector3( armX + 0.02, faY, 0)))

        // ── Hands ─────────────────────────────────────────────────────
        let hGeo = SCNSphere(radius: 0.044)
        let hY   = faY - p.unterarmLaenge / 2 - 0.04
        body.addChildNode(n("Hand links",  hGeo, SCNVector3(-armX - 0.03, hY, 0)))
        body.addChildNode(n("Hand rechts", hGeo, SCNVector3( armX + 0.03, hY, 0)))

        // ── Upper legs ────────────────────────────────────────────────
        let ulGeo = SCNCapsule(capRadius: 0.063, height: CGFloat(p.oberschenkelLaenge))
        let ulY   = -(p.oberschenkelLaenge / 2 + 0.01)
        body.addChildNode(n("Oberschenkel links",  ulGeo, SCNVector3(-beinX, ulY, 0)))
        body.addChildNode(n("Oberschenkel rechts", ulGeo, SCNVector3( beinX, ulY, 0)))

        // ── Lower legs ────────────────────────────────────────────────
        let llGeo = SCNCapsule(capRadius: 0.047, height: CGFloat(p.unterschenkelLaenge))
        let llY   = -(p.oberschenkelLaenge + p.unterschenkelLaenge / 2 + 0.02)
        body.addChildNode(n("Unterschenkel links",  llGeo, SCNVector3(-beinX * 0.88, llY, 0)))
        body.addChildNode(n("Unterschenkel rechts", llGeo, SCNVector3( beinX * 0.88, llY, 0)))

        // ── Feet ──────────────────────────────────────────────────────
        let fGeo = SCNBox(width: 0.082, height: 0.055, length: 0.190, chamferRadius: 0.025)
        let fY   = -(p.oberschenkelLaenge + p.unterschenkelLaenge + 0.045)
        body.addChildNode(n("Fuss links",  fGeo, SCNVector3(-beinX * 0.88, fY, 0.04)))
        body.addChildNode(n("Fuss rechts", fGeo, SCNVector3( beinX * 0.88, fY, 0.04)))
    }

    // MARK: Geometry helpers

    private static func tBox(_ w: Float, _ h: Float, _ d: Float) -> SCNGeometry {
        SCNBox(width: CGFloat(w), height: CGFloat(h), length: CGFloat(d), chamferRadius: 0.040)
    }

    private static func n(_ name: String, _ geo: SCNGeometry, _ pos: SCNVector3) -> SCNNode {
        let mat = SCNMaterial()
        mat.diffuse.contents  = hautfarbe
        mat.emission.contents = UIColor.black
        mat.lightingModel     = .phong
        mat.specular.contents = UIColor(white: 0.18, alpha: 1)
        mat.shininess         = 22
        mat.isDoubleSided     = true
        geo.materials = [mat]

        let node = SCNNode(geometry: geo)
        node.name     = name
        node.position = pos
        return node
    }
}
