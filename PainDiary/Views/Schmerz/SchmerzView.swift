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

    private var gruppiertNachDatum: [(tag: Date, items: [PainEntry])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: schmerzEintraege) { cal.startOfDay(for: $0.datum) }
        return grouped.sorted { $0.key > $1.key }
            .map { (tag: $0.key, items: $0.value.sorted { $0.datum > $1.datum }) }
    }

    private func tagLabel(_ datum: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(datum)     { return "Heute" }
        if cal.isDateInYesterday(datum) { return "Gestern" }
        return datum.formatted(.dateTime.weekday(.abbreviated).day().month())
    }

    var body: some View {
        List {
            statistikSektion

            if schmerzEintraege.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Noch keine Einträge",
                        systemImage: "waveform.path.ecg",
                        description: Text("Tippe auf + um deinen ersten Schmerz-Eintrag zu erfassen.")
                    )
                    .listRowBackground(Color.clear)
                }
            } else {
                ForEach(gruppiertNachDatum, id: \.tag) { gruppe in
                    Section {
                        ForEach(gruppe.items) { eintrag in
                            NavigationLink(destination: PainEntryDetailView(eintrag: eintrag)) {
                                SchmerzZeile(eintrag: eintrag)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    modelContext.delete(eintrag)
                                } label: { Label("Löschen", systemImage: "trash") }
                            }
                        }
                    } header: {
                        Text(tagLabel(gruppe.tag))
                            .font(.subheadline.bold()).foregroundStyle(.primary).textCase(nil)
                    }
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
            SchmerzAnalyseView()
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

}

