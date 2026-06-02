import Foundation
import SwiftData

@Observable
class DashboardViewModel {
    var eintraege: [PainEntry] = []

    var durchschnittsSchmerz: Double {
        guard !eintraege.isEmpty else { return 0 }
        return Double(eintraege.map(\.schmerzstaerke).reduce(0, +)) / Double(eintraege.count)
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
        return (0..<7).compactMap { versatz -> (datum: Date, schmerz: Double)? in
            guard let tag = kalender.date(byAdding: .day, value: -versatz, to: heute) else { return nil }
            let tagesEintraege = eintraege.filter {
                kalender.isDate($0.datum, inSameDayAs: tag)
            }
            guard !tagesEintraege.isEmpty else { return nil }
            let durchschnitt = Double(tagesEintraege.map(\.schmerzstaerke).reduce(0, +)) / Double(tagesEintraege.count)
            return (datum: tag, schmerz: durchschnitt)
        }.reversed()
    }

    var wochenschmerz: Double {
        let punkte = letzten7TageEintraege
        guard !punkte.isEmpty else { return 0 }
        return punkte.map(\.schmerz).reduce(0, +) / Double(punkte.count)
    }
}
