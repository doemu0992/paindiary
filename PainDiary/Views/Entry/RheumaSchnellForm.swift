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
    private let maxSchritt = 3
    private let pflichtSchritte: Set<Int> = [0, 1]

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
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.teal.opacity(0.15))
                    .frame(height: 3)
                Capsule()
                    .fill(Color.teal)
                    .frame(
                        width: geo.size.width * CGFloat(schritt + 1) / CGFloat(maxSchritt + 1),
                        height: 3
                    )
                    .animation(.easeInOut(duration: 0.3), value: schritt)
            }
        }
        .frame(height: 3)
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
            ScrollView {
                schmerzMorgenSchritt
                    .padding(.vertical, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
        case 2:
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
        VStack(spacing: 20) {
            schrittHeader(symbol: "cross.case.fill", titel: "Rheuma & Gelenke", untertitel: "Heutigen Zustand erfassen")

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

    // MARK: - Schritt 1: Schmerz & Morgensteifigkeit

    private var schmerzMorgenSchritt: some View {
        VStack(spacing: 20) {
            schrittHeader(symbol: "waveform.path.ecg", titel: "Wie stark?", untertitel: "Schmerzstärke und Morgensteifigkeit")

            karte {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Schmerzstärke").font(.headline)

                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(schmerzFarbe.opacity(0.15))
                                .frame(width: 104, height: 104)
                            Circle()
                                .strokeBorder(schmerzFarbe, lineWidth: 5)
                                .frame(width: 104, height: 104)
                            VStack(spacing: 1) {
                                Text("\(schmerzstaerke)")
                                    .font(.system(size: 44, weight: .bold, design: .rounded))
                                    .foregroundStyle(schmerzFarbe)
                                Text("/ 10")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: schmerzstaerke)
                        Spacer()
                    }

                    Text(schmerzLabel)
                        .font(.subheadline.bold())
                        .foregroundStyle(schmerzFarbe)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .animation(.easeInOut(duration: 0.2), value: schmerzLabel)

                    Slider(
                        value: Binding(get: { Double(schmerzstaerke) }, set: { schmerzstaerke = Int($0) }),
                        in: 0...10, step: 1
                    )
                    .tint(schmerzFarbe)

                    HStack {
                        Text("Kein Schmerz").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("Extremer Schmerz").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Morgensteifigkeit")
                    .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
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
                                    morgensteifigkeit == min ? Color.teal : Color(.secondarySystemGroupedBackground)
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
                        .foregroundStyle(morgensteifigkeit >= 30 ? .orange : .secondary)
                        .padding(.horizontal, 4)
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
                    Text("Zurück")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            if !pflichtSchritte.contains(schritt) && schritt < maxSchritt {
                Button {
                    vorwaerts = true
                    withAnimation(.easeInOut(duration: 0.25)) { schritt += 1 }
                } label: {
                    Text("Überspringen")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            if schritt < maxSchritt {
                Button {
                    vorwaerts = true
                    withAnimation(.easeInOut(duration: 0.25)) { schritt += 1 }
                } label: {
                    Text("Weiter ›")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.teal, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            } else {
                Button { speichern() } label: {
                    Label("Speichern", systemImage: "checkmark")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.teal, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
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

    // MARK: - schrittHeader helper

    private func schrittHeader(symbol: String, titel: String, untertitel: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 32))
                .foregroundStyle(.teal)
            Text(titel).font(.title3.bold())
            Text(untertitel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 4)
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
        let heute = Calendar.current.startOfDay(for: Date())
        let heuteDesc = FetchDescriptor<PainEntry>(
            predicate: #Predicate { $0.datum >= heute },
            sortBy: [SortDescriptor(\.datum, order: .reverse)]
        )
        if let letzterHeute = try? modelContext.fetch(heuteDesc).first {
            schlafStunden = letzterHeute.schlafStunden
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
