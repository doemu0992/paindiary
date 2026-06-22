import SwiftUI

struct PainEntryDetailView: View {
    let eintrag: PainEntry
    @State private var zeigeSchmerzBearbeiten = false
    @State private var zeigeRheumaBearbeiten = false
    @State private var zeigeHautBearbeiten = false

    private var modulTyp: ModulTyp {
        if eintrag.koerperstelle == "Rheuma" { return .rheuma }
        if eintrag.istHautEintrag { return .haut }
        return .schmerz
    }

    private enum ModulTyp {
        case schmerz, rheuma, haut
        var tint: Color {
            switch self {
            case .schmerz: return .red
            case .rheuma:  return .teal
            case .haut:    return .orange
            }
        }
        var symbol: String {
            switch self {
            case .schmerz: return "waveform.path.ecg"
            case .rheuma:  return "figure.arms.open"
            case .haut:    return "bandage.fill"
            }
        }
        var label: String {
            switch self {
            case .schmerz: return "Schmerz"
            case .rheuma:  return "Rheuma"
            case .haut:    return "Haut"
            }
        }
    }

    private var tint: Color { modulTyp.tint }

    private var displayTitle: String {
        switch modulTyp {
        case .rheuma:
            return "Rheuma & Gelenke"
        case .haut:
            let stellen = eintrag.hautStellen.components(separatedBy: ", ").filter { !$0.isEmpty }
            return stellen.isEmpty ? "Hautveränderung" : stellen.prefix(2).joined(separator: ", ")
        case .schmerz:
            return eintrag.koerperstelle.isEmpty ? "Schmerzeintrag" : eintrag.koerperstelle
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                heroKarte

                switch modulTyp {
                case .rheuma:
                    rheumaInhalt
                case .haut:
                    hautInhalt
                case .schmerz:
                    schmerzInhalt
                }

                wohlbefindenKarte
                wetterKarte

                if !eintrag.notizen.isEmpty {
                    infoKarte("Notizen", symbol: "note.text", farbe: tint, text: eintrag.notizen)
                }
            }
            .padding()
        }
        .navigationTitle(displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Bearbeiten") {
                    switch modulTyp {
                    case .rheuma:  zeigeRheumaBearbeiten = true
                    case .haut:    zeigeHautBearbeiten = true
                    case .schmerz: zeigeSchmerzBearbeiten = true
                    }
                }
            }
        }
        .sheet(isPresented: $zeigeSchmerzBearbeiten) { SchmerzForm(eintrag: eintrag) }
        .sheet(isPresented: $zeigeRheumaBearbeiten) { RheumaSchnellForm(eintrag: eintrag) }
        .sheet(isPresented: $zeigeHautBearbeiten)   { HautForm(eintrag: eintrag) }
    }

    // MARK: - Hero

    private var heroKarte: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: modulTyp.symbol)
                            .font(.caption.bold())
                            .foregroundStyle(tint)
                        Text(modulTyp.label)
                            .font(.caption.bold())
                            .foregroundStyle(tint)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(tint.opacity(0.12), in: Capsule())

                    Text(displayTitle)
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
                if modulTyp != .haut {
                    ZStack {
                        Circle()
                            .fill(tint.opacity(0.15))
                            .frame(width: 64, height: 64)
                        VStack(spacing: 0) {
                            Text("\(eintrag.schmerzstaerke)")
                                .font(.largeTitle.bold())
                                .foregroundStyle(tint)
                        }
                    }
                }
            }

            if modulTyp != .haut {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.12))
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(
                                colors: [tint.opacity(0.7), tint],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(
                                width: geo.size.width * CGFloat(eintrag.schmerzstaerke) / 10,
                                height: 8
                            )
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("Schmerzstärke")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(eintrag.schmerzstaerke) / 10")
                        .font(.caption.bold()).foregroundStyle(tint)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    // MARK: - Schmerz

    @ViewBuilder
    private var schmerzInhalt: some View {
        if !eintrag.koerperstelle.isEmpty || !eintrag.schmerzart.isEmpty || eintrag.dauerMinuten > 0 {
            VStack(alignment: .leading, spacing: 12) {
                Label("Schmerz", systemImage: "waveform.path.ecg")
                    .font(.headline).foregroundStyle(tint)
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
            .karte()
        }
        if !eintrag.ausloeser.isEmpty {
            infoKarte("Auslöser", symbol: "exclamationmark.triangle.fill", farbe: .orange, text: eintrag.ausloeser)
        }
        if !eintrag.begleiterscheinungen.isEmpty {
            infoKarte("Begleiterscheinungen", symbol: "list.bullet.medical", farbe: .purple, text: eintrag.begleiterscheinungen)
        }
        if !eintrag.massnahmen.isEmpty {
            infoKarte("Massnahmen", symbol: "cross.case.fill", farbe: .teal, text: eintrag.massnahmen)
        }
    }

    // MARK: - Rheuma

    @ViewBuilder
    private var rheumaInhalt: some View {
        let gelenke = GelenkStatusCoder.decode(eintrag.gelenkStatus)
        let schmerzhaft = gelenke.filter { $0.value == .schmerzhaft || $0.value == .beides }
        let geschwollen = gelenke.filter { $0.value == .geschwollen || $0.value == .beides }

        if !gelenke.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("Gelenkstatus", systemImage: "figure.arms.open")
                    .font(.headline).foregroundStyle(tint)
                Divider()

                HStack(spacing: 0) {
                    statPill("\(schmerzhaft.count)", label: "Schmerzhaft", farbe: schmerzhaft.isEmpty ? .secondary : .red)
                    Divider().frame(height: 32)
                    statPill("\(geschwollen.count)", label: "Geschwollen", farbe: geschwollen.isEmpty ? .secondary : .blue)
                    Divider().frame(height: 32)
                    statPill("\(gelenke.count)", label: "Betroffen", farbe: tint)
                }

                if !gelenke.isEmpty {
                    Divider()
                    betroffeneGelenkeGrid(gelenke: gelenke)
                }
            }
            .karte()
        }

        if eintrag.morgensteifigkeit > 0 || eintrag.fatigue > 0 {
            VStack(alignment: .leading, spacing: 12) {
                Label("Symptome", systemImage: "thermometer.medium")
                    .font(.headline).foregroundStyle(tint)
                Divider()
                if eintrag.morgensteifigkeit > 0 {
                    HStack {
                        Text("Morgensteifigkeit").font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "sunrise.fill").font(.caption)
                                .foregroundStyle(eintrag.morgensteifigkeit > 30 ? Color.orange : tint)
                            Text("\(eintrag.morgensteifigkeit) Min")
                                .font(.subheadline.bold())
                                .foregroundStyle(eintrag.morgensteifigkeit > 30 ? Color.orange : tint)
                        }
                    }
                }
                if eintrag.fatigue > 0 {
                    HStack {
                        Text("Erschöpfung (Fatigue)").font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "battery.25").font(.caption)
                                .foregroundStyle(fatigueFarbe(eintrag.fatigue))
                            Text("\(eintrag.fatigue)/10")
                                .font(.subheadline.bold())
                                .foregroundStyle(fatigueFarbe(eintrag.fatigue))
                        }
                    }
                }
            }
            .karte()
        }

        if !eintrag.massnahmen.isEmpty {
            infoKarte("Massnahmen", symbol: "cross.case.fill", farbe: tint, text: eintrag.massnahmen)
        }
    }

    @ViewBuilder
    private func betroffeneGelenkeGrid(gelenke: [String: GelenkZustand]) -> some View {
        let gelenkIDs = gelenke.keys.sorted { lhs, rhs in
            let lName = alleGelenke.first(where: { $0.id == lhs })?.langname ?? lhs
            let rName = alleGelenke.first(where: { $0.id == rhs })?.langname ?? rhs
            return lName < rName
        }
        FlowLayout(gelenkIDs) { id in
            let zustand = gelenke[id] ?? .keiner
            let name = alleGelenke.first(where: { $0.id == id })?.kurzname ?? id
            HStack(spacing: 4) {
                Circle()
                    .fill(zustand.farbe)
                    .frame(width: 8, height: 8)
                Text(name)
                    .font(.caption)
                Text(zustand.kuerzel)
                    .font(.caption2.bold())
                    .foregroundStyle(zustand.farbe)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(zustand.farbe.opacity(0.1), in: Capsule())
        }

        HStack(spacing: 16) {
            legendePunkt(farbe: .red, label: "Schmerzhaft")
            legendePunkt(farbe: .blue, label: "Geschwollen")
            legendePunkt(farbe: .purple, label: "Beides")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func legendePunkt(farbe: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(farbe).frame(width: 7, height: 7)
            Text(label)
        }
    }

    // MARK: - Haut

    @ViewBuilder
    private var hautInhalt: some View {
        let stellen = eintrag.hautStellen.components(separatedBy: ", ").filter { !$0.isEmpty }
        let arten = eintrag.hautArt.components(separatedBy: ", ").filter { !$0.isEmpty }

        VStack(alignment: .leading, spacing: 12) {
            Label("Hautbild", systemImage: "bandage")
                .font(.headline).foregroundStyle(tint)
            Divider()

            if !stellen.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Betroffene Stellen").font(.caption).foregroundStyle(.secondary)
                    FlowLayout(stellen) { stelle in
                        Text(stelle)
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(tint.opacity(0.12), in: Capsule())
                            .foregroundStyle(tint)
                    }
                }
            }

            if !arten.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("Art der Veränderung").font(.caption).foregroundStyle(.secondary)
                    FlowLayout(arten) { art in
                        Text(art)
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(.tertiarySystemGroupedBackground), in: Capsule())
                            .foregroundStyle(.primary)
                    }
                }
            }

            if !eintrag.verlauf.isEmpty {
                Divider()
                HStack {
                    Text("Verlauf").font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    verlaufBadge(eintrag.verlauf)
                }
            }

            if !eintrag.fotoDateiname.isEmpty,
               let bild = FotoManager.laden(dateiname: eintrag.fotoDateiname) {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Foto").font(.caption).foregroundStyle(.secondary)
                    Image(uiImage: bild)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .karte()
    }

    @ViewBuilder
    private func verlaufBadge(_ verlauf: String) -> some View {
        let (icon, farbe): (String, Color) = {
            switch verlauf {
            case "besser":     return ("arrow.up.circle.fill", .green)
            case "schlechter": return ("arrow.down.circle.fill", .red)
            default:           return ("equal.circle.fill", .orange)
            }
        }()
        HStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(farbe)
            Text(verlauf.prefix(1).uppercased() + verlauf.dropFirst())
                .font(.subheadline.bold()).foregroundStyle(farbe)
        }
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

            if eintrag.energielevel > 0 {
                HStack {
                    Text("Energie & Vitalität").font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: energieSymbol(eintrag.energielevel)).font(.caption)
                            .foregroundStyle(energieFarbe(eintrag.energielevel))
                        Text(energieLabel(eintrag.energielevel))
                            .font(.subheadline.bold())
                            .foregroundStyle(energieFarbe(eintrag.energielevel))
                    }
                }
            }

            if modulTyp == .schmerz && eintrag.fatigue > 0 {
                HStack {
                    Text("Erschöpfung (Fatigue)").font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "battery.25").font(.caption)
                            .foregroundStyle(fatigueFarbe(eintrag.fatigue))
                        Text("\(eintrag.fatigue)/10")
                            .font(.subheadline.bold())
                            .foregroundStyle(fatigueFarbe(eintrag.fatigue))
                    }
                }
            }

            if modulTyp == .schmerz && eintrag.morgensteifigkeit > 0 {
                HStack {
                    Text("Morgensteifigkeit").font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "sunrise.fill").font(.caption)
                            .foregroundStyle(Color.orange)
                        Text("\(eintrag.morgensteifigkeit) Min")
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.orange)
                    }
                }
            }
        }
        .karte()
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
            .karte()
        }
    }

    // MARK: - Generic helpers

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
        .karte()
    }

    @ViewBuilder
    private func zeile(_ label: String, wert: String) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(wert).font(.subheadline.bold()).multilineTextAlignment(.trailing)
        }
    }

    private func statPill(_ wert: String, label: String, farbe: Color) -> some View {
        VStack(spacing: 4) {
            Text(wert).font(.title3.bold()).foregroundStyle(farbe)
            Text(label).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
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

// MARK: - Card modifier

private extension View {
    func karte() -> some View {
        self
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }
}

