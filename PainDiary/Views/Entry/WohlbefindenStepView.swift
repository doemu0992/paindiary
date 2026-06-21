import SwiftUI

struct WohlbefindenStepView: View {
    @Binding var stimmung: Int
    @Binding var schlafStunden: Double
    @Binding var stressLevel: Int
    @Binding var notizen: String
    var morgensteifigkeit: Binding<Int>? = nil
    var fatigue: Binding<Int>? = nil
    var energielevel: Binding<Int>? = nil
    var healthSchlafVorschlag: Double? = nil

    var body: some View {
        VStack(spacing: 20) {
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
                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { stufe in
                            let aktiv = stimmung == stufe
                            let farbe = stimmungFarbe(stufe)
                            Button { stimmung = stufe } label: {
                                VStack(spacing: 5) {
                                    Image(systemName: "heart.fill")
                                        .font(.title2)
                                        .foregroundStyle(aktiv ? farbe : .secondary.opacity(0.3))
                                    Text(stimmungLabel(stufe))
                                        .font(.caption2)
                                        .foregroundStyle(aktiv ? .primary : .secondary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    aktiv ? farbe.opacity(0.12) : Color.secondary.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 10)
                                )
                                .animation(.easeInOut(duration: 0.15), value: aktiv)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if stimmung > 0 {
                        Text(stimmungLabel(stimmung))
                            .font(.caption).foregroundStyle(stimmungFarbe(stimmung))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.15), value: stimmung)
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))

                // Stresslevel
                VStack(alignment: .leading, spacing: 10) {
                    Text("Stresslevel")
                        .font(.headline)
                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { stufe in
                            let aktiv = stressLevel == stufe
                            let farbe = stressFarbe(stufe)
                            Button { stressLevel = stufe } label: {
                                VStack(spacing: 6) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(aktiv ? farbe : farbe.opacity(0.2))
                                        .frame(width: 6, height: CGFloat(stufe) * 5 + 8)
                                    Text(stressBezeichnung(stufe))
                                        .font(.caption2)
                                        .foregroundStyle(aktiv ? .primary : .secondary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    aktiv ? farbe.opacity(0.12) : Color.secondary.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 10)
                                )
                                .animation(.easeInOut(duration: 0.15), value: aktiv)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if stressLevel > 0 {
                        Text(stressBezeichnung(stressLevel))
                            .font(.caption).foregroundStyle(stressFarbe(stressLevel))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.15), value: stressLevel)
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

            if let eBinding = energielevel {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Energie & Vitalität")
                        .font(.headline)
                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { stufe in
                            let aktiv = eBinding.wrappedValue == stufe
                            Button { eBinding.wrappedValue = stufe } label: {
                                VStack(spacing: 5) {
                                    Image(systemName: energieSymbol(stufe))
                                        .font(.title2)
                                        .foregroundStyle(aktiv ? energieFarbe(stufe) : .secondary.opacity(0.35))
                                    Text(energieLabel(stufe))
                                        .font(.caption2)
                                        .foregroundStyle(aktiv ? .primary : .secondary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    aktiv ? energieFarbe(stufe).opacity(0.12) : Color.secondary.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 10)
                                )
                                .animation(.easeInOut(duration: 0.15), value: aktiv)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if eBinding.wrappedValue > 0 {
                        Text(energieLabel(eBinding.wrappedValue))
                            .font(.caption).foregroundStyle(energieFarbe(eBinding.wrappedValue))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.15), value: eBinding.wrappedValue)
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
        [.red, .orange, .yellow, .green, .teal][max(0, min(i - 1, 4))]
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
        [.green, .mint, .yellow, .orange, .red][max(0, min(level - 1, 4))]
    }

    private func energieSymbol(_ stufe: Int) -> String {
        switch stufe {
        case 1: return "battery.0"
        case 2: return "battery.25"
        case 3: return "battery.50"
        case 4: return "battery.75"
        default: return "battery.100"
        }
    }

    private func energieLabel(_ stufe: Int) -> String {
        switch stufe {
        case 1: return "Erschöpft"
        case 2: return "Müde"
        case 3: return "Okay"
        case 4: return "Gut"
        default: return "Top"
        }
    }

    private func energieFarbe(_ stufe: Int) -> Color {
        switch stufe {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .mint
        default: return .green
        }
    }
}
