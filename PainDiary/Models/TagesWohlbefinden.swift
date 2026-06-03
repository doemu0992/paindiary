import Foundation
import SwiftData

@Model final class TagesWohlbefinden {
    var datum: Date        // startOfDay
    var wasserMl: Int      // ml water drunk today, default 0
    var wasserZielMl: Int  // goal in ml, default 2000

    var fortschritt: Double {
        guard wasserZielMl > 0 else { return 0 }
        return min(Double(wasserMl) / Double(wasserZielMl), 1.0)
    }

    init(datum: Date = Date(), wasserMl: Int = 0, wasserZielMl: Int = 2000) {
        self.datum = Calendar.current.startOfDay(for: datum)
        self.wasserMl = wasserMl
        self.wasserZielMl = wasserZielMl
    }
}
