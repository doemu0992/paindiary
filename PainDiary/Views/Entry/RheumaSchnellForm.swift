import SwiftUI
import SwiftData

struct RheumaSchnellForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var onGespeichert: (() -> Void)? = nil

    @State private var datum = Date()
    @State private var istSchub = false
    @State private var gelenkStatus = ""
    @State private var morgensteifigkeit = 0
    @State private var fatigue = 0
    @State private var stimmung = 3
    @State private var notizen = ""

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Heute
                Section("Heute") {
                    DatePicker("Datum & Uhrzeit", selection: $datum)

                    Toggle(isOn: $istSchub) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Schub / Flare")
                                Text("Akute Verschlechterung / Krankheitsschub")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "flame.fill").foregroundStyle(.red)
                        }
                    }
                }

                // MARK: Morgensteifigkeit
                Section {
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
                } header: {
                    Text("Morgensteifigkeit")
                } footer: {
                    if morgensteifigkeit > 0 {
                        Text(morgensteifigkeit < 90
                             ? "Dauer: \(morgensteifigkeit) Minuten"
                             : "Dauer: über 90 Minuten")
                    }
                }

                // MARK: Fatigue
                Section("Erschöpfung / Fatigue") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(fatigue == 0 ? "Keine Erschöpfung" : "Fatigue: \(fatigue) / 10")
                            Spacer()
                            if fatigue > 0 {
                                Text(fatigueLabel)
                                    .font(.caption.bold())
                                    .foregroundStyle(fatigueFarbe)
                            }
                        }
                        Slider(
                            value: Binding(get: { Double(fatigue) }, set: { fatigue = Int($0) }),
                            in: 0...10, step: 1
                        ).tint(fatigueFarbe)
                    }
                }

                // MARK: Gelenke
                Section("Betroffene Gelenke") {
                    GelenkStepView(gelenkStatus: $gelenkStatus)
                }

                // MARK: Stimmung
                Section("Stimmung") {
                    HStack(spacing: 12) {
                        ForEach(1...5, id: \.self) { wert in
                            Button { stimmung = wert } label: {
                                Image(systemName: stimmung >= wert ? "heart.fill" : "heart")
                                    .foregroundStyle(stimmung >= wert ? .pink : .secondary)
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                        Text(stimmungLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // MARK: Notizen
                Section("Notizen") {
                    TextEditor(text: $notizen).frame(minHeight: 60)
                }
            }
            .navigationTitle("Rheuma & Gelenke")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { speichern() }
                }
            }
        }
    }

    // MARK: - Helpers

    private var fatigueLabel: String {
        switch fatigue {
        case 1...3: return "Leicht"
        case 4...6: return "Mittel"
        case 7...8: return "Stark"
        default:    return "Extrem"
        }
    }

    private var fatigueFarbe: Color {
        switch fatigue {
        case 0:     return .secondary
        case 1...3: return .green
        case 4...6: return .yellow
        case 7...8: return .orange
        default:    return .red
        }
    }

    private var stimmungLabel: String {
        ["", "Sehr schlecht", "Schlecht", "Neutral", "Gut", "Sehr gut"][stimmung]
    }

    // MARK: - Save

    private func speichern() {
        let neu = PainEntry(
            datum: datum,
            schmerzstaerke: 0,
            koerperstelle: "Rheuma",
            morgensteifigkeit: morgensteifigkeit,
            istSchub: istSchub,
            fatigue: fatigue,
            gelenkStatus: gelenkStatus,
            stimmung: stimmung,
            notizen: notizen
        )
        modelContext.insert(neu)
        onGespeichert?()
        dismiss()
    }
}
