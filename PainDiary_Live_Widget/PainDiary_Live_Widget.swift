import WidgetKit
import SwiftUI

// Zyklus-Widget: Home-Screen (klein/mittel) und Lockscreen (rund/rechteckig/inline).
// Daten kommen aus der App Group (`ZyklusWidgetSnapshot`), geschrieben von `ZyklusWidgetService` in der App.

struct ZyklusEntry: TimelineEntry {
    let date: Date
    let snapshot: ZyklusWidgetSnapshot
}

struct ZyklusProvider: TimelineProvider {
    func placeholder(in context: Context) -> ZyklusEntry {
        ZyklusEntry(date: .now, snapshot: Self.beispiel)
    }

    func getSnapshot(in context: Context, completion: @escaping (ZyklusEntry) -> Void) {
        completion(ZyklusEntry(date: .now, snapshot: context.isPreview ? Self.beispiel : ZyklusWidgetSnapshot.laden()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ZyklusEntry>) -> Void) {
        // Eintrag für heute; um Mitternacht neu laden (die App aktualisiert die Daten bei jeder Änderung).
        let jetzt = Date()
        let morgen = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: jetzt) ?? jetzt)
        let entry = ZyklusEntry(date: jetzt, snapshot: ZyklusWidgetSnapshot.laden())
        completion(Timeline(entries: [entry], policy: .after(morgen.addingTimeInterval(60))))
    }

    static let beispiel = ZyklusWidgetSnapshot(
        stand: .now, zyklustag: 12, phase: "Follikelphase", phaseSymbol: "leaf.fill",
        statusText: "Periode in 16 Tagen", naechstePeriode: nil, tageBisPeriode: 16,
        fruchtbar: false, eisprungBestaetigt: false, prognosenPausiert: false)
}

private enum WidgetFarbe {
    static let periode = Color(red: 0.90, green: 0.25, blue: 0.40)
    static let fruchtbar = Color.teal
    static let standard = Color.pink

    static func farbe(_ s: ZyklusWidgetSnapshot) -> Color {
        if s.fruchtbar { return fruchtbar }
        if s.phase == "Menstruation" { return periode }
        return standard
    }
}

struct ZyklusWidgetView: View {
    @Environment(\.widgetFamily) private var familie
    let entry: ZyklusEntry

    private var s: ZyklusWidgetSnapshot { entry.snapshot }
    private var farbe: Color { WidgetFarbe.farbe(s) }
    private var hatDaten: Bool { s.zyklustag != nil }

    var body: some View {
        switch familie {
        case .accessoryCircular:    rund
        case .accessoryRectangular: rechteckig
        case .accessoryInline:      inline
        case .systemMedium:         mittel
        default:                    klein
        }
    }

    // MARK: Lockscreen

    private var rund: some View {
        Gauge(value: Double(min(s.zyklustag ?? 0, 35)), in: 0...35) {
            Image(systemName: s.phaseSymbol)
        } currentValueLabel: {
            Text(hatDaten ? "\(s.zyklustag ?? 0)" : "–")
        }
        .gaugeStyle(.accessoryCircular)
        .tint(farbe)
    }

    private var rechteckig: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(hatDaten ? "Zyklustag \(s.zyklustag ?? 0)" : "Zyklus", systemImage: s.phaseSymbol)
                .font(.headline)
            Text(s.phase.isEmpty ? "Noch keine Daten" : s.phase)
                .font(.caption)
            Text(s.statusText).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inline: some View {
        Label(hatDaten ? "Tag \(s.zyklustag ?? 0) · \(s.statusText)" : "Zyklus: keine Daten", systemImage: s.phaseSymbol)
    }

    // MARK: Home-Screen

    private var klein: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: s.phaseSymbol).foregroundStyle(farbe)
                Spacer()
                if s.fruchtbar { Text("Fruchtbar").font(.caption2.bold()).foregroundStyle(WidgetFarbe.fruchtbar) }
            }
            Spacer(minLength: 0)
            Text("ZYKLUSTAG").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(hatDaten ? "\(s.zyklustag ?? 0)" : "–")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(farbe)
                .minimumScaleFactor(0.6)
            Text(s.phase.isEmpty ? "Noch keine Daten" : s.phase)
                .font(.caption.weight(.semibold))
            Text(s.statusText)
                .font(.caption2).foregroundStyle(.secondary).lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var mittel: some View {
        HStack(spacing: 16) {
            klein
            VStack(alignment: .leading, spacing: 8) {
                zeile("calendar", "Nächste Periode",
                      s.naechstePeriode.map { $0.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "de_CH"))) } ?? "–")
                zeile("hourglass", "In",
                      s.tageBisPeriode.map { $0 < 0 ? "\(-$0) T überfällig" : "\($0) Tagen" } ?? "–")
                zeile(s.eisprungBestaetigt ? "checkmark.seal.fill" : "sparkles", "Eisprung",
                      s.eisprungBestaetigt ? "bestätigt" : "geschätzt")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func zeile(_ symbol: String, _ titel: String, _ wert: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).foregroundStyle(farbe).frame(width: 18)
            VStack(alignment: .leading, spacing: 0) {
                Text(titel).font(.caption2).foregroundStyle(.secondary)
                Text(wert).font(.subheadline.weight(.semibold))
            }
        }
    }
}

struct PainDiary_Live_Widget: Widget {
    let kind = "ZyklusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ZyklusProvider()) { entry in
            ZyklusWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Zyklus")
        .description("Zyklustag, Phase und nächste Periode.")
        .supportedFamilies([.systemSmall, .systemMedium,
                            .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

#Preview(as: .systemSmall) {
    PainDiary_Live_Widget()
} timeline: {
    ZyklusEntry(date: .now, snapshot: ZyklusProvider.beispiel)
}
