import SwiftUI
import SwiftData

struct RheumaView: View {
    @Query(sort: \PainEntry.datum, order: .reverse) private var eintraege: [PainEntry]
    @Query(sort: \HAQEintrag.datum, order: .reverse) private var haqEintraege: [HAQEintrag]
    @Query(sort: \Impftermin.impfstoff) private var impfungen: [Impftermin]
    @Query(sort: \Arztbesuch.datum, order: .reverse) private var besuche: [Arztbesuch]
    @Query(sort: \Laborwert.datum, order: .reverse) private var laborwerte: [Laborwert]

    var body: some View {
        List {
            if !eintraege.isEmpty {
                Section {
                    schnellstatistiken
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            }

            Section("Verlauf & Scores") {
                NavigationLink(destination: HAQView()) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("HAQ & DAS28")
                            if let letzter = haqEintraege.first {
                                Text(String(format: "Letzter Score: %.2f", letzter.haqScore))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    } icon: {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundStyle(.purple)
                    }
                }
                NavigationLink(destination: LaborwerteView()) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Laborwerte")
                            if let letzter = laborwerte.first {
                                Text("\(letzter.typ): \(String(format: "%.1f", letzter.wert)) \(letzter.einheit)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    } icon: {
                        Image(systemName: "testtube.2")
                            .foregroundStyle(.blue)
                    }
                }
            }

            Section("Ärztliche Betreuung") {
                NavigationLink(destination: ArztbesuchView()) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Arztbesuche")
                            if let naechster = besuche.compactMap(\.naechsterTermin).filter({ $0 > Date() }).min() {
                                Text("Nächster: \(naechster.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    } icon: {
                        Image(systemName: "stethoscope")
                            .foregroundStyle(.teal)
                    }
                }
                NavigationLink(destination: ImpfpassView()) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Impfpass")
                            let faellig = impfungen.filter { $0.dringlichkeit != .ok }
                            if !faellig.isEmpty {
                                Text("\(faellig.count) ausstehend / fällig")
                                    .font(.caption).foregroundStyle(.orange)
                            }
                        }
                    } icon: {
                        Image(systemName: "syringe.fill")
                            .foregroundStyle(.green)
                    }
                }
                NavigationLink(destination: ArztbriefView()) {
                    Label("Arztbrief erstellen", systemImage: "doc.text.fill")
                        .foregroundStyle(.primary)
                }
            }
        }
        .navigationTitle("Rheuma & Gelenke")
    }

    private var schnellstatistiken: some View {
        let schube = eintraege.filter { $0.istSchub }.count
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date())
        let letzter30 = eintraege.filter { e in
            guard let c = cutoff else { return true }
            return e.datum >= c
        }
        let avgSchmerz = letzter30.isEmpty ? 0.0
            : Double(letzter30.map(\.schmerzstaerke).reduce(0, +)) / Double(letzter30.count)
        let mgEintraege = letzter30.filter { $0.morgensteifigkeit > 0 }
        let avgMg = mgEintraege.isEmpty ? 0.0
            : Double(mgEintraege.map(\.morgensteifigkeit).reduce(0, +)) / Double(mgEintraege.count)

        return VStack(alignment: .leading, spacing: 12) {
            Label("30-Tage-Überblick", systemImage: "chart.bar.fill")
                .font(.headline).foregroundStyle(.purple)
            Divider()
            HStack(spacing: 0) {
                statPill(letzter30.isEmpty ? "–" : String(format: "%.1f", avgSchmerz),
                         label: "Ø Schmerz",
                         farbe: avgSchmerz <= 3 ? .green : avgSchmerz <= 6 ? .orange : .red)
                Divider().frame(height: 40)
                statPill("\(schube)", label: "Schübe gesamt",
                         farbe: schube == 0 ? .green : .orange)
                Divider().frame(height: 40)
                statPill(avgMg > 0 ? String(format: "%.0f'", avgMg) : "–",
                         label: "Ø Steifigkeit",
                         farbe: avgMg > 30 ? .orange : .green)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    private func statPill(_ wert: String, label: String, farbe: Color) -> some View {
        VStack(spacing: 4) {
            Text(wert).font(.title2.bold()).foregroundStyle(farbe)
            Text(label).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
