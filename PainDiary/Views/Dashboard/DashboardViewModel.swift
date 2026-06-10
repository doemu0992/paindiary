import Foundation
import SwiftData

@Observable
class DashboardViewModel {
    var eintraege: [PainEntry] = []

    var durchschnittsSchmerz: Double {
        let schmerzEintraege = eintraege.filter { !$0.istHautEintrag }
        guard !schmerzEintraege.isEmpty else { return 0 }
        return Double(schmerzEintraege.map(\.schmerzstaerke).reduce(0, +)) / Double(schmerzEintraege.count)
    }

    var haeufigsterAusloeser: String? {
        let ausloeser = eintraege.map(\.ausloeser).filter { !$0.isEmpty }
        guard !ausloeser.isEmpty else { return nil }
        var zaehler: [String: Int] = [:]
        for a in ausloeser { zaehler[a, default: 0] += 1 }
        return zaehler.max(by: { $0.value < $1.value })?.key
    }

    var letzten7TageEintraege: [(datum: Date, schmerz: Double)] {
        let kalender = Calendar.current
        let heute = Date()
        return (0..<7).map { versatz -> (datum: Date, schmerz: Double) in
            let tag = kalender.date(byAdding: .day, value: -versatz, to: heute) ?? heute
            let tagesEintraege = eintraege.filter {
                !$0.istHautEintrag && kalender.isDate($0.datum, inSameDayAs: tag)
            }
            let durchschnitt = tagesEintraege.isEmpty
                ? 0.0
                : Double(tagesEintraege.map(\.schmerzstaerke).reduce(0, +)) / Double(tagesEintraege.count)
            return (datum: tag, schmerz: durchschnitt)
        }.reversed()
    }

    var wochenschmerz: Double {
        let punkte = letzten7TageEintraege
        guard !punkte.isEmpty else { return 0 }
        return punkte.map(\.schmerz).reduce(0, +) / Double(punkte.count)
    }

    var vorwochenschmerz: Double? {
        let kalender = Calendar.current
        let heute = Date()
        var punkte: [Double] = []
        for versatz in 7..<14 {
            guard let tag = kalender.date(byAdding: .day, value: -versatz, to: heute) else { continue }
            let tagesEintraege = eintraege.filter { kalender.isDate($0.datum, inSameDayAs: tag) }
            guard !tagesEintraege.isEmpty else { continue }
            let schnitt = Double(tagesEintraege.map(\.schmerzstaerke).reduce(0, +)) / Double(tagesEintraege.count)
            punkte.append(schnitt)
        }
        guard !punkte.isEmpty else { return nil }
        return punkte.reduce(0, +) / Double(punkte.count)
    }

    // positive = Schmerz gestiegen (schlechter), negative = gesunken (besser)
    var trendVorwoche: Double? {
        guard let vorwoche = vorwochenschmerz else { return nil }
        return wochenschmerz - vorwoche
    }
}
