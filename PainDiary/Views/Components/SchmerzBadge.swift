import SwiftUI

struct SchmerzBadge: View {
    let staerke: Int

    var body: some View {
        ZStack {
            Circle()
                .fill(Self.farbe(fuer: staerke).gradient)
                .frame(width: 44, height: 44)
            Text("\(staerke)")
                .font(.title3.bold())
                .foregroundStyle(.white)
        }
    }

    static func farbe(fuer staerke: Int) -> Color {
        switch staerke {
        case 0...2: .green
        case 3...4: .yellow
        case 5...6: .orange
        case 7...8: .red
        default:    Color(red: 0.7, green: 0, blue: 0)
        }
    }
}
