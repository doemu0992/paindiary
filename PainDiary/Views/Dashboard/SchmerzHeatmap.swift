import SwiftUI

struct SchmerzHeatmapKachel: View {
    let eintraege: [PainEntry]

    @State private var ausgewaehlterTag: Date? = nil
    @State private var zeigeDetail = false

    private var kal: Calendar {
        var k = Calendar.current
        k.firstWeekday = 2
        return k
    }

    private let zelle: CGFloat = 12
    private let abstand: CGFloat = 3
    private let tagLabels = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]

    // 26 Wochen (≈6 Monate), älteste zuerst, jede Woche = 7 Tage Mo–So
    private var wochen: [[Date?]] {
        let heute = kal.startOfDay(for: Date())
        guard let currentWeekStart = kal.dateInterval(of: .weekOfYear, for: heute)?.start else { return [] }
        return (-25...0).compactMap { versatz -> [Date?]? in
            guard let ws = kal.date(byAdding: .weekOfYear, value: versatz, to: currentWeekStart) else { return nil }
            return (0..<7).map { tag -> Date? in
                guard let d = kal.date(byAdding: .day, value: tag, to: ws) else { return nil }
                return d <= heute ? d : nil
            }
        }
    }

    private var schmerzProTag: [Date: (schnitt: Double, anzahl: Int)] {
        var dict: [Date: (sum: Int, count: Int)] = [:]
        for e in eintraege where !e.istHautEintrag {
            let tag = kal.startOfDay(for: e.datum)
            let cur = dict[tag] ?? (0, 0)
            dict[tag] = (cur.sum + e.schmerzstaerke, cur.count + 1)
        }
        return dict.mapValues { v in (Double(v.sum) / Double(v.count), v.count) }
    }

    private func zellFarbe(fuer datum: Date) -> Color {
        guard let info = schmerzProTag[datum] else { return Color(.systemFill) }
        let w = info.schnitt
        if w <= 3  { return .green }
        if w <= 6  { return Color(red: 0.95, green: 0.75, blue: 0) }
        if w <= 8  { return .orange }
        return .red
    }

    private func monatLabel(fuer woche: [Date?]) -> String? {
        guard let ersterTag = woche.compactMap({ $0 }).first,
              kal.component(.day, from: ersterTag) <= 7 else { return nil }
        return ersterTag.formatted(.dateTime.month(.abbreviated).locale(Locale(identifier: "de_DE")))
    }

    var body: some View {
        KachelContainer(
            titel: "Schmerzkalender",
            symbol: "calendar.badge.clock",
            farbe: .indigo,
            infoText: "Jeder Tag ist nach seinem Ø-Schmerzwert eingefärbt: Grün ≤3, Gelb 4–6, Orange 7–8, Rot ≥9. Grau = kein Eintrag. Tippe auf einen Tag für Details."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                heatmapGrid
                legendeZeile
                if let tag = ausgewaehlterTag {
                    auswahlInfo(fuer: tag)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.25), value: ausgewaehlterTag)
        }
        .sheet(isPresented: $zeigeDetail) {
            if let tag = ausgewaehlterTag {
                TagesDetailSheet(datum: tag, eintraege: eintraege)
            }
        }
    }

    private var heatmapGrid: some View {
        HStack(alignment: .top, spacing: 4) {
            // Fixe Wochentag-Labels links
            VStack(alignment: .trailing, spacing: abstand) {
                Text("").font(.system(size: 9)).frame(height: 14)
                ForEach(tagLabels, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: zelle)
                }
            }

            // Scrollbare Wochen-Spalten
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: abstand) {
                        ForEach(Array(wochen.enumerated()), id: \.offset) { idx, woche in
                            VStack(alignment: .leading, spacing: abstand) {
                                Text(monatLabel(fuer: woche) ?? "")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(monatLabel(fuer: woche) != nil ? Color.secondary : Color.clear)
                                    .frame(height: 14)

                                ForEach(Array(woche.enumerated()), id: \.offset) { _, datum in
                                    if let d = datum {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(ausgewaehlterTag == d
                                                  ? Color.accentColor
                                                  : zellFarbe(fuer: d))
                                            .frame(width: zelle, height: zelle)
                                            .onTapGesture {
                                                if ausgewaehlterTag == d {
                                                    if schmerzProTag[d] != nil { zeigeDetail = true }
                                                    else { ausgewaehlterTag = nil }
                                                } else {
                                                    ausgewaehlterTag = d
                                                }
                                            }
                                    } else {
                                        Color.clear.frame(width: zelle, height: zelle)
                                    }
                                }
                            }
                            .id(idx)
                        }
                    }
                    .padding(.trailing, 4)
                }
                .onAppear {
                    proxy.scrollTo(wochen.count - 1, anchor: .trailing)
                }
            }
        }
    }

    private var legendeZeile: some View {
        HStack(spacing: 6) {
            Text("Kein Eintrag")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(.systemFill))
                .frame(width: zelle, height: zelle)
            Spacer()
            ForEach([
                (Color.green,                               "≤3"),
                (Color(red: 0.95, green: 0.75, blue: 0),   "4–6"),
                (Color.orange,                              "7–8"),
                (Color.red,                                 "≥9")
            ], id: \.1) { farbe, label in
                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(farbe)
                        .frame(width: zelle, height: zelle)
                    Text(label)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func auswahlInfo(fuer tag: Date) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(tag.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "de_DE"))))
                    .font(.caption.bold())
                if let info = schmerzProTag[tag] {
                    Text("Ø \(String(format: "%.1f", info.schnitt)) · \(info.anzahl) \(info.anzahl == 1 ? "Eintrag" : "Einträge")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Kein Eintrag")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if schmerzProTag[tag] != nil {
                Button { zeigeDetail = true } label: {
                    Label("Details", systemImage: "chevron.right.circle.fill")
                        .font(.caption.bold())
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.mini)
            }
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}
