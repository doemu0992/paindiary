import Foundation
import SwiftUI

@MainActor
final class BodyScanService: ObservableObject {
    static let shared = BodyScanService()

    @Published var hatScan: Bool = false
    @Published var proportionen: BodyProportionen = BodyProportionen()

    private init() { laden() }

    func scanErgebnisSpeichern(_ p: BodyProportionen) {
        proportionen = p
        hatScan = true
        speichern()
    }

    func scanZuruecksetzen() {
        proportionen = BodyProportionen()
        hatScan = false
        speichern()
    }

    // MARK: - Persistence

    private var proportionenURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("body_proportionen.json")
    }

    private func laden() {
        guard let data = try? Data(contentsOf: proportionenURL),
              let p = try? JSONDecoder().decode(BodyProportionen.self, from: data) else { return }
        proportionen = p
        hatScan = true
    }

    private func speichern() {
        if let data = try? JSONEncoder().encode(proportionen) {
            try? data.write(to: proportionenURL, options: .atomic)
        }
    }
}
