import SwiftUI
import Combine
import ARKit

@MainActor
final class BodyScanService: ObservableObject {
    static let shared = BodyScanService()

    @Published var vorneBild: UIImage? = nil
    @Published var hintenBild: UIImage? = nil
    @Published var proportionen = BodyProportionen()

    var hatScan: Bool { vorneBild != nil }
    var arUnterstuetzt: Bool { ARBodyTrackingConfiguration.isSupported }

    private var vorneURL: URL        { dokumentURL("body_scan_vorne.png") }
    private var hintenURL: URL       { dokumentURL("body_scan_hinten.png") }
    private var proportionenURL: URL { dokumentURL("body_proportionen.json") }

    init() { laden() }

    func speichern(bild: UIImage, vorne: Bool) {
        let url = vorne ? vorneURL : hintenURL
        if let data = bild.pngData() {
            try? data.write(to: url, options: .atomic)
        }
        laden()
    }

    func speichernProportionen(_ p: BodyProportionen) {
        proportionen = p
        if let data = try? JSONEncoder().encode(p) {
            try? data.write(to: proportionenURL, options: .atomic)
        }
    }

    func loeschen() {
        try? FileManager.default.removeItem(at: vorneURL)
        try? FileManager.default.removeItem(at: hintenURL)
        try? FileManager.default.removeItem(at: proportionenURL)
        laden()
    }

    private func laden() {
        vorneBild  = UIImage(contentsOfFile: vorneURL.path)
        hintenBild = UIImage(contentsOfFile: hintenURL.path)
        if let data = try? Data(contentsOf: proportionenURL),
           let p    = try? JSONDecoder().decode(BodyProportionen.self, from: data) {
            proportionen = p
        }
    }

    private func dokumentURL(_ name: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(name)
    }
}
