import SwiftUI
import SwiftData

struct RheumaSchnellForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var onGespeichert: (() -> Void)? = nil

    @State private var schritt = 0
    @State private var vorwaerts = true
    @State private var datum = Date()
    @State private var istSchub = false
    @State private var schmerzstaerke = 5
    @State private var gelenkStatus = ""
    @State private var morgensteifigkeit = 0
    @State private var fatigue = 0
    @State private var schlafStunden: Double = 0
    @State private var stimmung = 3
    @State private var stressLevel = 3
    @State private var notizen = ""
    @State private var zeigeErfolg = false
    @State private var wetterTemperatur: Double? = nil
    @State private var wetterCode: Int? = nil
    @State private var wetterWind: Double? = nil

    private let wetter = WetterService.shared
    private let maxSchritt = 2
    private let schrittNamen = ["Allgemein", "Gelenke", "Wohlbefinden"]
    private let progressTint: Color = .teal
    private let pflichtSchritte: Set<Int> = [0]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressBar
                    .padding(.horizontal)
                    .padding(.top, 10)

                schrittInhalt
                    .frame(maxHeight: .infinity)
                    .id(schritt)
                    .transition(.asymmetric(
                        insertion: .move(edge: vorwaerts ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: vorwaerts ? .leading : .trailing).combined(with: .opacity)
                    ))

                navigationsLeiste
            }
            .navigationTitle("Rheuma & Gelenke")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
        .onAppear { laden() }
        .overlay {
            if zeigeErfolg {
                ZStack {
                    Color.black.opacity(0.25).ignoresSafeArea()
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 72, height: 72)
                                .shadow(color: .green.opacity(0.4), radius: 16, y: 4)
                            Image(systemName: "checkmark")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .scaleEffect(zeigeErfolg ? 1 : 0.3)
                        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: zeigeErfolg)
                        Text("Gespeichert")
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                            .opacity(zeigeErfolg ? 1 : 0)
                            .animation(.easeIn.delay(0.1), value: zeigeErfolg)
                    }
                }
                .transition(.opacity)
            }
        }
    }

    // MARK: - Progress bar

    private var progressBar: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 3)
                    Capsule()
                        .fill(progressTint)
                        .frame(
                            width: geo.size.width * (maxSchritt > 0 ? CGFloat(schritt) / CGFloat(maxSchritt) : 0),
                            height: 3
                        )
                        .animation(.spring(response: 0.4), value: schritt)
                }
            }
            .frame(height: 3)

            HStack {
                Text("Schritt \(schritt + 1) von \(maxSchritt + 1)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(schritt < schrittNamen.count ? schrittNamen[schritt] : "")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Step content

    @ViewBuilder
    private var schrittInhalt: some View {
        switch schritt {
        case 0:
            ScrollView {
                allgemeinSchritt
                    .padding(.vertical, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
        case 1:
            GelenkStepView(gelenkStatus: $gelenkStatus)
                .background(Color(.systemGroupedBackground))
        default:
            ScrollView {
                WohlbefindenStepView(
                    stimmung: $stimmung,
                    schlafStunden: $schlafStunden,
                    stressLevel: $stressLevel,
                    notizen: $notizen,
                    fatigue: $fatigue
                )
                .padding(.vertical, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
        }
    }

    // MARK: - Schritt 0: Allgemein

    private var allgemeinSchritt: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Image(systemName: "cross.case.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.teal)
                Text("Wie heute?")
                    .font(.title2.bold())
            }
            .padding(.top, 8)

            karte {
                Toggle(isOn: $istSchub) {
                    HStack(spacing: 10) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Schub / Flare")
                                .font(.headline)
                            Text("Akute Verschlechterung")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .tint(.red)
            }

            karte {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Schmerzstärke").font(.headline)
                        Spacer()
                        Text("\(schmerzstaerke)/10")
                            .font(.title3.bold())
                            .foregroundStyle(schmerzFarbe)
                            .animation(.easeInOut(duration: 0.15), value: schmerzstaerke)
                    }
                    Slider(
                        value: Binding(get: { Double(schmerzstaerke) }, set: { schmerzstaerke = Int($0) }),
                        in: 0...10, step: 1
                    )
                    .tint(schmerzFarbe)
                    HStack {
                        Text("Kein Schmerz").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text(schmerzLabel).font(.caption.bold()).foregroundStyle(schmerzFarbe)
                            .animation(.easeInOut(duration: 0.15), value: schmerzLabel)
                        Spacer()
                        Text("Extrem").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            karte {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Morgensteifigkeit").font(.headline)
                    HStack(spacing: 8) {
                        ForEach([0, 15, 30, 60, 90], id: \.self) { min in
                            Button {
                                morgensteifigkeit = min
                            } label: {
                                Text(min == 0 ? "–" : min < 90 ? "\(min)'" : "90'+")
                                    .font(.subheadline.bold())
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        morgensteifigkeit == min
                                            ? Color.teal
                                            : Color(.tertiarySystemBackground)
                                    )
                                    .foregroundStyle(morgensteifigkeit == min ? .white : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if morgensteifigkeit > 0 {
                        Text(morgensteifigkeit < 90
                             ? "Dauer: \(morgensteifigkeit) Minuten"
                             : "Dauer: über 90 Minuten")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            karte {
                VStack(alignment: .leading, spacing: 10) {
                    DatePicker("Datum & Uhrzeit", selection: $datum, displayedComponents: [.date, .hourAndMinute])
                    if let snap = wetterAnzeige {
                        Divider()
                        HStack(spacing: 6) {
                            Image(systemName: snap.symbol)
                                .foregroundStyle(.yellow)
                            Text(String(format: "%.0f°C", snap.temperatur))
                                .font(.caption.bold())
                            if !snap.luftdruckText.isEmpty {
                                Text(snap.luftdruckText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    // MARK: - Navigation bar

    private var navigationsLeiste: some View {
        HStack(spacing: 12) {
            if schritt > 0 {
                Button {
                    vorwaerts = false
                    withAnimation(.easeInOut(duration: 0.25)) { schritt -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 40, height: 40)
                        .background(Color(.secondarySystemBackground), in: Circle())
                }
                .buttonStyle(.plain)
            } else {
                Spacer().frame(width: 40)
            }

            Spacer()

            if !pflichtSchritte.contains(schritt) && schritt < maxSchritt {
                Button {
                    vorwaerts = true
                    withAnimation(.easeInOut(duration: 0.25)) { schritt += 1 }
                } label: {
                    Text("Überspringen")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if schritt < maxSchritt {
                Button {
                    vorwaerts = true
                    withAnimation(.easeInOut(duration: 0.25)) { schritt += 1 }
                } label: {
                    Text("Weiter ›")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(progressTint, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            } else {
                Button { speichern() } label: {
                    Text("✓ Speichern")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(Color.green, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(.bar)
    }

    // MARK: - Card helper

    @ViewBuilder
    private func karte<C: View>(@ViewBuilder content: () -> C) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Computed helpers

    private var schmerzFarbe: Color {
        schmerzstaerke <= 3 ? .green : schmerzstaerke <= 6 ? .orange : .red
    }

    private var schmerzLabel: String {
        switch schmerzstaerke {
        case 0:    return "Kein Schmerz"
        case 1...3: return "Leicht"
        case 4...6: return "Mittel"
        case 7...9: return "Stark"
        default:   return "Unerträglich"
        }
    }

    private var wetterAnzeige: WetterSnapshot? {
        if let temp = wetterTemperatur, let code = wetterCode {
            return WetterSnapshot(temperatur: temp, code: code, windgeschwindigkeit: wetterWind ?? 0)
        }
        return wetter.aktuell
    }

    // MARK: - Load / Save

    private func laden() {
        if let snap = wetter.aktuell {
            wetterTemperatur = snap.temperatur
            wetterCode = snap.code
            wetterWind = snap.windgeschwindigkeit
        } else {
            wetter.laden()
        }
    }

    private func speichern() {
        let neu = PainEntry(
            datum: datum,
            schmerzstaerke: schmerzstaerke,
            koerperstelle: "Rheuma",
            notizen: notizen,
            stimmung: stimmung,
            schlafStunden: schlafStunden,
            stressLevel: stressLevel,
            morgensteifigkeit: morgensteifigkeit,
            istSchub: istSchub,
            fatigue: fatigue,
            gelenkStatus: gelenkStatus
        )
        modelContext.insert(neu)
#if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
#endif
        zeigeErfolg = true
        onGespeichert?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { dismiss() }
    }
}
