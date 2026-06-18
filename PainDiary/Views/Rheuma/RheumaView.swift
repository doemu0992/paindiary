import SwiftUI
import SwiftData

struct RheumaView: View {
    @Query(sort: \PainEntry.datum, order: .reverse) private var eintraege: [PainEntry]
    @Query(sort: \HAQEintrag.datum, order: .reverse) private var haqEintraege: [HAQEintrag]
    @Query(sort: \FACITEintrag.datum, order: .reverse) private var facitEintraege: [FACITEintrag]
    @Query(sort: \BiologikaInjektion.datum, order: .reverse) private var injektionen: [BiologikaInjektion]
    @Query(sort: \Remissionsphase.beginn, order: .reverse) private var remissionsphasen: [Remissionsphase]

    @State private var zeigeForm = false
    @State private var zeigeAnalyse = false

    var body: some View {
        List {
            if !eintraege.isEmpty {
                Section {
                    schnellstatistiken
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            }

            Section("Scores & Verlauf") {
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
                        Image(systemName: "chart.line.uptrend.xyaxis").foregroundStyle(.teal)
                    }
                }
                NavigationLink(destination: FACITView()) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("FACIT-Erschöpfung")
                            if let letzter = facitEintraege.first {
                                Text("Score: \(letzter.facitScore) – \(letzter.erschoepfungsgradText)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    } icon: {
                        Image(systemName: "battery.25percent").foregroundStyle(.orange)
                    }
                }
                NavigationLink(destination: RemissionsView()) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Remissionsphasen")
                            if let aktive = remissionsphasen.first(where: { $0.istAktiv }) {
                                Text("Aktiv seit \(aktive.dauerText)")
                                    .font(.caption).foregroundStyle(.green)
                            }
                        }
                    } icon: {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                    }
                }
            }

            Section("Medikamente & Therapie") {
                NavigationLink(destination: BiologikaView()) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Biologika / Injektionen")
                            if let naechste = injektionen.compactMap(\.naechsteDosis).filter({ $0 > Date() }).min() {
                                Text("Nächste: \(naechste.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption).foregroundStyle(.secondary)
                            } else if let letzte = injektionen.first {
                                Text("Letzte: \(letzte.praeparat)")
                                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                    } icon: {
                        Image(systemName: "syringe.fill").foregroundStyle(.indigo)
                    }
                }
                NavigationLink(destination: KortisonView()) {
                    Label("Kortison-Tagebuch", systemImage: "pills.fill")
                        .foregroundStyle(.primary)
                }
                NavigationLink(destination: ArztbriefView()) {
                    Label("Arztbrief erstellen", systemImage: "doc.text.fill")
                        .foregroundStyle(.primary)
                }
            }
        }
        .navigationTitle("Rheuma & Gelenke")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { zeigeForm = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $zeigeForm) { RheumaSchnellForm() }
        .sheet(isPresented: $zeigeAnalyse) {
            RheumaAnalyseView(eintraege: eintraege, haqEintraege: haqEintraege)
        }
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

        return VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                Label("30-Tage-Überblick", systemImage: "chart.bar.fill")
                    .font(.headline).foregroundStyle(.teal)
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
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)

            Button { zeigeAnalyse = true } label: {
                Label("Rheuma-Analyse öffnen", systemImage: "chart.bar.xaxis.ascending")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.teal, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }

    private func statPill(_ wert: String, label: String, farbe: Color) -> some View {
        VStack(spacing: 4) {
            Text(wert).font(.title2.bold()).foregroundStyle(farbe)
            Text(label).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
