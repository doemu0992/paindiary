import Foundation

/// Einheitlicher Umgang mit kommagetrennten Listenfeldern („Stress, Wetter, Schlafmangel").
///
/// Das Speicherformat bleibt aus Kompatibilitätsgründen `"a, b, c"`.
/// Damit ein Listenelement das Format nicht zerstört, werden Kommas innerhalb eines
/// Elements beim Schreiben ersetzt (`bereinige`).
nonisolated enum ListenFeld {
    static let trenner = ", "

    /// Zerlegt ein gespeichertes Listenfeld; leere Elemente werden verworfen.
    static func parse(_ text: String) -> [String] {
        text.components(separatedBy: trenner)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Fügt Elemente zusammen. Reihenfolge bleibt erhalten, Duplikate werden entfernt.
    static func join(_ elemente: [String]) -> String {
        var gesehen = Set<String>()
        var ergebnis: [String] = []
        for roh in elemente {
            let e = bereinige(roh)
            guard !e.isEmpty, gesehen.insert(e).inserted else { continue }
            ergebnis.append(e)
        }
        return ergebnis.joined(separator: trenner)
    }

    /// Macht ein einzelnes Element „listensicher": keine Kommas/Zeilenumbrüche, getrimmt.
    static func bereinige(_ element: String) -> String {
        var s = element.replacingOccurrences(of: ",", with: " –")
        s = s.replacingOccurrences(of: "\n", with: " ")
        while s.contains("  ") { s = s.replacingOccurrences(of: "  ", with: " ") }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
