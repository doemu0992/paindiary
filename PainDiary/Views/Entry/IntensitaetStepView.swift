import SwiftUI

struct IntensitaetStepView: View {
    @Binding var schmerzstaerke: Int

    var body: some View {
        VStack(spacing: 32) {
            Text("Wie stark sind deine Schmerzen?")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            SchmerzBadge(staerke: schmerzstaerke)
                .scaleEffect(2.5)
                .frame(height: 110)

            Text(beschreibung)
                .font(.headline)
                .foregroundStyle(SchmerzBadge.farbe(fuer: schmerzstaerke))
                .animation(.easeInOut, value: schmerzstaerke)

            VStack(spacing: 16) {
                HStack {
                    Text("0 – Kein Schmerz")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("10 – Unerträglich")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Slider(value: Binding(
                    get: { Double(schmerzstaerke) },
                    set: { schmerzstaerke = Int($0) }
                ), in: 0...10, step: 1)
                .tint(SchmerzBadge.farbe(fuer: schmerzstaerke))

                HStack {
                    ForEach(0...10, id: \.self) { i in
                        Text("\(i)")
                            .font(.system(size: 10))
                            .foregroundStyle(i == schmerzstaerke ? SchmerzBadge.farbe(fuer: i) : .secondary.opacity(0.5))
                            .fontWeight(i == schmerzstaerke ? .bold : .regular)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal)
    }

    private var beschreibung: String {
        switch schmerzstaerke {
        case 0: return "Kein Schmerz"
        case 1...2: return "Leicht – kaum bemerkbar"
        case 3...4: return "Mild – ablenkbar"
        case 5...6: return "Mässig – beeinträchtigt"
        case 7...8: return "Stark – schwer erträglich"
        case 9...10: return "Sehr stark – unerträglich"
        default: return ""
        }
    }
}
