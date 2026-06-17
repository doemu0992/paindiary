import SwiftUI

struct GelenkStepView: View {
    @Binding var gelenkStatus: String

    @State private var statusDict: [String: GelenkZustand] = [:]

    var body: some View {
        VStack(spacing: 20) {
            Text("Betroffene Gelenke")
                .font(.title2.bold())

            // Legend
            HStack(spacing: 16) {
                ForEach([GelenkZustand.schmerzhaft, .geschwollen, .beides], id: \.rawValue) { z in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(z.farbe)
                            .frame(width: 12, height: 12)
                        Text(z.kuerzel == "SG" ? "S+G" : z.kuerzel)
                            .font(.caption2.bold())
                        Text(z.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // DAS28 summary
            if tjc28 > 0 || sjc28 > 0 {
                HStack(spacing: 20) {
                    scoreChip(label: "Druckschmerz", wert: "\(tjc28)/28", farbe: .red)
                    scoreChip(label: "Geschwollen",  wert: "\(sjc28)/28", farbe: .blue)
                }
                .padding(.horizontal)
            }

            // Bilateral groups: Left | Right
            ScrollView {
                VStack(spacing: 16) {
                    bilateraleGruppe(
                        titel: "Finger",
                        rechts: [.fingerRechts],
                        links: [.fingerLinks]
                    )
                    bilateraleGruppe(
                        titel: "Arm",
                        rechts: [.armRechts],
                        links: [.armLinks]
                    )
                    einzelGruppe(titel: "Wirbelsäule", gruppen: [.wirbelsaeule])
                    bilateraleGruppe(
                        titel: "Bein",
                        rechts: [.beinRechts],
                        links: [.beinLinks]
                    )
                    einzelGruppe(titel: "Sonstige", gruppen: [.sonstige])
                }
                .padding(.horizontal)
            }
        }
        .onAppear { statusDict = GelenkStatusCoder.decode(gelenkStatus) }
        .onChange(of: statusDict) { _, neu in gelenkStatus = GelenkStatusCoder.encode(neu) }
    }

    // MARK: - Sub-Views

    private func bilateraleGruppe(titel: String, rechts: [GelenkGruppe], links: [GelenkGruppe]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text(titel)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                if let info = infoText(fuer: titel) {
                    InfoButton(titel: titel, text: info)
                }
            }
            .padding(.leading, 4)

            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .center, spacing: 4) {
                    Text("Links").font(.caption2).foregroundStyle(.secondary)
                    ForEach(links, id: \.rawValue) { gruppe in
                        gelenkGrid(fuer: gruppe)
                    }
                }
                .frame(maxWidth: .infinity)

                Divider()

                VStack(alignment: .center, spacing: 4) {
                    Text("Rechts").font(.caption2).foregroundStyle(.secondary)
                    ForEach(rechts, id: \.rawValue) { gruppe in
                        gelenkGrid(fuer: gruppe)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func einzelGruppe(titel: String, gruppen: [GelenkGruppe]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text(titel)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                if let info = infoText(fuer: titel) {
                    InfoButton(titel: titel, text: info)
                }
            }
            .padding(.leading, 4)

            VStack(spacing: 4) {
                ForEach(gruppen, id: \.rawValue) { gruppe in
                    gelenkGrid(fuer: gruppe)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    @ViewBuilder
    private func gelenkGrid(fuer gruppe: GelenkGruppe) -> some View {
        let gelenke = alleGelenke.filter { $0.gruppe == gruppe }
        if gruppe == .fingerRechts || gruppe == .fingerLinks {
            fingerSpaltenAnsicht(gelenke: gelenke)
        } else {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: min(gelenke.count, 5)), spacing: 4) {
                ForEach(gelenke) { gelenk in
                    gelenkTaste(gelenk)
                }
            }
        }
    }

    private func fingerSpaltenAnsicht(gelenke: [Gelenk]) -> some View {
        let grund  = gelenke.filter { $0.id.contains("MCP") }.sorted { $0.id < $1.id }
        let mittel = gelenke.filter { $0.id.contains("PIP") }.sorted { $0.id < $1.id }
        let namen  = ["Dau.", "Zeig.", "Mitt.", "Ring.", "Kl."]
        return VStack(spacing: 3) {
            HStack(spacing: 4) {
                Text("").frame(width: 34)
                ForEach(namen.indices, id: \.self) { i in
                    Text(namen[i])
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
            HStack(spacing: 4) {
                Text("Grund.")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                    .frame(width: 34, alignment: .trailing)
                ForEach(grund) { gelenk in gelenkKachel(gelenk) }
            }
            HStack(spacing: 4) {
                Text("Mittel.")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                    .frame(width: 34, alignment: .trailing)
                ForEach(mittel) { gelenk in gelenkKachel(gelenk) }
            }
        }
    }

    private func gelenkKachel(_ gelenk: Gelenk) -> some View {
        let zustand = statusDict[gelenk.id] ?? .keiner
        return Button {
            withAnimation(.spring(response: 0.2)) {
                let naechster = zustand.naechster
                if naechster == .keiner {
                    statusDict.removeValue(forKey: gelenk.id)
                } else {
                    statusDict[gelenk.id] = naechster
                }
            }
#if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(zustand.farbe)
                    .frame(minHeight: 30)
                if zustand != .keiner {
                    Text(zustand.kuerzel == "SG" ? "S+G" : zustand.kuerzel)
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func gelenkTaste(_ gelenk: Gelenk) -> some View {
        let zustand = statusDict[gelenk.id] ?? .keiner
        return Button {
            withAnimation(.spring(response: 0.2)) {
                let naechster = zustand.naechster
                if naechster == .keiner {
                    statusDict.removeValue(forKey: gelenk.id)
                } else {
                    statusDict[gelenk.id] = naechster
                }
            }
#if os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
        } label: {
            VStack(spacing: 2) {
                Text(gelenk.kurzname)
                    .font(.system(size: 9, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(minWidth: 32, minHeight: 32)
            .background(zustand.farbe, in: RoundedRectangle(cornerRadius: 6))
            .foregroundStyle(zustand.textfarbe)
        }
        .buttonStyle(.plain)
    }

    private func infoText(fuer titel: String) -> String? {
        switch titel {
        case "Finger":
            return "Grundgelenke (MCP): die Knöchelreihe direkt vor den Fingern. Mittelgelenke (PIP): die mittlere Fingerreihe. Alle 20 Fingergelenke (je 10 pro Hand) fliessen in den DAS28-Score ein."
        case "Arm":
            return "Handgelenk, Ellbogen und Schulter – je links und rechts. Diese 6 Gelenke sind Teil des DAS28-Scores."
        case "Wirbelsäule":
            return "Hals- (HWS), Brust- (BWS) und Lendenwirbelsäule (LWS). Diese Gelenke zählen nicht zum DAS28-Score, können aber bei Spondylarthritis und anderen Rheuma-Formen betroffen sein."
        case "Bein":
            return "Hüfte, Knie und Sprunggelenk – je links und rechts. Nur die Knie fliessen in den DAS28-Score ein."
        case "Sonstige":
            return "Kiefergelenk (Temporomandibulargelenk): kann bei bestimmten Rheuma-Erkrankungen schmerzhaft oder geschwollen sein."
        default:
            return nil
        }
    }

    private func scoreChip(label: String, wert: String, farbe: Color) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(wert).font(.subheadline.bold()).foregroundStyle(farbe)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(farbe.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }

    private var tjc28: Int { DAS28Rechner.tjc28(statusDict) }
    private var sjc28: Int { DAS28Rechner.sjc28(statusDict) }
}
