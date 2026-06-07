import UIKit

enum FotoManager {

    private static var verzeichnis: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir  = docs.appendingPathComponent("PainDiaryFotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func speichern(_ bild: UIImage) -> String {
        let name = UUID().uuidString + ".jpg"
        if let data = bild.jpegData(compressionQuality: 0.82) {
            try? data.write(to: verzeichnis.appendingPathComponent(name))
        }
        return name
    }

    static func laden(dateiname: String) -> UIImage? {
        guard !dateiname.isEmpty else { return nil }
        return UIImage(contentsOfFile: verzeichnis.appendingPathComponent(dateiname).path)
    }

    static func loeschen(dateiname: String) {
        guard !dateiname.isEmpty else { return }
        try? FileManager.default.removeItem(at: verzeichnis.appendingPathComponent(dateiname))
    }
}
