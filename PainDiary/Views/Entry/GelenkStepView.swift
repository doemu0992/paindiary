import SwiftUI

struct GelenkStepView: View {
    @Binding var gelenkStatus: String

    @State private var statusDict: [String: GelenkZustand] = [:]
    @State private var ansicht: GelenkAnsicht = .finger
    @State private var ausgewaehltesGelenk: AusgewaehltesGelenk? = nil

    var body: some View {
        VStack(spacing: 12) {
            Text("Betroffene Gelenke")
                .font(.title2.bold())

            Picker("Ansicht", selection: $ansicht) {
                ForEach(GelenkAnsicht.allCases, id: \.self) { a in
                    Text(a.rawValue).tag(a)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            if tjc28 > 0 || sjc28 > 0 {
                HStack(spacing: 20) {
                    scoreChip(label: "Druckschmerz", wert: "\(tjc28)/28", farbe: .red)
                    scoreChip(label: "Geschwollen",  wert: "\(sjc28)/28", farbe: .blue)
                }
            }

            HStack(spacing: 16) {
                ForEach([GelenkZustand.schmerzhaft, .geschwollen, .beides], id: \.rawValue) { z in
                    HStack(spacing: 5) {
                        Circle().fill(z.farbe).frame(width: 10, height: 10)
                        Text(z.label).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }

            switch ansicht {
            case .finger:
                GelenkHandView(statusDict: statusDict, onTap: handleTap)
                    .padding(.horizontal)
                Text("Gelenk antippen → Zustand wählen")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

            case .koerper:
                GelenkKoerperView(statusDict: statusDict, onTap: handleTap)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Text("Tippen zum Markieren · Wischen zum Drehen · Doppeltippen zum Zurücksetzen · Rücken/Wirbelsäule: Figur drehen")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear { statusDict = GelenkStatusCoder.decode(gelenkStatus) }
        .onChange(of: statusDict) { _, neu in gelenkStatus = GelenkStatusCoder.encode(neu) }
        .sheet(item: $ausgewaehltesGelenk) { gelenk in
            GelenkZustandSheet(gelenk: gelenk) { neuerZustand in
                withAnimation(.spring(response: 0.2)) {
                    if neuerZustand == .keiner {
                        statusDict.removeValue(forKey: gelenk.id)
                    } else {
                        statusDict[gelenk.id] = neuerZustand
                    }
                }
            }
        }
    }

    private func handleTap(_ gelenkId: String, _ name: String) {
        let zustand = statusDict[gelenkId] ?? .keiner
        ausgewaehltesGelenk = AusgewaehltesGelenk(id: gelenkId, name: name, zustand: zustand)
#if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
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

// MARK: - Supporting types

enum GelenkAnsicht: String, CaseIterable {
    case finger  = "Finger"
    case koerper = "Körper"
}

struct AusgewaehltesGelenk: Identifiable {
    let id: String
    let name: String
    let zustand: GelenkZustand
}

// MARK: - Zustand sheet

struct GelenkZustandSheet: View {
    let gelenk: AusgewaehltesGelenk
    let onWaehlen: (GelenkZustand) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 4)
                .padding(.top, 8)

            Text(gelenk.name)
                .font(.title3.bold())
                .padding(.top, 4)

            VStack(spacing: 10) {
                ForEach([GelenkZustand.schmerzhaft, .geschwollen, .beides], id: \.rawValue) { z in
                    Button {
                        onWaehlen(z)
                        dismiss()
                    } label: {
                        HStack(spacing: 14) {
                            Circle().fill(z.farbe).frame(width: 22, height: 22)
                            Text(z.label)
                                .font(.body.weight(.medium))
                            Spacer()
                            if gelenk.zustand == z {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(z.farbe)
                            }
                        }
                        .padding()
                        .background(z.farbe.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                }

                if gelenk.zustand != .keiner {
                    Button {
                        onWaehlen(.keiner)
                        dismiss()
                    } label: {
                        Label("Markierung entfernen", systemImage: "xmark.circle")
                            .foregroundStyle(.red)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.hidden)
    }
}
