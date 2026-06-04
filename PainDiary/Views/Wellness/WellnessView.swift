import SwiftUI

// WellnessView nutzt UserDefaults statt SwiftData — kein @Model im Schema nötig.
struct WellnessView: View {
    @State private var wasserMl: Int = 0
    @State private var wasserZielMl: Int = 2000
    @AppStorage("wasserErinnerungAktiv") private var wasserErinnerungAktiv = false
    @AppStorage("wasserErinnerungZeit") private var wasserErinnerungZeitSek = 54000.0 // 15:00

    private let notif = NotificationManager.shared

    private var wasserErinnerungZeit: Binding<Date> {
        Binding(
            get: { Date(timeIntervalSinceReferenceDate: wasserErinnerungZeitSek) },
            set: { wasserErinnerungZeitSek = $0.timeIntervalSinceReferenceDate }
        )
    }

    private static func datumKey(_ offset: Int = 0) -> String {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let datum = Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
        return df.string(from: datum)
    }
    private static let zielKey = "wasserZielMl"
    private func wasserKey(_ offset: Int = 0) -> String { "wasserMl_\(Self.datumKey(offset))" }

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
        .onAppear { ladeWasserDaten() }
    }

    // MARK: - Wasser-Tracker

    private var wasserTrackerKarte: some View {
        let fortschritt = min(Double(wasserMl) / Double(wasserZielMl), 1.0)
        return VStack(spacing: 16) {
            HStack {
                Label("Wasser-Tracker", systemImage: "drop.fill")
                    .font(.headline).foregroundStyle(.teal)
                Spacer()
            }

            ZStack {
                Circle().stroke(Color.teal.opacity(0.15), lineWidth: 14)
                Circle()
                    .trim(from: 0, to: fortschritt)
                    .stroke(Color.teal, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5), value: wasserMl)
                VStack(spacing: 4) {
                    Text("\(wasserMl)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.teal)
                    Text("von \(wasserZielMl) ml").font(.caption).foregroundStyle(.secondary)
                    Text(String(format: "%.0f%%", fortschritt * 100))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(width: 160, height: 160)
            .padding(.vertical, 8)

            HStack(spacing: 10) {
                ForEach([150, 200, 330, 500], id: \.self) { menge in
                    Button { trinken(ml: menge) } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "drop.fill").font(.caption).foregroundStyle(.teal)
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
                    wasserMl = max(0, wasserMl - 150)
                    UserDefaults.standard.set(wasserMl, forKey: wasserKey())
                } label: {
                    Label("Rückgängig", systemImage: "arrow.uturn.backward")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            HStack {
                Text("Tagesziel").font(.subheadline)
                Spacer()
                Stepper(
                    "\(wasserZielMl) ml",
                    value: $wasserZielMl,
                    in: 1000...4000,
                    step: 100
                )
                .fixedSize()
                .onChange(of: wasserZielMl) { _, neu in
                    UserDefaults.standard.set(neu, forKey: Self.zielKey)
                }
            }

            Divider()

            Toggle(isOn: $wasserErinnerungAktiv) {
                Label("Wasser-Erinnerung", systemImage: "bell.badge")
            }
            .onChange(of: wasserErinnerungAktiv) { _, aktiv in
                if aktiv {
                    Task {
                        let granted = await notif.berechtigungAnfordern()
                        if granted {
                            let dc = Calendar.current.dateComponents([.hour, .minute], from: wasserErinnerungZeit.wrappedValue)
                            notif.planeWasserErinnerung(stunde: dc.hour ?? 15, minute: dc.minute ?? 0)
                        } else {
                            wasserErinnerungAktiv = false
                        }
                    }
                } else {
                    notif.loescheWasserErinnerung()
                }
            }

            if wasserErinnerungAktiv {
                DatePicker("Uhrzeit", selection: wasserErinnerungZeit, displayedComponents: .hourAndMinute)
                    .onChange(of: wasserErinnerungZeit.wrappedValue) { _, neue in
                        let dc = Calendar.current.dateComponents([.hour, .minute], from: neue)
                        notif.planeWasserErinnerung(stunde: dc.hour ?? 15, minute: dc.minute ?? 0)
                    }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Streak

    private var streakKarte: some View {
        let streak = berechneStreak()
        return VStack(spacing: 10) {
            HStack {
                Label("Wasser-Streak", systemImage: "flame.fill")
                    .font(.headline).foregroundStyle(.orange)
                Spacer()
            }

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
                    streakInfo(symbol: "drop.fill", farbe: .teal, text: "Getrunken: \(wasserMl) ml")
                    streakInfo(symbol: "checkmark.circle.fill", farbe: .green, text: "Ziel: \(wasserZielMl) ml")
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

    private func ladeWasserDaten() {
        let gespeichert = UserDefaults.standard.integer(forKey: wasserKey())
        wasserMl = gespeichert
        let ziel = UserDefaults.standard.integer(forKey: Self.zielKey)
        wasserZielMl = ziel > 0 ? ziel : 2000
    }

    private func trinken(ml: Int) {
        wasserMl += ml
        UserDefaults.standard.set(wasserMl, forKey: wasserKey())
    }

    private func berechneStreak() -> Int {
        let ziel = UserDefaults.standard.integer(forKey: Self.zielKey)
        let zielMl = ziel > 0 ? ziel : 2000
        var streak = 0
        for offset in 0...29 {
            let key = wasserKey(-offset)
            let ml = UserDefaults.standard.integer(forKey: key)
            if ml >= zielMl {
                streak += 1
            } else if offset > 0 {
                break
            }
        }
        return streak
    }
}
