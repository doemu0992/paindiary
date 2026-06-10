import Foundation

enum ChipSpeicher {
    static func laden(schluessel: String) -> [String] {
        UserDefaults.standard.stringArray(forKey: schluessel) ?? []
    }

    static func hinzufuegen(_ wert: String, schluessel: String, max: Int = 15) {
        let bereinigt = wert.trimmingCharacters(in: .whitespaces)
        guard !bereinigt.isEmpty else { return }
        var liste = laden(schluessel: schluessel)
        guard !liste.contains(bereinigt) else { return }
        liste.insert(bereinigt, at: 0)
        if liste.count > max { liste = Array(liste.prefix(max)) }
        UserDefaults.standard.set(liste, forKey: schluessel)
    }
}
