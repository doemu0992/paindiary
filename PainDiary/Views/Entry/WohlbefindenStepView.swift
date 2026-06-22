import SwiftUI

struct WohlbefindenStepView: View {
    @Binding var stimmung: Int
    @Binding var schlafStunden: Double
    @Binding var stressLevel: Int
    @Binding var notizen: String
    var morgensteifigkeit: Binding<Int>? = nil
    var fatigue: Binding<Int>? = nil
    var healthSchlafVorschlag: Double? = nil

    var body: some View {
        VStack(spacing: 20) {
            // Header — matches schrittHeader style
            VStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.indigo)
                Text("Wie geht es dir?")
                    .font(.title3.bold())
                Text("Stimmung, Schlaf und Wohlbefinden")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 20) {
                // Stimmung
                VStack(alignment: .leading, spacing: 10) {
                    Text("Stimmung")
                        .font(.headline)
                    HStack(spacing: 12) {
                        ForEach(1...5, id: \.self) { i in
                            VStack(spacing: 4) {
                                Image(systemName: i <= stimmung ? "heart.fill" : "heart")
                                    .font(.title)
                                    .foregroundStyle(i <= stimmung ? stimmungFarbe(i) : .secondary.opacity(0.3))
                                    .scaleEffect(i == stimmung ? 1.2 : 1.0)
                                    .animation(.spring(response: 0.2), value: stimmung)
                                Text(stimmungLabel(i))
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .onTapGesture { stimmung = i }
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))

                // Stresslevel
                VStack(alignment: .leading, spacing: 10) {
                    Text("Stresslevel")
                        .font(.headline)
                    HStack(spacing: 6) {
                        ForEach(1...5, id: \.self) { i in
                            let farbe = stressFarbe(i)
                            let aktiv = stressLevel == i
                            let balkenHoehe: CGFloat = [28, 36, 44, 52, 60][i - 1]
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(aktiv ? farbe : Color.secondary.opacity(0.15))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: balkenHoehe)
                                    .animation(.easeInOut(duration: 0.15), value: stressLevel)
                                Text(stressBezeichnung(i))
                                    .font(.system(size: 8))
                                    .foregroundStyle(aktiv ? farbe : .secondary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity)
                            .onTapGesture { stressLevel = i }
                        }
                    }
                    .frame(height: 84)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))

                // Schlaf
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Schlaf letzte Nacht")
                            .font(.headline)
                        Spacer()
                        Text(String(format: "%.1f Std.", schlafStunden))
                            .font(.subheadline.bold())
                            .foregroundStyle(.indigo)
                    }
                    if let hs = healthSchlafVorschlag {
                        Button {
                            schlafStunden = min(hs, 12)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "heart.fill").foregroundStyle(.red)
                                Text(String(format: "Apple Health: %.1f Std. übernehmen", hs))
                                    .font(.caption)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.1), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    Slider(value: $schlafStunden, in: 0...12, step: 0.5)
                        .tint(.indigo)
                    HStack {
                        Text("0 Std.").font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Text("12 Std.").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            }

            if let fBinding = fatigue {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Erschöpfung / Fatigue")
                            .font(.headline)
                        Spacer()
                        Text(fBinding.wrappedValue == 0 ? "Nicht erfasst" : "\(fBinding.wrappedValue)/10")
                            .font(.subheadline.bold())
                            .foregroundStyle(fBinding.wrappedValue == 0 ? Color.secondary : fatigueFarbe(fBinding.wrappedValue))
                    }
                    Slider(value: Binding(
                        get: { Double(fBinding.wrappedValue) },
                        set: { fBinding.wrappedValue = Int($0) }
                    ), in: 0...10, step: 1)
                    .tint(fatigueFarbe(fBinding.wrappedValue))
                    HStack {
                        Text("Keine").font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Text("Extrem").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            }

            if let mgBinding = morgensteifigkeit {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Morgensteifigkeit")
                            .font(.headline)
                        Spacer()
                        Text(mgBinding.wrappedValue == 0 ? "Keine" : "\(mgBinding.wrappedValue) Min")
                            .font(.subheadline.bold())
                            .foregroundStyle(mgBinding.wrappedValue == 0 ? Color.secondary : Color.orange)
                    }
                    HStack(spacing: 6) {
                        ForEach([(0, "–"), (15, "15'"), (30, "30'"), (60, "60'"), (90, "90'+'")], id: \.0) { wert, label in
                            Button {
                                mgBinding.wrappedValue = wert
                            } label: {
                                Text(label)
                                    .font(.caption.bold())
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        mgBinding.wrappedValue == wert
                                            ? Color.orange.opacity(0.2)
                                            : Color.secondary.opacity(0.12),
                                        in: RoundedRectangle(cornerRadius: 8)
                                    )
                                    .foregroundStyle(mgBinding.wrappedValue == wert ? .orange : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Text("Wie lange dauerte die Steifigkeit nach dem Aufstehen?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Notizen")
                    .font(.headline)
                ZStack(alignment: .topLeading) {
                    if notizen.isEmpty {
                        Text("Weitere Beobachtungen, Bemerkungen…")
                            .foregroundStyle(.tertiary)
                            .font(.subheadline)
                            .padding(.top, 8).padding(.leading, 4)
                    }
                    TextEditor(text: $notizen)
                        .frame(minHeight: 80)
                        .font(.subheadline)
                        .scrollContentBackground(.hidden)
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))

            Text("Optional – du kannst diesen Schritt überspringen.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
    }

    private func fatigueFarbe(_ wert: Int) -> Color {
        switch wert {
        case 0:    return .secondary
        case 1...3: return .green
        case 4...6: return .orange
        default:   return .red
        }
    }

    private func stimmungLabel(_ i: Int) -> String {
        switch i {
        case 1: return "Schlecht"
        case 2: return "Mässig"
        case 3: return "Okay"
        case 4: return "Gut"
        case 5: return "Sehr gut"
        default: return ""
        }
    }

    private func stimmungFarbe(_ i: Int) -> Color {
        switch i {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .green
        case 5: return .teal
        default: return .secondary
        }
    }

    private func stressBezeichnung(_ level: Int) -> String {
        switch level {
        case 1: return "Entspannt"
        case 2: return "Ruhig"
        case 3: return "Mittel"
        case 4: return "Gestresst"
        case 5: return "Sehr hoch"
        default: return "Mittel"
        }
    }

    private func stressFarbe(_ level: Int) -> Color {
        switch level {
        case 1: return .green
        case 2: return .mint
        case 3: return .yellow
        case 4: return .orange
        case 5: return .red
        default: return .yellow
        }
    }
}
