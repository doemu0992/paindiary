import SwiftUI
import SwiftData

struct HautView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<PainEntry> { $0.istHautEintrag == true },
        sort: \PainEntry.datum, order: .reverse
    ) private var eintraege: [PainEntry]

    @State private var zeigeForm = false
    @State private var zeigeAnalyse = false

    private var eintraege30: [PainEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return eintraege.filter { $0.datum >= cutoff }
    }

    private var gruppiertNachDatum: [(tag: Date, items: [PainEntry])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: eintraege) { cal.startOfDay(for: $0.datum) }
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

            if eintraege.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Keine Einträge",
                        systemImage: "bandage.fill",
                        description: Text("Tippe auf + um eine Hautveränderung zu erfassen.")
                    )
                    .listRowSeparator(.hidden)
                }
            } else {
                ForEach(gruppiertNachDatum, id: \.tag) { gruppe in
                    Section {
                        ForEach(gruppe.items) { eintrag in
                            NavigationLink(destination: PainEntryDetailView(eintrag: eintrag)) {
                                SchmerzZeile(eintrag: eintrag)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    FotoManager.loeschen(dateiname: eintrag.fotoDateiname)
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
        .navigationTitle("Hautveränderungen")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { zeigeForm = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $zeigeForm) { HautForm() }
        .sheet(isPresented: $zeigeAnalyse) {
            HautAnalyseView()
        }
    }

    // MARK: - Statistik

    private var statistikSektion: some View {
        Section {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    Label("30-Tage-Überblick", systemImage: "chart.bar.fill")
                        .font(.headline).foregroundStyle(.orange)
                    Divider()
                    HStack(spacing: 0) {
                        statPill(
                            "\(eintraege30.count)",
                            label: "Einträge",
                            farbe: eintraege30.isEmpty ? .secondary : .orange
                        )
                        Divider().frame(height: 40)
                        statPill(
                            topArt(in: eintraege30) ?? "–",
                            label: "Häufigste Art",
                            farbe: eintraege30.isEmpty ? .secondary : .orange
                        )
                        Divider().frame(height: 40)
                        statPill(
                            topStelle(in: eintraege30) ?? "–",
                            label: "Häufigste Stelle",
                            farbe: eintraege30.isEmpty ? .secondary : .orange
                        )
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)

                Button { zeigeAnalyse = true } label: {
                    Label("Haut-Analyse öffnen", systemImage: "chart.bar.xaxis.ascending")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.orange, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.clear)
    }

    private func statPill(_ wert: String, label: String, farbe: Color) -> some View {
        VStack(spacing: 4) {
            Text(wert).font(.title2.bold()).foregroundStyle(farbe).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func topArt(in liste: [PainEntry]) -> String? {
        let alle = liste.flatMap { $0.hautArt.components(separatedBy: ", ").filter { !$0.isEmpty } }
        return Dictionary(grouping: alle, by: { $0 }).max(by: { $0.value.count < $1.value.count })?.key
    }

    private func topStelle(in liste: [PainEntry]) -> String? {
        let alle = liste.flatMap { $0.hautStellen.components(separatedBy: ", ").filter { !$0.isEmpty } }
        return Dictionary(grouping: alle, by: { $0 }).max(by: { $0.value.count < $1.value.count })?.key
    }
}

// MARK: - Zeile

