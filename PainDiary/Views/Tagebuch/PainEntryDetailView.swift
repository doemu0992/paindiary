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
                    HStack(spacing: 3) {
                        ForEach(1...5, id: \.self) { i in
                            Image(systemName: i <= eintrag.stimmung ? "heart.fill" : "heart")
                                .font(.system(size: 14))
                                .foregroundStyle(i <= eintrag.stimmung ? .red : .secondary.opacity(0.3))
                        }
                    }
                }
                HStack {
                    Text("Stresslevel")
                    Spacer()
                    HStack(spacing: 3) {
                        ForEach(1...5, id: \.self) { i in
                            Image(systemName: i <= eintrag.stressLevel ? "bolt.fill" : "bolt")
                                .font(.system(size: 14))
                                .foregroundStyle(i <= eintrag.stressLevel ? .orange : .secondary.opacity(0.3))
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
}
