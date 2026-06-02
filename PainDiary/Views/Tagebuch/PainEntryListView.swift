import SwiftUI
import SwiftData

struct PainEntryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PainEntry.datum, order: .reverse) private var eintraege: [PainEntry]
    @State private var wizardAnzeigen = false

    var body: some View {
        List {
            if eintraege.isEmpty {
                ContentUnavailableView(
                    "Noch keine Einträge",
                    systemImage: "heart.text.clipboard",
                    description: Text("Tippe auf + um deinen ersten Schmerzeintrag zu erfassen.")
                )
                .listRowSeparator(.hidden)
            } else {
                ForEach(eintraege) { eintrag in
                    NavigationLink(destination: PainEntryDetailView(eintrag: eintrag)) {
                        PainEntryZeile(eintrag: eintrag)
                    }
                }
                .onDelete(perform: loeschen)
            }
        }
        .navigationTitle("Schmerztagebuch")
        .toolbar {
#if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) { EditButton() }
#endif
            ToolbarItem {
                Button { wizardAnzeigen = true } label: {
                    Label("Neuer Eintrag", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $wizardAnzeigen) { AddEntryView() }
    }

    private func loeschen(_ offsets: IndexSet) {
        withAnimation {
            offsets.forEach { modelContext.delete(eintraege[$0]) }
        }
    }
}

private struct PainEntryZeile: View {
    let eintrag: PainEntry

    var body: some View {
        HStack(spacing: 12) {
            SchmerzBadge(staerke: eintrag.schmerzstaerke)
            VStack(alignment: .leading, spacing: 3) {
                Text(eintrag.koerperstelle.isEmpty ? "Körperstelle unbekannt" : eintrag.koerperstelle)
                    .font(.headline)
                HStack(spacing: 6) {
                    if !eintrag.schmerzart.isEmpty {
                        Text(eintrag.schmerzart)
                            .font(.caption).foregroundStyle(.secondary)
                        Text("·").font(.caption).foregroundStyle(.secondary)
                    }
                    Text(eintrag.datum, style: .date)
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            HStack(spacing: 1) {
                ForEach(1...5, id: \.self) { i in
                    Image(systemName: i <= eintrag.stimmung ? "heart.fill" : "heart")
                        .font(.system(size: 8))
                        .foregroundStyle(i <= eintrag.stimmung ? .red : .secondary.opacity(0.3))
                }
            }
        }
        .padding(.vertical, 4)
    }
}
