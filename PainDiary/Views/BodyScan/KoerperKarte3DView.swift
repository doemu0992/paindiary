import SwiftUI
import SceneKit

// MARK: - SwiftUI wrapper

struct KoerperKarte3DView: UIViewRepresentable {
    let ausgewaehlt: Set<String>
    let onTap: (String) -> Void
    let proportionen: BodyProportionen
    var tintColor: UIColor = .systemRed

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

        let pinch = UIPinchGestureRecognizer(target: context.coordinator,
                                              action: #selector(Coordinator.handlePinch(_:)))
        v.addGestureRecognizer(pinch)

        let tap = UITapGestureRecognizer(target: context.coordinator,
                                          action: #selector(Coordinator.handleTap(_:)))
        tap.require(toFail: pan)
        v.addGestureRecognizer(tap)

        let doubleTap = UITapGestureRecognizer(target: context.coordinator,
                                                action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        tap.require(toFail: doubleTap)
        v.addGestureRecognizer(doubleTap)

        context.coordinator.scnView = v
        return v
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        uiView.scene?.rootNode.enumerateChildNodes { node, _ in
            guard let name = node.name else { return }
            let isSelected = ausgewaehlt.contains(name)
                || (SubRegionen.map[name]?.contains { ausgewaehlt.contains($0) } ?? false)
                || (SubRegionen.elternIndex[name]?.contains { ausgewaehlt.contains($0) } ?? false)
            node.geometry?.materials.forEach { mat in
                if isSelected {
                    BodySceneBuilder.stileAktiv(mat, tint: tintColor, staerke: 1)
                } else {
                    BodySceneBuilder.stileNormal(mat)
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
            guard let v = scnView else { return }
            let t = g.translation(in: v)

            // Horizontal → rotate body around Y-axis
            if let body = v.scene?.rootNode.childNode(withName: "body", recursively: false) {
                body.eulerAngles.y += Float(t.x) * 0.013
            }

            // Vertical → pan camera up/down so zoomed-in users can scroll to feet/head
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
            SCNTransaction.commit()
        }

        @objc func handleTap(_ g: UITapGestureRecognizer) {
            guard let v = scnView else { return }
            let hits = v.hitTest(g.location(in: v), options: [
                SCNHitTestOption.firstFoundOnly: false,
                SCNHitTestOption.backFaceCulling: false,
                SCNHitTestOption.categoryBitMask: BodySceneBuilder.koerperMaske
            ])
            guard let name = hits.compactMap({ $0.node.name }).first else { return }
            // Beim USDZ-Körper sind Vorder- und Rückseite eigene Regionen → keine Umdeutung nötig
            let hatUSDZ = v.scene?.rootNode.childNode(withName: "usdzKoerper", recursively: true) != nil
            let resolved = (hatUSDZ || isFrontView) ? name : (backMap[name] ?? name)
            onTap(resolved)
        }

        private var isFrontView: Bool {
            guard let body = scnView?.scene?.rootNode
                    .childNode(withName: "body", recursively: false) else { return true }
            var a = body.eulerAngles.y.truncatingRemainder(dividingBy: 2 * .pi)
            if a >  .pi { a -= 2 * .pi }
            if a < -.pi { a += 2 * .pi }
            return abs(a) < .pi / 2
        }

        private let backMap: [String: String] = [
            "Hals":  "Hals",
            "Brust": "Rücken oben",
            "Bauch": "Rücken unten",
            "Hüfte": "Gesäss",
        ]
    }
}

// MARK: - Scene builder

enum BodySceneBuilder {
    /// Alte Hautfarbe (nur noch für Bereiche, die bewusst „opak" bleiben).
    static let hautfarbe = UIColor(red: 0.91, green: 0.87, blue: 0.83, alpha: 1.0)

    // MARK: Glas-Look („Hologramm") — alle Werte an einer Stelle
    static let glasFarbe      = UIColor(red: 0.84, green: 0.90, blue: 1.00, alpha: 1)   // kühles Weiß
    static let glasGlow       = UIColor(red: 0.29, green: 0.56, blue: 0.89, alpha: 1)   // #4A90E2
    static let lichtViolett   = UIColor(red: 0.54, green: 0.17, blue: 0.89, alpha: 1)   // #8A2BE2
    static let ambientFarbe   = UIColor(red: 0.10, green: 0.10, blue: 0.18, alpha: 1)   // #1A1A2E
    static let hintergrund    = UIColor(red: 0.051, green: 0.051, blue: 0.071, alpha: 1) // #0D0D12

    /// Kategorie-Masken: Körperteile sind tapp-/auswählbar, Dekoration (Bodenring) nicht.
    static let koerperMaske = 1
    static let dekoMaske    = 2

    /// Normalzustand eines Körperteils: halbtransparentes, mattes Glas mit schwachem Eigenleuchten.
    static func stileNormal(_ m: SCNMaterial) {
        m.diffuse.contents      = glasFarbe
        m.emission.contents     = glasGlow
        m.emission.intensity    = 0.12
        m.transparency          = 0.55
    }

    /// Aktiver Zustand (ausgewählt / Häufigkeit): getönt, leuchtend, fast opak. `staerke` 0…1.
    static func stileAktiv(_ m: SCNMaterial, tint: UIColor, staerke: Double) {
        let s = CGFloat(min(max(staerke, 0), 1))
        m.diffuse.contents   = tint.mischung(mit: .white, anteil: 0.30)
        m.emission.contents  = tint
        m.emission.intensity = 0.35 + 0.55 * s
        m.transparency       = 0.65 + 0.30 * s
    }

    /// Glas-Material (PBR wie im RealityKit-Beispiel: roughness 0.35, metallic 0.1; Dual-Layer-Transparenz).
    private static func glasMaterial() -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel       = .physicallyBased
        m.roughness.contents  = 0.35      // Milchglas: Rauheit bricht das Licht weich
        m.metalness.contents  = 0.10
        m.transparencyMode    = .dualLayer
        m.isDoubleSided       = true
        stileNormal(m)
        return m
    }

    /// - Parameter mitUSDZ: `false` erzwingt den prozeduralen Körper (nötig für die Gelenk-Ansicht, deren
    ///   Marker auf die prozeduralen Proportionen abgestimmt sind).
    static func build(_ p: BodyProportionen, mitUSDZ: Bool = true) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = hintergrundBild()
        // Weiche Umgebungsbeleuchtung für das PBR-Glas
        scene.lightingEnvironment.contents = UIColor(red: 0.30, green: 0.38, blue: 0.58, alpha: 1)
        scene.lightingEnvironment.intensity = 0.8
        addLights(to: scene)
        addCamera(to: scene)

        let body = SCNNode()
        body.name = "body"
        if !(mitUSDZ && addUSDZParts(to: body, p: p)) {
            addParts(to: body, p: p)   // Fallback: prozeduraler Körper
        }

        let (lo, hi) = body.boundingBox
        body.position.y = -(lo.y + (hi.y - lo.y) / 2)

        scene.rootNode.addChildNode(body)
        scene.rootNode.addChildNode(bodenRing(fussY: body.position.y + lo.y - 0.01))
        return scene
    }

    // MARK: Dekoration

    /// Dunkler Verlauf mit weichem blauem Schein (Hologramm-Bühne).
    private static func hintergrundBild() -> UIImage {
        let groesse = CGSize(width: 512, height: 768)
        return UIGraphicsImageRenderer(size: groesse).image { ctx in
            hintergrund.setFill()
            ctx.fill(CGRect(origin: .zero, size: groesse))
            let farben = [glasGlow.withAlphaComponent(0.30).cgColor,
                          lichtViolett.withAlphaComponent(0.10).cgColor,
                          UIColor.clear.cgColor] as CFArray
            if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: farben, locations: [0, 0.5, 1]) {
                let mitte = CGPoint(x: groesse.width / 2, y: groesse.height * 0.45)
                ctx.cgContext.drawRadialGradient(grad, startCenter: mitte, startRadius: 0,
                                                 endCenter: mitte, endRadius: groesse.width * 0.85, options: [])
            }
        }
    }

    /// Dünner leuchtender Ring am Boden (Dreh-Hinweis). Nicht tappbar.
    private static func bodenRing(fussY: Float) -> SCNNode {
        let torus = SCNTorus(ringRadius: 0.44, pipeRadius: 0.004)
        let m = SCNMaterial()
        m.lightingModel      = .constant
        m.diffuse.contents   = glasGlow
        m.emission.contents  = glasGlow
        m.emission.intensity = 0.9
        m.transparency       = 0.55
        torus.materials = [m]
        let node = SCNNode(geometry: torus)
        node.name = "bodenRing"
        node.position = SCNVector3(0, fussY, 0)
        node.categoryBitMask = dekoMaske
        return node
    }

    // MARK: Lights

    private static func addLights(to scene: SCNScene) {
        // Intensität: 1000 entspricht 1.0 (Vorgabe: ambient 0.6, blau 1.2, violett 0.8)
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.color = ambientFarbe
        ambient.light?.intensity = 800
        scene.rootNode.addChildNode(ambient)

        func richtung(_ farbe: UIColor, _ pos: SCNVector3, _ intensitaet: CGFloat) {
            let n = SCNNode()
            let l = SCNLight()
            l.type = .directional
            l.color = farbe
            l.intensity = intensitaet
            n.light = l
            n.position = pos
            scene.rootNode.addChildNode(n)
            n.look(at: SCNVector3Zero)
        }
        richtung(glasGlow,     SCNVector3( 5, 10,  5), 1200)
        richtung(lichtViolett, SCNVector3(-5, -5, -5),  800)
        // Weiches Frontlicht, damit die Vorderseite lesbar bleibt
        richtung(.white,       SCNVector3( 0,  2,  6),  350)
    }

    // MARK: USDZ-Körper (Meshy-Modell, mit tools/segment_body.py in Regionen zerlegt)

    /// Prim-Name im USDZ → Knotenname (= Name in `SubRegionen`, Konvention: links = x < 0).
    static let usdzRegionen: [String: String] = {
        var d: [String: String] = [
            "Kopf": "Kopf", "Hals": "Hals", "Nacken": "Nacken", "Brust": "Brust",
            "Ruecken_oben": "Rücken oben", "Bauch": "Bauch", "Ruecken_unten": "Rücken unten",
            "Huefte": "Hüfte", "Gesaess": "Gesäss",
        ]
        let seitig: [(String, String)] = [
            ("Schulter", "Schulter"), ("Bizeps", "Bizeps"), ("Trizeps", "Trizeps"),
            ("Ellbogen", "Ellbogen"), ("Unterarm", "Unterarm"), ("Hand", "Hand"),
            ("Oberschenkel_vorne", "Oberschenkel vorne"), ("Oberschenkel_hinten", "Oberschenkel hinten"),
            ("Kniescheibe", "Kniescheibe"), ("Kniekehle", "Kniekehle"),
            ("Schienbein", "Schienbein"), ("Wade", "Wade"), ("Knoechel", "Knöchel"),
            ("Fussspann", "Fußspann"), ("Fussohle", "Fußsohle"), ("Ferse", "Ferse"),
        ]
        for (id, anzeige) in seitig {
            d["\(id)_links"] = "\(anzeige) links"
            d["\(id)_rechts"] = "\(anzeige) rechts"
        }
        return d
    }()

    /// Lädt `KoerperGlas.usdz` und hängt jede Region als eigenen, benannten Knoten an `body`.
    /// Gibt `false` zurück, wenn die Datei fehlt oder unvollständig ist (dann greift der prozedurale Körper).
    private static func addUSDZParts(to body: SCNNode, p: BodyProportionen) -> Bool {
        guard let url = Bundle.main.url(forResource: "KoerperGlas", withExtension: "usdz"),
              let quelle = try? SCNScene(url: url, options: nil) else { return false }

        let container = SCNNode()
        container.name = "usdzKoerper"
        var anzahl = 0
        quelle.rootNode.enumerateHierarchy { node, _ in
            guard let geo = node.geometry else { return }
            let id = node.name ?? geo.name ?? ""
            guard let anzeige = usdzRegionen[id] else { return }
            geo.materials = [glasMaterial()]
            let teil = SCNNode(geometry: geo)
            teil.name = anzeige
            teil.transform = node.worldTransform
            teil.categoryBitMask = koerperMaske
            container.addChildNode(teil)
            anzahl += 1
        }
        // Erwartet: 41 Regionen. Deutlich weniger → Datei/Importer passt nicht → Fallback
        guard anzahl >= 30 else { return false }

        // Personalisierung (Körperscan): Höhe → Gesamtskalierung, Schulterbreite → X-Skalierung
        let hoehe = Float(p.geschaetzteGroesseCM / 164.5)
        let breite = Float(p.schulterBreite / 0.42)
        let basis: Float = 0.9           // Modell ist 1.9 hoch, Kamera/Rahmen sind auf ca. 1.7 ausgelegt
        container.scale = SCNVector3(basis * breite, basis * hoehe, basis * hoehe)
        body.addChildNode(container)
        return true
    }

    // MARK: Camera

    private static func addCamera(to scene: SCNScene) {
        let cam = SCNNode()
        cam.camera = SCNCamera()
        cam.camera!.fieldOfView = 44
        cam.camera!.projectionDirection = .vertical
        cam.camera!.zNear = 0.05
        cam.camera!.zFar  = 20
        cam.position = SCNVector3(0, 0, 3.0)
        scene.rootNode.addChildNode(cam)
    }

    // MARK: Body parts

    private static func addParts(to body: SCNNode, p: BodyProportionen) {
        let huefteTop = p.huefteHoehe
        let bauchTop  = huefteTop + p.bauchHoehe
        let brustTop  = bauchTop  + p.brustHoehe
        let kopfMitte = brustTop  + p.halsLaenge + p.kopfRadius

        let armX  = p.schulterBreite / 2 + 0.04
        let beinX = p.huefteBreite   * 0.28

        // Head
        body.addChildNode(n("Kopf",
            SCNSphere(radius: CGFloat(p.kopfRadius)),
            SCNVector3(0, kopfMitte, 0)))

        // Ears
        let ohrGeo = SCNSphere(radius: 0.022)
        body.addChildNode(n("Ohr links",  ohrGeo, SCNVector3(-(p.kopfRadius + 0.016), kopfMitte - 0.015, 0)))
        body.addChildNode(n("Ohr rechts", ohrGeo, SCNVector3(  p.kopfRadius + 0.016,  kopfMitte - 0.015, 0)))

        // Neck
        body.addChildNode(n("Hals",
            SCNBox(width:  CGFloat(p.torsoBreite * 0.38),
                   height: CGFloat(p.halsLaenge),
                   length: CGFloat(p.torsoTiefe  * 0.55),
                   chamferRadius: 0.03),
            SCNVector3(0, brustTop + p.halsLaenge / 2, 0)))

        // Chest
        body.addChildNode(n("Brust",
            tBox(p.torsoBreite, p.brustHoehe, p.torsoTiefe),
            SCNVector3(0, bauchTop + p.brustHoehe / 2, 0)))

        // Abdomen
        body.addChildNode(n("Bauch",
            tBox(p.torsoBreite * 0.90, p.bauchHoehe, p.torsoTiefe * 0.95),
            SCNVector3(0, huefteTop + p.bauchHoehe / 2, 0)))

        // Hips
        body.addChildNode(n("Hüfte",
            tBox(p.huefteBreite, p.huefteHoehe, p.torsoTiefe * 0.90),
            SCNVector3(0, p.huefteHoehe / 2, 0)))

        // Shoulders
        let sGeo = SCNSphere(radius: 0.062)
        body.addChildNode(n("Schulter links",  sGeo, SCNVector3(-armX + 0.03, brustTop - 0.01, 0)))
        body.addChildNode(n("Schulter rechts", sGeo, SCNVector3( armX - 0.03, brustTop - 0.01, 0)))

        // Upper arms
        let oaGeo = SCNCapsule(capRadius: 0.040, height: CGFloat(p.oberarmLaenge))
        let oaY   = brustTop - 0.02 - p.oberarmLaenge / 2
        body.addChildNode(n("Oberarm links",  oaGeo, SCNVector3(-armX, oaY, 0)))
        body.addChildNode(n("Oberarm rechts", oaGeo, SCNVector3( armX, oaY, 0)))

        // Elbows
        let ellbogenY = oaY - p.oberarmLaenge / 2
        let elbowGeo  = SCNSphere(radius: 0.030)
        body.addChildNode(n("Ellbogen links",  elbowGeo, SCNVector3(-armX - 0.015, ellbogenY, 0.015)))
        body.addChildNode(n("Ellbogen rechts", elbowGeo, SCNVector3( armX + 0.015, ellbogenY, 0.015)))

        // Forearms
        let faGeo = SCNCapsule(capRadius: 0.033, height: CGFloat(p.unterarmLaenge))
        let faY   = oaY - p.oberarmLaenge / 2 - p.unterarmLaenge / 2
        body.addChildNode(n("Unterarm links",  faGeo, SCNVector3(-armX - 0.02, faY, 0)))
        body.addChildNode(n("Unterarm rechts", faGeo, SCNVector3( armX + 0.02, faY, 0)))

        // Hands
        let hGeo = SCNSphere(radius: 0.044)
        let hY   = faY - p.unterarmLaenge / 2 - 0.04
        body.addChildNode(n("Hand links",  hGeo, SCNVector3(-armX - 0.03, hY, 0)))
        body.addChildNode(n("Hand rechts", hGeo, SCNVector3( armX + 0.03, hY, 0)))

        // Upper legs
        let ulGeo = SCNCapsule(capRadius: 0.063, height: CGFloat(p.oberschenkelLaenge))
        let ulY   = -(p.oberschenkelLaenge / 2 + 0.01)
        body.addChildNode(n("Oberschenkel links",  ulGeo, SCNVector3(-beinX, ulY, 0)))
        body.addChildNode(n("Oberschenkel rechts", ulGeo, SCNVector3( beinX, ulY, 0)))

        // Knees
        let knieY   = ulY - p.oberschenkelLaenge / 2
        let kneeGeo = SCNSphere(radius: 0.042)
        body.addChildNode(n("Knie links",  kneeGeo, SCNVector3(-beinX, knieY, 0.03)))
        body.addChildNode(n("Knie rechts", kneeGeo, SCNVector3( beinX, knieY, 0.03)))

        // Lower legs
        let llGeo = SCNCapsule(capRadius: 0.047, height: CGFloat(p.unterschenkelLaenge))
        let llY   = -(p.oberschenkelLaenge + p.unterschenkelLaenge / 2 + 0.02)
        body.addChildNode(n("Unterschenkel links",  llGeo, SCNVector3(-beinX * 0.88, llY, 0)))
        body.addChildNode(n("Unterschenkel rechts", llGeo, SCNVector3( beinX * 0.88, llY, 0)))

        // Ankles
        let knoechelY = -(p.oberschenkelLaenge + p.unterschenkelLaenge + 0.02)
        let ankleGeo  = SCNSphere(radius: 0.030)
        body.addChildNode(n("Knöchel links",  ankleGeo, SCNVector3(-beinX - 0.02, knoechelY, 0.01)))
        body.addChildNode(n("Knöchel rechts", ankleGeo, SCNVector3( beinX + 0.02, knoechelY, 0.01)))

        // Feet
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
        // Jedes Teil bekommt eigene Geometrie + eigenes Material (individuelle Färbung)
        let uniqueGeo = (geo.copy() as? SCNGeometry) ?? geo
        uniqueGeo.materials = [glasMaterial()]

        let node = SCNNode(geometry: uniqueGeo)
        node.name     = name
        node.position = pos
        node.categoryBitMask = koerperMaske
        return node
    }
}

// MARK: - Farb-Hilfe

private extension UIColor {
    /// Mischt mit einer anderen Farbe (`anteil` 0…1 der anderen Farbe).
    func mischung(mit andere: UIColor, anteil: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        andere.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let t = min(max(anteil, 0), 1)
        return UIColor(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t, blue: b1 + (b2 - b1) * t, alpha: 1)
    }
}
