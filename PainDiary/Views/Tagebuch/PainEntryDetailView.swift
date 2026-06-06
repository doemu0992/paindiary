import SwiftUI

struct PainEntryDetailView: View {
    let eintrag: PainEntry
    @State private var bearbeiten = false

    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        SchmerzBadge(staerke: eintrag.schmerzstaerke)
                            .scaleEffect(1.5)
                            .padding(.bottom, 4)
                        Text("Schmerzstärke \(eintrag.schmerzstaerke)/10")
                            .font(.headline)
                        Text(eintrag.datum, style: .date)
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text(eintrag.datum, style: .time)
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 12)
            }
            .listRowBackground(Color.clear)

            if !eintrag.koerperstelle.isEmpty || !eintrag.schmerzart.isEmpty {
                Section("Schmerz") {
                    if !eintrag.koerperstelle.isEmpty {
                        LabeledContent("Körperstelle", value: eintrag.koerperstelle)
                    }
                    if !eintrag.schmerzart.isEmpty {
                        LabeledContent("Schmerzart", value: eintrag.schmerzart)
                    }
                    if eintrag.dauerMinuten > 0 {
                        LabeledContent("Dauer", value: formatierteDauer(eintrag.dauerMinuten))
                    }
                }
            }

            if !eintrag.ausloeser.isEmpty {
                Section("Auslöser") { Text(eintrag.ausloeser) }
            }

            if !eintrag.begleiterscheinungen.isEmpty {
                Section("Begleiterscheinungen") { Text(eintrag.begleiterscheinungen) }
            }

            if !eintrag.massnahmen.isEmpty {
                Section("Massnahmen") { Text(eintrag.massnahmen) }
            }

            Section("Wohlbefinden") {
                HStack {
                    Text("Stimmung")
                    Spacer()
                    Text(stimmungLabel(eintrag.stimmung))
                        .font(.subheadline).foregroundStyle(stimmungFarbe(eintrag.stimmung))
                    HStack(spacing: 3) {
                        ForEach(1...5, id: \.self) { i in
                            Image(systemName: i <= eintrag.stimmung ? "heart.fill" : "heart")
                                .font(.system(size: 13))
                                .foregroundStyle(i <= eintrag.stimmung ? stimmungFarbe(eintrag.stimmung) : .secondary.opacity(0.3))
                        }
                    }
                }
                HStack {
                    Text("Stresslevel")
                    Spacer()
                    Text(stressLabel(eintrag.stressLevel))
                        .font(.subheadline).foregroundStyle(stressFarbe(eintrag.stressLevel))
                    HStack(spacing: 3) {
                        ForEach(1...5, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(i <= eintrag.stressLevel ? stressFarbe(eintrag.stressLevel) : Color.secondary.opacity(0.2))
                                .frame(width: 10, height: 14)
                        }
                    }
                }
                if eintrag.schlafStunden > 0 {
                    LabeledContent("Schlaf", value: String(format: "%.1f Stunden", eintrag.schlafStunden))
                }
            }

            if let code = eintrag.wetterCode, let temp = eintrag.wetterTemperatur {
                Section("Wetter") {
                    HStack {
                        Image(systemName: WetterSnapshot.symbolFuerCode(code))
                            .foregroundStyle(.yellow)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(WetterSnapshot.beschreibungFuerCode(code))
                                .font(.subheadline)
                            Text(String(format: "%.0f°C", temp))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if let wind = eintrag.wetterWind, wind > 0 {
                            Spacer()
                            Label(String(format: "%.0f km/h", wind), systemImage: "wind")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if !eintrag.notizen.isEmpty {
                Section("Notizen") { Text(eintrag.notizen) }
            }
        }
        .navigationTitle("Eintrag")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Bearbeiten") { bearbeiten = true }
            }
        }
        .sheet(isPresented: $bearbeiten) {
            AddEntryView(eintrag: eintrag)
        }
    }

    private func formatierteDauer(_ min: Int) -> String {
        let h = min / 60; let m = min % 60
        if h == 0 { return "\(m) Min." }
        if m == 0 { return "\(h) Std." }
        return "\(h) Std. \(m) Min."
    }

    private func stimmungLabel(_ s: Int) -> String {
        switch s {
        case 1: return "Schlecht"
        case 2: return "Mässig"
        case 3: return "Okay"
        case 4: return "Gut"
        case 5: return "Super"
        default: return ""
        }
    }

    private func stimmungFarbe(_ s: Int) -> Color {
        switch s {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .mint
        case 5: return .green
        default: return .secondary
        }
    }

    private func stressLabel(_ s: Int) -> String {
        switch s {
        case 1: return "Entspannt"
        case 2: return "Leicht"
        case 3: return "Mässig"
        case 4: return "Hoch"
        case 5: return "Extrem"
        default: return ""
        }
    }

    private func stressFarbe(_ s: Int) -> Color {
        switch s {
        case 1: return .green
        case 2: return .mint
        case 3: return .yellow
        case 4: return .orange
        case 5: return .red
        default: return .secondary
        }
    }
}
