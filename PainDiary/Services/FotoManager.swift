import Foundation
import UIKit

enum FotoManager {
    private static var fotoVerzeichnis: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("PainDiaryFotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func speichern(_ bild: UIImage) -> String {
        let name = UUID().uuidString + ".jpg"
        let url = fotoVerzeichnis.appendingPathComponent(name)
        if let data = bild.jpegData(compressionQuality: 0.82) {
            try? data.write(to: url)
        }
        return name
    }

    static func laden(dateiname: String) -> UIImage? {
        guard !dateiname.isEmpty else { return nil }
        let url = fotoVerzeichnis.appendingPathComponent(dateiname)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    static func loeschen(dateiname: String) {
        guard !dateiname.isEmpty else { return }
        let url = fotoVerzeichnis.appendingPathComponent(dateiname)
        try? FileManager.default.removeItem(at: url)
    }
}
