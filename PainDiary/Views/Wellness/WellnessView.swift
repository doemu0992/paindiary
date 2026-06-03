import SwiftUI
import SwiftData

struct WellnessView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TagesWohlbefinden.datum, order: .reverse) private var eintraege: [TagesWohlbefinden]

    @State private var healthManager = HealthKitManager.shared
    @State private var schlafStunden: Double? = nil
    @State private var schritte: Int? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    wasserTrackerKarte
                    healthKarte
                    streakKarte
                }
                .padding()
                .padding(.bottom, 30)
            }
            .navigationTitle("Wohlbefinden")
        }
        .onAppear { ladeHealthDaten() }
    }

    // MARK: - Wasser-Tracker

    private var wasserTrackerKarte: some View {
        VStack(spacing: 16) {
            // Section header
            HStack {
                Label("Wasser-Tracker", systemImage: "drop.fill")
                    .font(.headline)
                    .foregroundStyle(.teal)
                Spacer()
            }

            // Circular progress ring
            ZStack {
                // Track
                Circle()
                    .stroke(Color.teal.opacity(0.15), lineWidth: 14)

                // Progress ring
                Circle()
                    .trim(from: 0, to: heute.fortschritt)
                    .stroke(
                        Color.teal,
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5), value: heute.wasserMl)

                // Center text
                VStack(spacing: 4) {
                    Text("\(heute.wasserMl)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.teal)
                    Text("von \(heute.wasserZielMl) ml")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.0f%%", heute.fortschritt * 100))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 160, height: 160)
            .padding(.vertical, 8)

            // Quick-add buttons
            HStack(spacing: 10) {
                ForEach([150, 200, 330, 500], id: \.self) { menge in
                    Button {
                        trinken(ml: menge)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "drop.fill")
                                .font(.caption)
                                .foregroundStyle(.teal)
                            Text("+\(menge)")
                                .font(.caption.bold())
                            Text("ml")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.teal.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Undo button
            if heute.wasserMl > 0 {
                Button {
                    heute.wasserMl = max(0, heute.wasserMl - 150)
                } label: {
                    Label("Rückgängig", systemImage: "arrow.uturn.backward")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Goal stepper
            HStack {
                Text("Tagesziel")
                    .font(.subheadline)
                Spacer()
                Stepper(
                    "\(heute.wasserZielMl) ml",
                    value: Binding(
                        get: { heute.wasserZielMl },
                        set: { heute.wasserZielMl = $0 }
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

    // MARK: - Apple Health

    private var healthKarte: some View {
        VStack(spacing: 14) {
            HStack {
                Label("Apple Health", systemImage: "heart.fill")
                    .font(.headline)
                    .foregroundStyle(.red)
                Spacer()
                Button(action: ladeHealthDaten) {
                    Label("Daten laden", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 0) {
                // Sleep
                VStack(spacing: 6) {
                    Image(systemName: "bed.double.fill")
                        .font(.title2)
                        .foregroundStyle(.indigo)
                    if let std = schlafStunden {
                        Text(String(format: "%.1f Std.", std))
                            .font(.title3.bold())
                    } else {
                        Text("–")
                            .font(.title3.bold())
                            .foregroundStyle(.secondary)
                    }
                    Text("Schlaf")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 56)

                // Steps
                VStack(spacing: 6) {
                    Image(systemName: "figure.walk")
                        .font(.title2)
                        .foregroundStyle(.green)
                    if let s = schritte {
                        Text(schrittText(s))
                            .font(.title3.bold())
                    } else {
                        Text("–")
                            .font(.title3.bold())
                            .foregroundStyle(.secondary)
                    }
                    Text("Schritte")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 4)
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
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 6) {
                    streakInfo(symbol: "checkmark.circle.fill", farbe: .green,
                               text: "Ziel heute: \(heute.wasserZielMl) ml")
                    streakInfo(symbol: "drop.fill", farbe: .teal,
                               text: "Getrunken: \(heute.wasserMl) ml")
                    if streak >= 7 {
                        streakInfo(symbol: "star.fill", farbe: .yellow, text: "Wochenziel erreicht!")
                    } else if streak >= 3 {
                        streakInfo(symbol: "bolt.fill", farbe: .orange, text: "Super, weiter so!")
                    } else {
                        streakInfo(symbol: "drop.circle", farbe: .teal, text: "Trinke genug, um Streak zu starten")
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

    // MARK: - Helper functions

    private var heute: TagesWohlbefinden {
        let start = Calendar.current.startOfDay(for: Date())
        if let existing = eintraege.first(where: { Calendar.current.isDate($0.datum, inSameDayAs: start) }) {
            return existing
        }
        let neu = TagesWohlbefinden(datum: start)
        modelContext.insert(neu)
        return neu
    }

    private func trinken(ml: Int) {
        heute.wasserMl += ml
    }

    private func ladeHealthDaten() {
        Task {
            schlafStunden = await healthManager.schlafStundenLetztteNacht()
            schritte = await healthManager.schritteDiesemTag()
        }
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
            } else if kal.isDateInToday(tag) {
                // heute noch nicht geschafft – kein Streak-Abbruch, nur nicht zählen
            } else {
                break
            }
            guard let vorherig = kal.date(byAdding: .day, value: -1, to: erwartet) else { break }
            erwartet = vorherig
        }
        return streak
    }

    private func schrittText(_ schritte: Int) -> String {
        if schritte >= 1000 {
            let tausend = Double(schritte) / 1000.0
            return String(format: "%.1f Tsd.", tausend)
        }
        return "\(schritte)"
    }
}
