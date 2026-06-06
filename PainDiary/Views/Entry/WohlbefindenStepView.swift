import SwiftUI

struct WohlbefindenStepView: View {
    @Binding var stimmung: Int
    @Binding var schlafStunden: Double
    @Binding var stressLevel: Int
    var healthSchlafVorschlag: Double? = nil

    var body: some View {
        VStack(spacing: 24) {
            Text("Wie geht es dir?")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

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
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

                // Stresslevel
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Stresslevel")
                            .font(.headline)
                        Spacer()
                        Text(stressBezeichnung(stressLevel))
                            .font(.subheadline.bold())
                            .foregroundStyle(stressFarbe(stressLevel))
                    }
                    HStack(spacing: 6) {
                        ForEach(1...5, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 6)
                                .fill(i <= stressLevel ? stressFarbe(stressLevel) : Color.secondary.opacity(0.2))
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                                .overlay(
                                    Text("\(i)").font(.caption.bold())
                                        .foregroundStyle(i <= stressLevel ? .white : .secondary)
                                )
                                .onTapGesture { stressLevel = i }
                                .animation(.easeInOut(duration: 0.15), value: stressLevel)
                        }
                    }
                    HStack {
                        Text("Entspannt").font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Text("Extrem").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

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
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding(.horizontal)
    }

    private func stimmungLabel(_ i: Int) -> String {
        switch i {
        case 1: return "Schlecht"
        case 2: return "Mässig"
        case 3: return "Okay"
        case 4: return "Gut"
        case 5: return "Super"
        default: return ""
        }
    }

    private func stimmungFarbe(_ i: Int) -> Color {
        switch i {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .mint
        case 5: return .green
        default: return .secondary
        }
    }

    private func stressBezeichnung(_ level: Int) -> String {
        switch level {
        case 1: return "Entspannt"
        case 2: return "Leicht"
        case 3: return "Mässig"
        case 4: return "Hoch"
        case 5: return "Extrem"
        default: return "Mässig"
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
