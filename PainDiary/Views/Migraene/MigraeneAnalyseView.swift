import SwiftUI
import Charts

struct MigraeneAnalyseView: View {
    let anfaelle: [MigraeneEintrag]
    let zyklusAnalyse: ZyklusAnalyse

    @Environment(\.dismiss) private var dismiss
    @AppStorage("zyklusModulAktiv") private var zyklusModulAktiv = false

    // MARK: - Computed

    private var anfaelle30: [MigraeneEintrag] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return anfaelle.filter { $0.datum >= cutoff }
    }

    private var monatlicherVerlauf: [(monat: Date, anzahl: Int)] {
        let cal = Calendar.current
        return (0..<6).reversed().compactMap { offset -> (Date, Int)? in
            guard let ref = cal.date(byAdding: .month, value: -offset, to: Date()),
                  let interval = cal.dateInterval(of: .month, for: ref) else { return nil }
            let count = anfaelle.filter { $0.datum >= interval.start && $0.datum < interval.end }.count
            return (interval.start, count)
        }
    }

    private var topAusloeser: [(name: String, anzahl: Int)] {
        var counts: [String: Int] = [:]
        anfaelle.flatMap(\.ausloeserListe).forEach { counts[$0, default: 0] += 1 }
        return counts.map { ($0.key, $0.value) }
            .sorted { $0.anzahl > $1.anzahl }
            .prefix(6).map { $0 }
    }

    private struct TageszeitPunkt: Identifiable {
        let id = UUID()
        let label: String
        let anzahl: Int
        let farbe: Color
    }

    private var tageszeitMuster: [TageszeitPunkt] {
        var n = 0, m = 0, mi = 0, na = 0, ab = 0
        for a in anfaelle {
            switch Calendar.current.component(.hour, from: a.datum) {
            case 6..<11:  m  += 1
            case 11..<14: mi += 1
            case 14..<18: na += 1
            case 18..<22: ab += 1
            default:      n  += 1
            }
        }
        return [
            .init(label: "Nacht",   anzahl: n,  farbe: .indigo),
            .init(label: "Morgens", anzahl: m,  farbe: .orange),
            .init(label: "Mittags", anzahl: mi, farbe: .yellow),
            .init(label: "Nachm.",  anzahl: na, farbe: .mint),
            .init(label: "Abend",   anzahl: ab, farbe: .purple),
        ]
    }

    private var avgDauerMin: Double? {
        let mit = anfaelle.filter { $0.dauer > 0 }.map { Double($0.dauer) }
        guard !mit.isEmpty else { return nil }
        return mit.reduce(0, +) / Double(mit.count)
    }

    private var auraQuote: Double {
        guard !anfaelle.isEmpty else { return 0 }
        return Double(anfaelle.filter(\.hatAura).count) / Double(anfaelle.count) * 100
    }

    private struct MedWirksamkeit: Identifiable {
        let id = UUID()
        let name: String
        let gut: Int
        let teilweise: Int
        let nicht: Int
        var total: Int { gut + teilweise + nicht }
    }

    private var medWirksamkeit: [MedWirksamkeit] {
        var map: [String: (Int, Int, Int)] = [:]
        for a in anfaelle where !a.akutmedikament.isEmpty {
            var (g, t, n) = map[a.akutmedikament] ?? (0, 0, 0)
            switch a.medikamentWirksam {
            case "Ja":        g += 1
            case "Teilweise": t += 1
            case "Nein":      n += 1
            default: break
            }
            map[a.akutmedikament] = (g, t, n)
        }
        return map.map { MedWirksamkeit(name: $0.key, gut: $0.value.0, teilweise: $0.value.1, nicht: $0.value.2) }
            .filter { $0.total > 0 }
            .sorted { $0.total > $1.total }
    }

    private var zyklusDaten: [(phase: ZyklusRechner.Zyklusphase, anzahl: Int, avgStaerke: Double)] {
        ZyklusRechner.migraeneJePhase(anfaelle: anfaelle, analyse: zyklusAnalyse)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    summaryKarte
                    verlaufKarte
                    tageszeitKarte
                    if !topAusloeser.isEmpty { ausloeserKarte }
                    HStack(alignment: .top, spacing: 12) {
                        auraKarte
                        dauerKarte
                    }
                    if !medWirksamkeit.isEmpty { medikamentKarte }
                    if zyklusModulAktiv && !zyklusDaten.isEmpty { zyklusKarte }
                }
                .padding()
            }
            .navigationTitle("Migräne-Analyse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    // MARK: - Summary

    private var summaryKarte: some View {
        let total = anfaelle.count
        let avg = anfaelle.isEmpty ? 0.0
            : Double(anfaelle.map(\.staerke).reduce(0, +)) / Double(anfaelle.count)
        return HStack(spacing: 0) {
            statZelle("\(total)", label: "Anfälle total", farbe: .purple)
            Divider().frame(height: 44)
            statZelle("\(anfaelle30.count)", label: "Letzte 30 Tage", farbe: .orange)
            Divider().frame(height: 44)
            statZelle(String(format: "%.1f", avg), label: "Ø Stärke", farbe: .red)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    private func statZelle(_ wert: String, label: String, farbe: Color) -> some View {
        VStack(spacing: 4) {
            Text(wert).font(.title2.bold()).foregroundStyle(farbe)
            Text(label).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Verlauf

    private var verlaufKarte: some View {
        karte(titel: "Verlauf (6 Monate)", symbol: "chart.bar.fill", farbe: .purple) {
            Chart(monatlicherVerlauf, id: \.monat) { item in
                BarMark(
                    x: .value("Monat", item.monat, unit: .month),
                    y: .value("Anfälle", item.anzahl)
                )
                .foregroundStyle(Color.purple.gradient)
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) {
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
            .frame(height: 130)
        }
    }

    // MARK: - Tageszeit

    private var tageszeitKarte: some View {
        karte(titel: "Beginn nach Tageszeit", symbol: "clock.fill", farbe: .indigo) {
            Chart(tageszeitMuster) { item in
                BarMark(
                    x: .value("Zeit", item.label),
                    y: .value("Anzahl", item.anzahl)
                )
                .foregroundStyle(item.farbe.gradient)
                .cornerRadius(4)
            }
            .frame(height: 110)
        }
    }

    // MARK: - Auslöser

    private var ausloeserKarte: some View {
        karte(titel: "Top Auslöser", symbol: "exclamationmark.triangle.fill", farbe: .orange) {
            let maxVal = topAusloeser.first?.anzahl ?? 1
            VStack(spacing: 10) {
                ForEach(topAusloeser, id: \.name) { item in
                    HStack(spacing: 10) {
                        Text(item.name)
                            .font(.subheadline)
                            .frame(width: 110, alignment: .leading)
                            .lineLimit(1)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.orange.opacity(0.15))
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.orange.gradient)
                                    .frame(width: geo.size.width * CGFloat(item.anzahl) / CGFloat(maxVal))
                            }
                        }
                        .frame(height: 18)
                        Text("\(item.anzahl)")
                            .font(.caption.bold()).foregroundStyle(.orange)
                            .frame(width: 20, alignment: .trailing)
                    }
                }
            }
        }
    }

    // MARK: - Aura & Dauer

    private var auraKarte: some View {
        VStack(spacing: 8) {
            Image(systemName: "eye.fill").font(.title2).foregroundStyle(.purple)
            Text(String(format: "%.0f%%", auraQuote))
                .font(.title.bold()).foregroundStyle(.purple)
            Text("mit Aura").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    private var dauerKarte: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.fill").font(.title2).foregroundStyle(.teal)
            Group {
                if let avg = avgDauerMin {
                    let h = Int(avg) / 60; let m = Int(avg) % 60
                    Text(h > 0 ? "\(h)h\(m > 0 ? " \(m)m" : "")" : "\(m)m")
                } else {
                    Text("–")
                }
            }
            .font(.title.bold()).foregroundStyle(.teal)
            Text("Ø Dauer").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    // MARK: - Medikament

    private var medikamentKarte: some View {
        karte(titel: "Medikament-Wirksamkeit", symbol: "pill.fill", farbe: .blue) {
            VStack(spacing: 14) {
                ForEach(medWirksamkeit) { med in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(med.name).font(.subheadline.bold())
                        GeometryReader { geo in
                            HStack(spacing: 2) {
                                if med.gut > 0 {
                                    RoundedRectangle(cornerRadius: 3).fill(Color.green)
                                        .frame(width: geo.size.width * CGFloat(med.gut) / CGFloat(med.total))
                                }
                                if med.teilweise > 0 {
                                    RoundedRectangle(cornerRadius: 3).fill(Color.orange)
                                        .frame(width: geo.size.width * CGFloat(med.teilweise) / CGFloat(med.total))
                                }
                                if med.nicht > 0 {
                                    RoundedRectangle(cornerRadius: 3).fill(Color.red)
                                        .frame(width: geo.size.width * CGFloat(med.nicht) / CGFloat(med.total))
                                }
                            }
                            .frame(height: 10)
                        }
                        .frame(height: 10)
                        HStack(spacing: 10) {
                            if med.gut > 0 {
                                Label("\(med.gut)× wirksam", systemImage: "circle.fill")
                                    .font(.caption).foregroundStyle(.green)
                            }
                            if med.teilweise > 0 {
                                Label("\(med.teilweise)× teilweise", systemImage: "circle.fill")
                                    .font(.caption).foregroundStyle(.orange)
                            }
                            if med.nicht > 0 {
                                Label("\(med.nicht)× nicht", systemImage: "circle.fill")
                                    .font(.caption).foregroundStyle(.red)
                            }
                        }
                    }
                    if med.id != medWirksamkeit.last?.id { Divider() }
                }
            }
        }
    }

    // MARK: - Zyklus

    private var zyklusKarte: some View {
        karte(titel: "Zyklus-Korrelation", symbol: "moon.stars.fill", farbe: .pink) {
            Chart(zyklusDaten, id: \.phase) { item in
                BarMark(
                    x: .value("Phase", item.phase.rawValue),
                    y: .value("Anfälle", item.anzahl)
                )
                .foregroundStyle(phaseFarbe(item.phase).gradient)
                .cornerRadius(4)
                .annotation(position: .top) {
                    Text("\(item.anzahl)").font(.caption2.bold())
                        .foregroundStyle(phaseFarbe(item.phase))
                }
            }
            .frame(height: 110)
        }
    }

    private func phaseFarbe(_ phase: ZyklusRechner.Zyklusphase) -> Color {
        switch phase {
        case .menstruation:  return .red
        case .follikelphase: return .yellow
        case .ovulation:     return .orange
        case .lutealphase:   return .purple
        }
    }

    // MARK: - Helper

    private func karte<Content: View>(titel: String, symbol: String, farbe: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(titel, systemImage: symbol)
                .font(.headline).foregroundStyle(farbe)
            Divider()
            content()
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }
}
