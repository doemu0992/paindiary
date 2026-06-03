import SwiftUI
import SwiftData

struct WellnessView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TagesWohlbefinden.datum, order: .reverse) private var eintraege: [TagesWohlbefinden]

    @State private var heuteEintrag: TagesWohlbefinden? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    wasserTrackerKarte
                    streakKarte
                }
                .padding()
                .padding(.bottom, 30)
            }
            .navigationTitle("Wohlbefinden")
        }
        .onAppear {
            stelleHeuteEintragSicher()
        }
    }

    // MARK: - Wasser-Tracker

    private var wasserTrackerKarte: some View {
        let eintrag = heuteEintrag
        let wasserMl = eintrag?.wasserMl ?? 0
        let wasserZiel = eintrag?.wasserZielMl ?? 2000
        let fortschritt = min(Double(wasserMl) / Double(wasserZiel), 1.0)

        return VStack(spacing: 16) {
            HStack {
                Label("Wasser-Tracker", systemImage: "drop.fill")
                    .font(.headline)
                    .foregroundStyle(.teal)
                Spacer()
            }

            ZStack {
                Circle()
                    .stroke(Color.teal.opacity(0.15), lineWidth: 14)
                Circle()
                    .trim(from: 0, to: fortschritt)
                    .stroke(Color.teal, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5), value: wasserMl)
                VStack(spacing: 4) {
                    Text("\(wasserMl)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.teal)
                    Text("von \(wasserZiel) ml")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.0f%%", fortschritt * 100))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 160, height: 160)
            .padding(.vertical, 8)

            HStack(spacing: 10) {
                ForEach([150, 200, 330, 500], id: \.self) { menge in
                    Button { trinken(ml: menge) } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "drop.fill")
                                .font(.caption)
                                .foregroundStyle(.teal)
                            Text("+\(menge)").font(.caption.bold())
                            Text("ml").font(.caption2).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.teal.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }

            if wasserMl > 0 {
                Button {
                    heuteEintrag?.wasserMl = max(0, wasserMl - 150)
                } label: {
                    Label("Rückgängig", systemImage: "arrow.uturn.backward")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            HStack {
                Text("Tagesziel").font(.subheadline)
                Spacer()
                Stepper(
                    "\(wasserZiel) ml",
                    value: Binding(
                        get: { wasserZiel },
                        set: { heuteEintrag?.wasserZielMl = $0 }
                    ),
                    in: 1000...4000,
                    step: 100
                )
                .fixedSize()
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Streak

    private var streakKarte: some View {
        VStack(spacing: 10) {
            HStack {
                Label("Wasser-Streak", systemImage: "flame.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Spacer()
            }

            let streak = berechneStreak()

            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("\(streak)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(streak > 0 ? .orange : .secondary)
                    Text(streak == 1 ? "Tag in Folge" : "Tage in Folge")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 6) {
                    streakInfo(symbol: "drop.fill", farbe: .teal,
                               text: "Getrunken: \(heuteEintrag?.wasserMl ?? 0) ml")
                    streakInfo(symbol: "checkmark.circle.fill", farbe: .green,
                               text: "Ziel: \(heuteEintrag?.wasserZielMl ?? 2000) ml")
                    if streak >= 7 {
                        streakInfo(symbol: "star.fill", farbe: .yellow, text: "Wochenziel erreicht!")
                    } else if streak >= 3 {
                        streakInfo(symbol: "bolt.fill", farbe: .orange, text: "Super, weiter so!")
                    } else {
                        streakInfo(symbol: "drop.circle", farbe: .teal, text: "Trinke täglich genug")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func streakInfo(symbol: String, farbe: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).foregroundStyle(farbe).font(.caption)
            Text(text).font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private func stelleHeuteEintragSicher() {
        let start = Calendar.current.startOfDay(for: Date())
        if let existing = eintraege.first(where: { Calendar.current.isDate($0.datum, inSameDayAs: start) }) {
            heuteEintrag = existing
        } else {
            let neu = TagesWohlbefinden(datum: start)
            modelContext.insert(neu)
            heuteEintrag = neu
        }
    }

    private func trinken(ml: Int) {
        heuteEintrag?.wasserMl += ml
    }

    private func berechneStreak() -> Int {
        let kal = Calendar.current
        let sortiert = eintraege.sorted { $0.datum > $1.datum }
        var streak = 0
        var erwartet = kal.startOfDay(for: Date())
        for eintrag in sortiert {
            let tag = kal.startOfDay(for: eintrag.datum)
            guard kal.isDate(tag, inSameDayAs: erwartet) else { break }
            if eintrag.wasserMl >= eintrag.wasserZielMl {
                streak += 1
            } else if !kal.isDateInToday(tag) {
                break
            }
            guard let vorherig = kal.date(byAdding: .day, value: -1, to: erwartet) else { break }
            erwartet = vorherig
        }
        return streak
    }
}
