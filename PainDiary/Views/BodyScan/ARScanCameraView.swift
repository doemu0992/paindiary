import SwiftUI
import ARKit
import SceneKit
import Vision
import simd

// MARK: - Phase

enum BodyScanPhase: Equatable {
    case suchend
    case erkannt
    case verarbeiten
}

// MARK: - AR Camera View

struct ARScanCameraView: UIViewRepresentable {
    @Binding var phase: BodyScanPhase
    let onSilhouette: (UIImage, BodyProportionen?) -> Void

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView()
        view.session.delegate = context.coordinator
        view.automaticallyUpdatesLighting = false
        view.scene = SCNScene()

        let config = ARBodyTrackingConfiguration()
        view.session.run(config, options: [.resetTracking, .removeExistingAnchors])

        context.coordinator.arView = view
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(phase: $phase, onSilhouette: onSilhouette)
    }

    class Coordinator: NSObject, ARSessionDelegate {
        @Binding var phase: BodyScanPhase
        var arView: ARSCNView?
        let onSilhouette: (UIImage, BodyProportionen?) -> Void

        private var erkennungsStart: Date?
        private var ausgefuehrt = false

        init(phase: Binding<BodyScanPhase>, onSilhouette: @escaping (UIImage, BodyProportionen?) -> Void) {
            _phase = phase
            self.onSilhouette = onSilhouette
        }

        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            aktualisiereStatus(session: session)
        }

        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            aktualisiereStatus(session: session)
        }

        func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
            aktualisiereStatus(session: session)
        }

        private func aktualisiereStatus(session: ARSession) {
            guard !ausgefuehrt else { return }

            let hatKoerper = session.currentFrame?.anchors.contains { $0 is ARBodyAnchor } ?? false

            DispatchQueue.main.async {
                if hatKoerper {
                    if self.erkennungsStart == nil {
                        self.erkennungsStart = Date()
                        self.phase = .erkannt
                    }
                    let vergangen = Date().timeIntervalSince(self.erkennungsStart ?? Date())
                    if vergangen >= 2.0 {
                        self.ausgefuehrt = true
                        self.phase = .verarbeiten
                        self.aufnehmen()
                    }
                } else {
                    self.erkennungsStart = nil
                    self.phase = .suchend
                }
            }
        }

        private func aufnehmen() {
            guard let session = arView?.session,
                  let frame = session.currentFrame else { return }

            let proportionen = frame.anchors
                .compactMap { $0 as? ARBodyAnchor }
                .first
                .map { BodyProportionen.from(skeleton: $0.skeleton) }

            Task.detached(priority: .userInitiated) {
                let bild = await self.erstelleSilhouette(frame: frame)
                await MainActor.run { self.onSilhouette(bild, proportionen) }
            }
        }

        private func erstelleSilhouette(frame: ARFrame) async -> UIImage {
            let ciRoh = CIImage(cvPixelBuffer: frame.capturedImage).oriented(.right)
            let ciCtx = CIContext()
            guard let cgRoh = ciCtx.createCGImage(ciRoh, from: ciRoh.extent) else {
                return UIImage()
            }

            let request = VNGeneratePersonSegmentationRequest()
            request.qualityLevel = .accurate
            let handler = VNImageRequestHandler(cgImage: cgRoh)
            try? handler.perform([request])

            guard let observation = request.results?.first else {
                return UIImage(cgImage: cgRoh)
            }

            return anwendeMaske(original: cgRoh, maskePuffer: observation.pixelBuffer)
        }

        private func anwendeMaske(original: CGImage, maskePuffer: CVPixelBuffer) -> UIImage {
            let breite = CGFloat(original.width)
            let hoehe  = CGFloat(original.height)

            let maskeCI = CIImage(cvPixelBuffer: maskePuffer)
            let sx = breite / maskeCI.extent.width
            let sy = hoehe  / maskeCI.extent.height
            let skaliertesMaske = maskeCI.transformed(by: CGAffineTransform(scaleX: sx, y: sy))

            let hautfarbe  = CIImage(color: CIColor(red: 0.91, green: 0.88, blue: 0.84, alpha: 1.0))
                .cropped(to: CGRect(x: 0, y: 0, width: breite, height: hoehe))
            let transparent = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0))
                .cropped(to: CGRect(x: 0, y: 0, width: breite, height: hoehe))

            guard let blend = CIFilter(name: "CIBlendWithMask") else {
                return UIImage(cgImage: original)
            }
            blend.setValue(hautfarbe,    forKey: kCIInputImageKey)
            blend.setValue(transparent,  forKey: kCIInputBackgroundImageKey)
            blend.setValue(skaliertesMaske, forKey: kCIInputMaskImageKey)

            guard let output = blend.outputImage else { return UIImage(cgImage: original) }

            let ctx = CIContext()
            guard let cgResult = ctx.createCGImage(output, from: output.extent) else {
                return UIImage(cgImage: original)
            }
            return UIImage(cgImage: cgResult)
        }
    }
}

// MARK: - BodyProportionen extraction

extension BodyProportionen {
    static func from(skeleton: ARSkeleton3D) -> BodyProportionen {
        let names = skeleton.definition.jointNames

        func pos(_ joint: String) -> simd_float3? {
            guard let idx = names.firstIndex(of: joint),
                  idx < skeleton.jointModelTransforms.count else { return nil }
            let t = skeleton.jointModelTransforms[idx]
            return simd_float3(t.columns.3.x, t.columns.3.y, t.columns.3.z)
        }

        func dist(_ a: String, _ b: String) -> Float? {
            guard let pa = pos(a), let pb = pos(b) else { return nil }
            return simd_distance(pa, pb)
        }

        var p = BodyProportionen()

        if let d = dist("left_shoulder_1_joint", "right_shoulder_1_joint"), d > 0.20 {
            p.schulterBreite = d
            p.torsoBreite    = d * 0.70
            p.huefteBreite   = d * 0.86
        }
        if let d = dist("left_shoulder_1_joint", "left_arm_joint"),    d > 0.12 { p.oberarmLaenge      = d }
        if let d = dist("left_arm_joint",         "left_forearm_joint"), d > 0.12 { p.unterarmLaenge    = d }
        if let d = dist("left_upLeg_joint",        "left_leg_joint"),    d > 0.20 { p.oberschenkelLaenge = d }
        if let d = dist("left_leg_joint",          "left_foot_joint"),   d > 0.18 { p.unterschenkelLaenge = d }

        if let root = pos("hips_joint"), let neck = pos("neck_1_joint") {
            let h = simd_distance(root, neck)
            if h > 0.30 {
                p.huefteHoehe = h * 0.22
                p.bauchHoehe  = h * 0.31
                p.brustHoehe  = h * 0.47
                p.halsLaenge  = h * 0.13
            }
        }

        return p
    }
}
