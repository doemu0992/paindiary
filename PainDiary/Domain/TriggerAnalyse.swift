import Foundation

/// Merkmale eines Tages für die Trigger-Erkennung.
nonisolated struct TagesMerkmale: Equatable, Sendable {
    let tag: DayKey
    /// Mittlere Schmerzstärke des Tages (`nil` = kein Schmerzeintrag).
    let schmerz: Double?
    /// Dokumentierte potenzielle Auslöser/Faktoren dieses Tages (z. B. „Stress", „Schlafmangel").
    let faktoren: Set<String>
}

nonisolated enum Konfidenz: String, Sendable {
    case niedrig, mittel, hoch
}

nonisolated struct TriggerErgebnis: Equatable, Sendable {
    let name: String
    /// Anzahl Tage mit Faktor (und vorhandenem Schmerzwert).
    let tageMit: Int
    let tageOhne: Int
    let mittelMit: Double
    let mittelOhne: Double
    var differenz: Double { mittelMit - mittelOhne }
    let konfidenz: Konfidenz
}

/// Erkennt Faktoren, nach denen die Schmerzstärke im Mittel höher ist.
///
/// **Wichtig:** Das ist eine Korrelation, kein Nachweis für Ursächlichkeit. Die Oberfläche muss dies
/// kenntlich machen und keine Diagnosen ableiten.
nonisolated enum TriggerAnalyse {

    /// - Parameters:
    ///   - verzoegerungTage: 0 = Schmerz am selben Tag, 1 = Schmerz am Folgetag.
    ///   - minFaelle: Mindestzahl Tage **mit** und **ohne** Faktor; sonst wird der Faktor nicht ausgewiesen.
    static func auswerten(tage: [TagesMerkmale], verzoegerungTage: Int = 0, minFaelle: Int = 3) -> [TriggerErgebnis] {
        var schmerzProTag: [DayKey: Double] = [:]
        for t in tage { if let s = t.schmerz { schmerzProTag[t.tag] = s } }

        let alleFaktoren = Set(tage.flatMap(\.faktoren))
        var ergebnisse: [TriggerErgebnis] = []

        for faktor in alleFaktoren {
            var mit: [Double] = []
            var ohne: [Double] = []
            for t in tage {
                guard let s = schmerzProTag[t.tag.addiere(tage: verzoegerungTage)] else { continue }
                if t.faktoren.contains(faktor) { mit.append(s) } else { ohne.append(s) }
            }
            guard mit.count >= minFaelle, ohne.count >= minFaelle,
                  let mMit = Statistik.mittelwert(mit), let mOhne = Statistik.mittelwert(ohne) else { continue }
            let konfidenz: Konfidenz = mit.count >= 10 ? .hoch : (mit.count >= 5 ? .mittel : .niedrig)
            ergebnisse.append(TriggerErgebnis(
                name: faktor, tageMit: mit.count, tageOhne: ohne.count,
                mittelMit: mMit, mittelOhne: mOhne, konfidenz: konfidenz))
        }
        return ergebnisse.sorted { $0.differenz == $1.differenz ? $0.name < $1.name : $0.differenz > $1.differenz }
    }
}
