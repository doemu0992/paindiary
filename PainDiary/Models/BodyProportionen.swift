import Foundation

struct BodyProportionen: Codable {
    var kopfRadius: Float          = 0.115
    var halsLaenge: Float          = 0.095
    var schulterBreite: Float      = 0.420
    var torsoBreite: Float         = 0.285
    var torsoTiefe: Float          = 0.185
    var brustHoehe: Float          = 0.220
    var bauchHoehe: Float          = 0.165
    var huefteHoehe: Float         = 0.110
    var huefteBreite: Float        = 0.340
    var oberarmLaenge: Float       = 0.275
    var unterarmLaenge: Float      = 0.245
    var oberschenkelLaenge: Float  = 0.430
    var unterschenkelLaenge: Float = 0.395

    static let standard = BodyProportionen()

    // Default total height ≈ 1.645 m
    private static let standardGroesseCM: Double = 164.5

    static func fuerGroesse(_ cm: Double) -> BodyProportionen {
        let s = Float(cm / standardGroesseCM)
        return BodyProportionen(
            kopfRadius:          0.115 * s,
            halsLaenge:          0.095 * s,
            schulterBreite:      0.420 * s,
            torsoBreite:         0.285 * s,
            torsoTiefe:          0.185 * s,
            brustHoehe:          0.220 * s,
            bauchHoehe:          0.165 * s,
            huefteHoehe:         0.110 * s,
            huefteBreite:        0.340 * s,
            oberarmLaenge:       0.275 * s,
            unterarmLaenge:      0.245 * s,
            oberschenkelLaenge:  0.430 * s,
            unterschenkelLaenge: 0.395 * s
        )
    }

    var geschaetzteGroesseCM: Double {
        Double((oberschenkelLaenge + unterschenkelLaenge) / 0.825 * Float(Self.standardGroesseCM))
    }
}
