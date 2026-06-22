import Foundation

struct SleepNightSummary: Codable, Identifiable {
    var datum: TimeInterval
    var qualitaet: Double
    var dauerSek: Double
    var tiefPct: Double
    var remPct: Double
    var leichtPct: Double
    var wachPct: Double
    var schnarchenAnzahl: Int
    var sprechenAnzahl: Int
    var geraeuschAnzahl: Int

    var id: TimeInterval { datum }
    var date: Date { Date(timeIntervalSince1970: datum) }
    var dauerStunden: Double { dauerSek / 3600 }

    var geraeuschGesamtAnzahl: Int { schnarchenAnzahl + sprechenAnzahl + geraeuschAnzahl }
    var hatGeraeusche: Bool { geraeuschGesamtAnzahl > 0 }
}

extension SleepNightSummary {
    static let appGroupKey = "sb_sessions"
    static let appGroupSuite = "group.com.doemu0992.sleepbuddy"

    static func laden() -> [SleepNightSummary] {
        guard let defaults = UserDefaults(suiteName: appGroupSuite),
              let data = defaults.data(forKey: appGroupKey),
              let decoded = try? JSONDecoder().decode([SleepNightSummary].self, from: data)
        else { return [] }
        return decoded.sorted { $0.datum > $1.datum }
    }

    static var istVerfuegbar: Bool {
        guard let defaults = UserDefaults(suiteName: appGroupSuite) else { return false }
        return defaults.data(forKey: appGroupKey) != nil
    }

    static func loeschen(_ nacht: SleepNightSummary) {
        var alle = laden()
        alle.removeAll { $0.datum == nacht.datum }
        speichern(alle)
    }

    private static func speichern(_ summaries: [SleepNightSummary]) {
        guard let defaults = UserDefaults(suiteName: appGroupSuite),
              let data = try? JSONEncoder().encode(summaries)
        else { return }
        defaults.set(data, forKey: appGroupKey)
    }
}
