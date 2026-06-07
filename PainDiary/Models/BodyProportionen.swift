import Foundation

struct BodyProportionen: Codable {
    var schulterBreite: Float = 0.42
    var beckenBreite: Float = 0.34
    var koerperGroesse: Float = 1.75

    static let standard = BodyProportionen()
}
