import SwiftUI
import SwiftData

struct SchmerzView: View {
    @Query(sort: \PainEntry.datum, order: .reverse) private var eintraege: [PainEntry]
    @Environment(\.modelContext) private var modelContext

    @State private var zeigeForm = false
    @State private var zeigeAnalyse = false

    private var schmerzEintraege: [PainEntry] { eintraege.filter { !$0.istHautEintrag && $0.koerperstelle != "Rheuma" } }

    private var eintraege30: [PainEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return schmerzEintraege.filter { $0.datum >= cutoff }
    }

    private var avgSchmerz: String {
        guard !eintraege30.isEmpty else { return "–" }
        let avg = Double(eintraege30.map(\.schmerzstaerke).reduce(0, +)) / Double(eintraege30.count)
        return String(format: "%.1f", avg)
    }

    private var avgSchmerzFarbe: Color {
        guard !eintraege30.isEmpty else { return .secondary }
        let avg = Double(eintraege30.map(\.schmerzstaerke).reduce(0, +)) / Double(eintraege30.count)
        return avg <= 3 ? .green : avg <= 6 ? .orange : .red
    }

    private var schube30: Int { eintraege30.filter(\.istSchub).count }

    var body: some View {
        List {
            statistikSektion

            if !schmerzEintraege.isEmpty {
                Section("Einträge") {
                    ForEach(schmerzEintraege.prefix(30)) { eintrag in
                        NavigationLink(destination: PainEntryDetailView(eintrag: eintrag)) {
                            SchmerzEintragZeile(eintrag: eintrag)
                        }
                    }
                    .onDelete(perform: loeschen)
                }
            } else {
                Section {
                    ContentUnavailableView(
                        "Noch keine Einträge",
                        systemImage: "waveform.path.ecg",
                        description: Text("Tippe auf + um deinen ersten Schmerz-Eintrag zu erfassen.")
                    )
                    .listRowBackground(Color.clear)
                }
            }
        }
        .navigationTitle("Schmerztagebuch")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { zeigeForm = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $zeigeForm) { AddEntryView() }
        .sheet(isPresented: $zeigeAnalyse) {
            SchmerzAnalyseView(eintraege: schmerzEintraege)
        }
    }

    // MARK: - Statistik-Header

    private var statistikSektion: some View {
        Section {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    Label("30-Tage-Überblick", systemImage: "waveform.path.ecg")
                        .font(.headline).foregroundStyle(.red)
                    Divider()
                    HStack(spacing: 0) {
                        statPill(avgSchmerz, label: "Ø Schmerz", farbe: avgSchmerzFarbe)
                        Divider().frame(height: 40)
                        statPill("\(schube30)", label: "Schübe", farbe: schube30 == 0 ? .green : .red)
                        Divider().frame(height: 40)
                        statPill("\(eintraege30.count)", label: "Einträge", farbe: .secondary)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)

                if !schmerzEintraege.isEmpty {
                    Button { zeigeAnalyse = true } label: {
                        Label("Schmerz-Analyse öffnen", systemImage: "chart.bar.xaxis.ascending")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.clear)
    }

    private func statPill(_ wert: String, label: String, farbe: Color) -> some View {
        VStack(spacing: 4) {
            Text(wert).font(.title2.bold()).foregroundStyle(farbe)
            Text(label).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func loeschen(at offsets: IndexSet) {
        let sichtbar = Array(schmerzEintraege.prefix(30))
        for index in offsets {
            modelContext.delete(sichtbar[index])
        }
    }
}

// MARK: - Zeile

private struct SchmerzEintragZeile: View {
    let eintrag: PainEntry

    private var df: DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_CH")
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(SchmerzBadge.farbe(fuer: eintrag.schmerzstaerke).opacity(0.15))
                    .frame(width: 40, height: 40)
                Text("\(eintrag.schmerzstaerke)")
                    .font(.subheadline.bold())
                    .foregroundStyle(SchmerzBadge.farbe(fuer: eintrag.schmerzstaerke))
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(df.string(from: eintrag.datum)).font(.subheadline)
                    if eintrag.istSchub {
                        Text("Schub").font(.caption2.bold())
                            .foregroundStyle(.red)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.red.opacity(0.12), in: Capsule())
                    }
                }
                if !eintrag.koerperstelle.isEmpty {
                    Text(eintrag.koerperstelle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                } else if !eintrag.ausloeser.isEmpty {
                    Text(eintrag.ausloeser).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
