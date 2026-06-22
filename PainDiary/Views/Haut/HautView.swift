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
                Section("Einträge") {
                    ForEach(eintraege) { eintrag in
                        HautEintragZeile(eintrag: eintrag)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    modelContext.delete(eintrag)
                                } label: { Label("Löschen", systemImage: "trash") }
                            }
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

private struct HautEintragZeile: View {
    let eintrag: PainEntry

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "bandage.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(eintrag.datum, style: .date).font(.subheadline.bold())

                let arten = eintrag.hautArt.components(separatedBy: ", ").filter { !$0.isEmpty }
                if !arten.isEmpty {
                    Text(arten.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                }

                let stellen = eintrag.hautStellen.components(separatedBy: ", ").filter { !$0.isEmpty }
                if !stellen.isEmpty {
                    Text(stellen.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if !eintrag.notizen.isEmpty {
                Image(systemName: "note.text")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}
