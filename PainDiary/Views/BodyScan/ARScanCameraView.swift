import SwiftUI
import ARKit
import SceneKit
import Vision

// MARK: - Phase

enum BodyScanPhase: Equatable {
    case suchend
    case erkannt
    case verarbeiten
}

// MARK: - AR Camera View

struct ARScanCameraView: UIViewRepresentable {
    @Binding var phase: BodyScanPhase
    let onSilhouette: (UIImage) -> Void

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
        let onSilhouette: (UIImage) -> Void

        private var erkennungsStart: Date?
        private var ausgefuehrt = false

        init(phase: Binding<BodyScanPhase>, onSilhouette: @escaping (UIImage) -> Void) {
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
            guard let frame = arView?.session.currentFrame else { return }
            Task.detached(priority: .userInitiated) {
                let bild = await self.erstelleSilhouette(frame: frame)
                await MainActor.run { self.onSilhouette(bild) }
            }
        }

        private func erstelleSilhouette(frame: ARFrame) async -> UIImage {
            // Convert ARKit pixel buffer → portrait-oriented UIImage
            let ciRoh = CIImage(cvPixelBuffer: frame.capturedImage).oriented(.right)
            let ciCtx = CIContext()
            guard let cgRoh = ciCtx.createCGImage(ciRoh, from: ciRoh.extent) else {
                return UIImage()
            }

            // Person segmentation
            let request = VNGeneratePersonSegmentationRequest()
            request.qualityLevel = .accurate
            let handler = VNImageRequestHandler(cgImage: cgRoh)
            try? handler.perform([request])

            guard let observation = request.results?.first else {
                // Fallback: plain photo without segmentation
                return UIImage(cgImage: cgRoh)
            }

            return anwendeMaske(original: cgRoh, maskePuffer: observation.pixelBuffer)
        }

        private func anwendeMaske(original: CGImage, maskePuffer: CVPixelBuffer) -> UIImage {
            let breite = CGFloat(original.width)
            let hoehe = CGFloat(original.height)

            // Scale mask to match original image size
            let maskeCI = CIImage(cvPixelBuffer: maskePuffer)
            let sx = breite / maskeCI.extent.width
            let sy = hoehe / maskeCI.extent.height
            let skaliertesMaske = maskeCI.transformed(by: CGAffineTransform(scaleX: sx, y: sy))

            // Skin-toned fill
            let hautfarbe = CIImage(color: CIColor(red: 0.91, green: 0.88, blue: 0.84, alpha: 1.0))
                .cropped(to: CGRect(x: 0, y: 0, width: breite, height: hoehe))
            let transparent = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0))
                .cropped(to: CGRect(x: 0, y: 0, width: breite, height: hoehe))

            guard let blend = CIFilter(name: "CIBlendWithMask") else {
                return UIImage(cgImage: original)
            }
            blend.setValue(hautfarbe, forKey: kCIInputImageKey)
            blend.setValue(transparent, forKey: kCIInputBackgroundImageKey)
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
