import SwiftUI
import SwiftData

/// Kompakte Kennzahlen für das Arztgespräch (30 / 90 Tage) mit Teilen-Funktion.
/// Alle Berechnungen laufen in `ArztZusammenfassung` (Domain).
struct ArztZusammenfassungKarte: View {
    @Query(sort: \PainEntry.datum, order: .reverse) private var eintraege: [PainEntry]
    @State private var tage = 30

    private var zusammenfassung: ArztZusammenfassung {
        let heute = DayKey.heute()
        let daten = eintraege
            .filter { $0.eintragsArt != .haut }
            .map { SchmerzDatensatz(tag: $0.tag, staerke: $0.schmerzstaerke,
                                    koerperstellen: $0.koerperstellenListe, ausloeser: $0.ausloeserListe) }
        return ArztZusammenfassung.erstelle(datensaetze: daten, von: heute.addiere(tage: -(tage - 1)), bis: heute)
    }

    var body: some View {
        let z = zusammenfassung
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Für den Arztbesuch", systemImage: "stethoscope")
                    .font(.headline).foregroundStyle(.teal)
                Spacer()
                Picker("Zeitraum", selection: $tage) {
                    Text("30 T").tag(30)
                    Text("90 T").tag(90)
                }
                .pickerStyle(.segmented)
                .frame(width: 130)
            }

            if z.eintraege == 0 {
                Text("Keine Einträge im Zeitraum.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                HStack(spacing: 0) {
                    stat(z.mittlereStaerke.map { String(format: "%.1f", $0) } ?? "–", "Ø Stärke")
                    Divider().frame(height: 36)
                    stat(z.maximaleStaerke.map { "\($0)" } ?? "–", "Maximum")
                    Divider().frame(height: 36)
                    stat("\(z.schmerzfreieTage)", "schmerzfrei")
                }

                if let t = z.trend {
                    let symbol = t.richtung() == .schlechter ? "arrow.up.right" : (t.richtung() == .besser ? "arrow.down.right" : "equal")
                    let farbe: Color = t.richtung() == .schlechter ? .red : (t.richtung() == .besser ? .green : .secondary)
                    Label(String(format: "%+.1f im Vergleich zum Zeitraum davor", t.differenz), systemImage: symbol)
                        .font(.caption).foregroundStyle(farbe)
                }

                if !z.topKoerperstellen.isEmpty { chipZeile("Häufigste Stellen", z.topKoerperstellen) }
                if !z.topAusloeser.isEmpty { chipZeile("Häufigste Auslöser", z.topAusloeser) }

                ShareLink(item: text(z)) {
                    Label("Zusammenfassung teilen", systemImage: "square.and.arrow.up")
                        .font(.subheadline.bold()).frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glassSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 24, padding: 20)
    }

    private func stat(_ wert: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(wert).font(.title2.bold())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func chipZeile(_ titel: String, _ eintraege: [HaeufigerEintrag]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titel).font(.caption).foregroundStyle(.secondary)
            Text(eintraege.map { "\($0.name) (\($0.anzahl)×)" }.joined(separator: " · "))
                .font(.subheadline)
        }
    }

    private func text(_ z: ArztZusammenfassung) -> String {
        var zeilen = ["PainDiary – Zusammenfassung der letzten \(tage) Tage"]
        zeilen.append("Einträge: \(z.eintraege) an \(z.erfassteTage) Tagen")
        if let m = z.mittlereStaerke { zeilen.append(String(format: "Mittlere Schmerzstärke: %.1f / 10", m)) }
        if let x = z.maximaleStaerke { zeilen.append("Maximum: \(x) / 10") }
        zeilen.append("Schmerzfreie Tage (dokumentiert): \(z.schmerzfreieTage)")
        if !z.topKoerperstellen.isEmpty {
            zeilen.append("Häufigste Stellen: " + z.topKoerperstellen.map { "\($0.name) (\($0.anzahl)×)" }.joined(separator: ", "))
        }
        if !z.topAusloeser.isEmpty {
            zeilen.append("Häufigste Auslöser: " + z.topAusloeser.map { "\($0.name) (\($0.anzahl)×)" }.joined(separator: ", "))
        }
        zeilen.append("Hinweis: Selbstdokumentation, keine Diagnose.")
        return zeilen.joined(separator: "\n")
    }
}
