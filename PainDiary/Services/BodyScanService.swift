import SwiftUI
import ARKit

@MainActor
final class BodyScanService: ObservableObject {
    static let shared = BodyScanService()

    @Published var vorneBild: UIImage? = nil
    @Published var hintenBild: UIImage? = nil

    var hatScan: Bool { vorneBild != nil }
    var arUnterstuetzt: Bool { ARBodyTrackingConfiguration.isSupported }

    private var vorneURL: URL { dokumentURL("body_scan_vorne.png") }
    private var hintenURL: URL { dokumentURL("body_scan_hinten.png") }

    init() { laden() }

    func speichern(bild: UIImage, vorne: Bool) {
        let url = vorne ? vorneURL : hintenURL
        if let data = bild.pngData() {
            try? data.write(to: url, options: .atomic)
        }
        laden()
    }

    func loeschen() {
        try? FileManager.default.removeItem(at: vorneURL)
        try? FileManager.default.removeItem(at: hintenURL)
        laden()
    }

    private func laden() {
        vorneBild = UIImage(contentsOfFile: vorneURL.path)
        hintenBild = UIImage(contentsOfFile: hintenURL.path)
    }

    private func dokumentURL(_ name: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(name)
    }
}
