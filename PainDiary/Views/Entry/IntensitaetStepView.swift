import SwiftUI

struct IntensitaetStepView: View {
    @Binding var schmerzstaerke: Int
    @Binding var verlauf: String
    @Binding var istSchub: Bool
    @Binding var gelenkStatus: String
    var letzterEintrag: PainEntry? = nil

    @State private var zeigeGelenke: Bool = false

    var body: some View {
        VStack(spacing: 32) {
            Text("Wie stark sind deine Schmerzen?")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            SchmerzBadge(staerke: schmerzstaerke)
                .scaleEffect(2.5)
                .frame(height: 110)

            Text(beschreibung)
                .font(.headline)
                .foregroundStyle(SchmerzBadge.farbe(fuer: schmerzstaerke))
                .animation(.easeInOut, value: schmerzstaerke)

            VStack(spacing: 16) {
                HStack {
                    Text("0 – Kein Schmerz").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("10 – Unerträglich").font(.caption).foregroundStyle(.secondary)
                }
                Slider(value: Binding(
                    get: { Double(schmerzstaerke) },
                    set: { schmerzstaerke = Int($0) }
                ), in: 0...10, step: 1)
                .tint(SchmerzBadge.farbe(fuer: schmerzstaerke))
                .onChange(of: schmerzstaerke) { _, _ in
#if os(iOS)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
                }

                HStack {
                    ForEach(0...10, id: \.self) { i in
                        Text("\(i)")
                            .font(.system(size: 10))
                            .foregroundStyle(i == schmerzstaerke
                                ? SchmerzBadge.farbe(fuer: i) : .secondary.opacity(0.5))
                            .fontWeight(i == schmerzstaerke ? .bold : .regular)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))

            // Schub / Flare toggle
            Button {
                withAnimation(.spring(response: 0.25)) { istSchub.toggle() }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: istSchub ? "flame.fill" : "flame")
                        .font(.title3)
                        .foregroundStyle(istSchub ? .red : .secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Schub / Flare")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                        Text("Akute Verschlechterung / Krankheitsschub")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: istSchub ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(istSchub ? .red : .secondary)
                }
                .padding()
                .background(
                    istSchub ? Color.red.opacity(0.1) : Color(.secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 16)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(istSchub ? Color.red.opacity(0.4) : Color.clear, lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)

            // Gelenke erfassen (optional, expandable)
            VStack(spacing: 0) {
                Button {
                    withAnimation(.spring(response: 0.3)) { zeigeGelenke.toggle() }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: gelenkAktiv ? "hand.point.up.left.fill" : "hand.point.up.left")
                            .font(.title3)
                            .foregroundStyle(gelenkAktiv ? Color.purple : Color.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Gelenke erfassen")
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                            Text(gelenkAktiv ? gelenkZusammenfassung : "Optional · bei Gelenkbeschwerden")
                                .font(.caption)
                                .foregroundStyle(gelenkAktiv ? Color.purple : Color.secondary)
                        }
                        Spacer()
                        Image(systemName: zeigeGelenke ? "chevron.up" : "chevron.down")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(
                        gelenkAktiv ? Color.purple.opacity(0.08) : Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 16)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(gelenkAktiv ? Color.purple.opacity(0.3) : Color.clear, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)

                if zeigeGelenke {
                    GelenkStepView(gelenkStatus: $gelenkStatus)
                        .padding(.top, 12)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            if let letzter = letzterEintrag {
                VerlaufSektionView(letzterEintrag: letzter, verlauf: $verlauf)
            }
        }
        .padding(.horizontal)
        .onAppear {
            if !gelenkStatus.isEmpty { zeigeGelenke = true }
        }
    }

    private var gelenkAktiv: Bool { !gelenkStatus.isEmpty }

    private var gelenkZusammenfassung: String {
        let dict = GelenkStatusCoder.decode(gelenkStatus)
        let tjc = DAS28Rechner.tjc28(dict)
        let sjc = DAS28Rechner.sjc28(dict)
        var teile: [String] = []
        if tjc > 0 { teile.append("\(tjc) schmerzhaft") }
        if sjc > 0 { teile.append("\(sjc) geschwollen") }
        return teile.isEmpty ? "Eingetragen" : teile.joined(separator: ", ")
    }

    private var beschreibung: String {
        switch schmerzstaerke {
        case 0:      return "Kein Schmerz"
        case 1...2:  return "Leicht – kaum bemerkbar"
        case 3...4:  return "Mild – ablenkbar"
        case 5...6:  return "Mässig – beeinträchtigt"
        case 7...8:  return "Stark – schwer erträglich"
        case 9...10: return "Sehr stark – unerträglich"
        default:     return ""
        }
    }
}

// MARK: - Verlauf section

private struct VerlaufSektionView: View {
    let letzterEintrag: PainEntry
    @Binding var verlauf: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Vergleich mit letztem Eintrag")
                    .font(.headline)
                Spacer()
                Text(zeitAbstand)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Stärke \(letzterEintrag.schmerzstaerke)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !letzterEintrag.koerperstelle.isEmpty {
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(letzterEintrag.koerperstelle.components(separatedBy: ", ").first ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            HStack(spacing: 10) {
                ForEach(verlaufOptionen, id: \.wert) { opt in
                    Button {
                        verlauf = verlauf == opt.wert ? "" : opt.wert
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: opt.symbol)
                            Text(opt.label)
                                .font(.subheadline.bold())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(verlauf == opt.wert
                            ? opt.farbe.opacity(0.22)
                            : Color.secondary.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(verlauf == opt.wert ? opt.farbe : .secondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(verlauf == opt.wert ? opt.farbe.opacity(0.5) : Color.clear,
                                        lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(response: 0.2), value: verlauf)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var zeitAbstand: String {
        let diff = Calendar.current.dateComponents(
            [.hour, .minute], from: letzterEintrag.datum, to: Date())
        let h = diff.hour ?? 0
        let m = diff.minute ?? 0
        if h == 0 { return "vor \(m) Min." }
        if h < 24  { return "vor \(h) Std." }
        let days = h / 24
        return "vor \(days) Tag\(days == 1 ? "" : "en")"
    }

    private struct VerlaufOption {
        let wert: String
        let label: String
        let symbol: String
        let farbe: Color
    }

    private let verlaufOptionen: [VerlaufOption] = [
        VerlaufOption(wert: "besser",     label: "Besser",     symbol: "arrow.up",    farbe: .green),
        VerlaufOption(wert: "gleich",     label: "Gleich",     symbol: "arrow.right", farbe: .orange),
        VerlaufOption(wert: "schlechter", label: "Schlechter", symbol: "arrow.down",  farbe: .red),
    ]
}

