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
        let ausloeser = eintraege.filter { !$0.istHautEintrag }
            .map(\.ausloeser).filter { !$0.isEmpty }
        guard !ausloeser.isEmpty else { return nil }
        var zaehler: [String: Int] = [:]
        for a in ausloeser { zaehler[a, default: 0] += 1 }
        return zaehler.max(by: { $0.value < $1.value })?.key
    }

    private var wochenKalender: Calendar {
        var kal = Calendar.current
        kal.firstWeekday = 2  // Montag
        return kal
    }

    // Tage Mo–So der aktuellen Woche bis heute, nur Tage mit Einträgen
    var dieseWocheEintraege: [(datum: Date, schmerz: Double)] {
        let kal = wochenKalender
        guard let interval = kal.dateInterval(of: .weekOfYear, for: Date()) else { return [] }
        let heute = kal.startOfDay(for: Date())
        return (0..<7).compactMap { versatz -> (datum: Date, schmerz: Double)? in
            guard let tag = kal.date(byAdding: .day, value: versatz, to: interval.start),
                  kal.startOfDay(for: tag) <= heute else { return nil }
            let tagesEintraege = eintraege.filter { !$0.istHautEintrag && kal.isDate($0.datum, inSameDayAs: tag) }
            guard !tagesEintraege.isEmpty else { return nil }
            let schnitt = Double(tagesEintraege.map(\.schmerzstaerke).reduce(0, +)) / Double(tagesEintraege.count)
            return (datum: tag, schmerz: schnitt)
        }
    }

    var wochenschmerz: Double {
        let punkte = dieseWocheEintraege
        guard !punkte.isEmpty else { return 0 }
        return punkte.map(\.schmerz).reduce(0, +) / Double(punkte.count)
    }

    var vorwochenschmerz: Double? {
        let kal = wochenKalender
        guard let interval = kal.dateInterval(of: .weekOfYear, for: Date()),
              let vorwocheStart = kal.date(byAdding: .weekOfYear, value: -1, to: interval.start) else { return nil }
        var punkte: [Double] = []
        for versatz in 0..<7 {
            guard let tag = kal.date(byAdding: .day, value: versatz, to: vorwocheStart) else { continue }
            let tagesEintraege = eintraege.filter { !$0.istHautEintrag && kal.isDate($0.datum, inSameDayAs: tag) }
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
