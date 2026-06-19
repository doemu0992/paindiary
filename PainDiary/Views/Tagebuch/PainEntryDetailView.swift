import SwiftUI

struct PainEntryDetailView: View {
    let eintrag: PainEntry
    @State private var bearbeiten = false
    @State private var zeigeRheumaBearbeiten = false

    private var displayLocation: String {
        if !eintrag.koerperstelle.isEmpty { return eintrag.koerperstelle }
        if !eintrag.hautStellen.isEmpty   { return eintrag.hautStellen }
        return "Körperstelle unbekannt"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                heroKarte
                if !eintrag.koerperstelle.isEmpty || !eintrag.schmerzart.isEmpty || eintrag.dauerMinuten > 0 {
                    schmerzKarte
                }
                wohlbefindenKarte
                wetterKarte
                if !eintrag.ausloeser.isEmpty {
                    infoKarte("Auslöser", symbol: "exclamationmark.triangle.fill", farbe: .orange, text: eintrag.ausloeser)
                }
                if !eintrag.begleiterscheinungen.isEmpty {
                    infoKarte("Begleiterscheinungen", symbol: "list.bullet.medical", farbe: .purple, text: eintrag.begleiterscheinungen)
                }
                if !eintrag.massnahmen.isEmpty {
                    infoKarte("Massnahmen", symbol: "cross.case.fill", farbe: .teal, text: eintrag.massnahmen)
                }
                if !eintrag.notizen.isEmpty {
                    infoKarte("Notizen", symbol: "note.text", farbe: .indigo, text: eintrag.notizen)
                }
            }
            .padding()
        }
        .navigationTitle(displayLocation)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Bearbeiten") {
                    if eintrag.koerperstelle == "Rheuma" {
                        zeigeRheumaBearbeiten = true
                    } else {
                        bearbeiten = true
                    }
                }
            }
        }
        .sheet(isPresented: $bearbeiten) {
            AddEntryView(eintrag: eintrag)
        }
        .sheet(isPresented: $zeigeRheumaBearbeiten) {
            RheumaSchnellForm(eintrag: eintrag)
        }
    }

    // MARK: - Hero

    private var heroKarte: some View {
        let farbe = SchmerzBadge.farbe(fuer: eintrag.schmerzstaerke)
        return VStack(spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(displayLocation)
                        .font(.title3.bold())
                    HStack(spacing: 4) {
                        Text(eintrag.datum, style: .date)
                        Text("·").foregroundStyle(.secondary)
                        Text(eintrag.datum, style: .time)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    if eintrag.istSchub {
                        Label("Rheumaschub", systemImage: "flame.fill")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.red, in: Capsule())
                    }
                }
                Spacer()
                ZStack {
                    Circle()
                        .fill(farbe.opacity(0.15))
                        .frame(width: 64, height: 64)
                    Text("\(eintrag.schmerzstaerke)")
                        .font(.largeTitle.bold())
                        .foregroundStyle(farbe)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.12))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(
                            colors: [farbe.opacity(0.7), farbe],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: geo.size.width * CGFloat(eintrag.schmerzstaerke) / 10, height: 8)
                }
            }
            .frame(height: 8)

            HStack {
                Text("Schmerzstärke")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(eintrag.schmerzstaerke) / 10")
                    .font(.caption.bold()).foregroundStyle(farbe)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    // MARK: - Schmerz

    private var schmerzKarte: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Schmerz", systemImage: "waveform.path.ecg")
                .font(.headline).foregroundStyle(.red)
            Divider()
            if !eintrag.koerperstelle.isEmpty {
                zeile("Körperstelle", wert: eintrag.koerperstelle)
            }
            if !eintrag.schmerzart.isEmpty {
                zeile("Schmerzart", wert: eintrag.schmerzart)
            }
            if eintrag.dauerMinuten > 0 {
                zeile("Dauer", wert: formatierteDauer(eintrag.dauerMinuten))
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    // MARK: - Wohlbefinden

    private var wohlbefindenKarte: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Wohlbefinden", systemImage: "heart.text.square.fill")
                .font(.headline).foregroundStyle(.pink)
            Divider()

            HStack {
                Text("Stimmung").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                if eintrag.stimmung > 0 {
                    HStack(spacing: 4) {
                        Text(stimmungLabel(eintrag.stimmung))
                            .font(.subheadline.bold())
                            .foregroundStyle(stimmungFarbe(eintrag.stimmung))
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(stimmungFarbe(eintrag.stimmung))
                    }
                } else {
                    Text("–").font(.subheadline).foregroundStyle(.secondary)
                }
            }

            HStack {
                Text("Stresslevel").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                if eintrag.stressLevel > 0 {
                    HStack(spacing: 6) {
                        Text(stressLabel(eintrag.stressLevel))
                            .font(.subheadline.bold())
                            .foregroundStyle(stressFarbe(eintrag.stressLevel))
                        HStack(spacing: 3) {
                            ForEach(1...5, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(i <= eintrag.stressLevel
                                          ? stressFarbe(eintrag.stressLevel)
                                          : Color.secondary.opacity(0.2))
                                    .frame(width: 8, height: 12)
                            }
                        }
                    }
                } else {
                    Text("–").font(.subheadline).foregroundStyle(.secondary)
                }
            }

            if eintrag.schlafStunden > 0 {
                zeile("Schlaf", wert: String(format: "%.1f Stunden", eintrag.schlafStunden))
            }

            if eintrag.fatigue > 0 {
                HStack {
                    Text("Erschöpfung (Fatigue)").font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "battery.25")
                            .font(.caption)
                            .foregroundStyle(fatigueFarbe(eintrag.fatigue))
                        Text("\(eintrag.fatigue)/10")
                            .font(.subheadline.bold())
                            .foregroundStyle(fatigueFarbe(eintrag.fatigue))
                    }
                }
            }

            if eintrag.morgensteifigkeit > 0 {
                HStack {
                    Text("Morgensteifigkeit").font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "sunrise.fill")
                            .font(.caption)
                            .foregroundStyle(Color.orange)
                        Text("\(eintrag.morgensteifigkeit) Min")
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.orange)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    // MARK: - Wetter

    @ViewBuilder
    private var wetterKarte: some View {
        if let code = eintrag.wetterCode {
            VStack(alignment: .leading, spacing: 12) {
                Label("Wetter", systemImage: "cloud.sun.fill")
                    .font(.headline).foregroundStyle(.blue)
                Divider()
                HStack(spacing: 14) {
                    Image(systemName: WetterSnapshot.symbolFuerCode(code))
                        .font(.largeTitle).foregroundStyle(.yellow)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(WetterSnapshot.beschreibungFuerCode(code))
                            .font(.subheadline.bold())
                        if let temp = eintrag.wetterTemperatur {
                            Text(String(format: "%.0f°C", temp))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if let wind = eintrag.wetterWind, wind > 0 {
                        Label(String(format: "%.0f km/h", wind), systemImage: "wind")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
        }
    }

    // MARK: - Generic

    @ViewBuilder
    private func infoKarte(_ titel: String, symbol: String, farbe: Color, text: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(titel, systemImage: symbol)
                .font(.headline).foregroundStyle(farbe)
            Divider()
            Text(text)
                .font(.body)
                .foregroundStyle(.primary.opacity(0.85))
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    @ViewBuilder
    private func zeile(_ label: String, wert: String) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(wert).font(.subheadline.bold()).multilineTextAlignment(.trailing)
        }
    }

    // MARK: - Helpers

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

    private func fatigueFarbe(_ f: Int) -> Color {
        switch f {
        case 1...3: return .green
        case 4...6: return .orange
        default:    return .red
        }
    }
}
