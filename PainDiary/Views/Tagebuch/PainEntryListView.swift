import SwiftUI
import SwiftData

struct PainEntryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PainEntry.datum, order: .reverse) private var eintraege: [PainEntry]

    @State private var wizardAnzeigen = false
    @State private var suchtext = ""
    @State private var filterAnzeigen = false
    @State private var filterStaerkeMin = 0
    @State private var filterStaerkeMax = 10
    @State private var filterZeitraum = Zeitraum.alle

    enum Zeitraum: String, CaseIterable {
        case alle = "Alle"
        case woche = "7 Tage"
        case monat = "30 Tage"
        case dreiMonate = "3 Monate"

        var tage: Int? {
            switch self {
            case .alle: return nil
            case .woche: return 7
            case .monat: return 30
            case .dreiMonate: return 90
            }
        }
    }

    private var gefilterteEintraege: [PainEntry] {
        eintraege.filter { eintrag in
            let suchMatch = suchtext.isEmpty ||
                eintrag.koerperstelle.localizedCaseInsensitiveContains(suchtext) ||
                eintrag.schmerzart.localizedCaseInsensitiveContains(suchtext) ||
                eintrag.ausloeser.localizedCaseInsensitiveContains(suchtext) ||
                eintrag.notizen.localizedCaseInsensitiveContains(suchtext)

            let staerkeMatch = eintrag.schmerzstaerke >= filterStaerkeMin &&
                               eintrag.schmerzstaerke <= filterStaerkeMax

            let datumMatch: Bool
            if let tage = filterZeitraum.tage {
                let grenze = Calendar.current.date(byAdding: .day, value: -tage, to: Date()) ?? Date()
                datumMatch = eintrag.datum >= grenze
            } else {
                datumMatch = true
            }

            return suchMatch && staerkeMatch && datumMatch
        }
    }

    private var filterAktiv: Bool {
        filterStaerkeMin > 0 || filterStaerkeMax < 10 || filterZeitraum != .alle
    }

    var body: some View {
        List {
            if gefilterteEintraege.isEmpty {
                if eintraege.isEmpty {
                    ContentUnavailableView(
                        "Noch keine Einträge",
                        systemImage: "heart.text.clipboard",
                        description: Text("Tippe auf + um deinen ersten Schmerzeintrag zu erfassen.")
                    )
                    .listRowSeparator(.hidden)
                } else {
                    ContentUnavailableView.search(text: suchtext)
                        .listRowSeparator(.hidden)
                }
            } else {
                ForEach(gefilterteEintraege) { eintrag in
                    NavigationLink(destination: PainEntryDetailView(eintrag: eintrag)) {
                        PainEntryZeile(eintrag: eintrag)
                    }
                }
                .onDelete(perform: loeschen)
            }
        }
        .navigationTitle("Schmerztagebuch")
        .searchable(text: $suchtext, prompt: "Körperstelle, Schmerzart, Auslöser…")
        .toolbar {
#if os(iOS)
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    filterAnzeigen = true
                } label: {
                    Label("Filter", systemImage: filterAktiv ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .foregroundStyle(filterAktiv ? Color.accentColor : Color.primary)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) { EditButton() }
#endif
            ToolbarItem {
                Button { wizardAnzeigen = true } label: {
                    Label("Neuer Eintrag", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $wizardAnzeigen) { AddEntryView() }
        .sheet(isPresented: $filterAnzeigen) { filterSheet }
    }

    private var filterSheet: some View {
        NavigationStack {
            Form {
                Section("Schmerzstärke") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Von \(filterStaerkeMin)")
                            Spacer()
                            Text("Bis \(filterStaerkeMax)")
                        }
                        .font(.subheadline)
                        HStack(spacing: 12) {
                            VStack {
                                Text("Min").font(.caption).foregroundStyle(.secondary)
                                Stepper("\(filterStaerkeMin)", value: $filterStaerkeMin, in: 0...filterStaerkeMax)
                                    .labelsHidden()
                                Text("\(filterStaerkeMin)").font(.title3.bold())
                                    .foregroundStyle(SchmerzBadge.farbe(fuer: filterStaerkeMin))
                            }
                            Spacer()
                            VStack {
                                Text("Max").font(.caption).foregroundStyle(.secondary)
                                Stepper("\(filterStaerkeMax)", value: $filterStaerkeMax, in: filterStaerkeMin...10)
                                    .labelsHidden()
                                Text("\(filterStaerkeMax)").font(.title3.bold())
                                    .foregroundStyle(SchmerzBadge.farbe(fuer: filterStaerkeMax))
                            }
                        }
                    }
                }

                Section("Zeitraum") {
                    Picker("Zeitraum", selection: $filterZeitraum) {
                        ForEach(Zeitraum.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if filterAktiv {
                    Section {
                        Button("Filter zurücksetzen", role: .destructive) {
                            filterStaerkeMin = 0
                            filterStaerkeMax = 10
                            filterZeitraum = .alle
                        }
                    }
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { filterAnzeigen = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func loeschen(_ offsets: IndexSet) {
        let zuLoeschen = offsets.map { gefilterteEintraege[$0] }
        withAnimation {
            zuLoeschen.forEach { modelContext.delete($0) }
        }
    }
}

private struct PainEntryZeile: View {
    let eintrag: PainEntry

    private func stimmungFarbe(_ wert: Int) -> Color {
        switch wert {
        case 1...2: return .gray
        case 3: return .orange
        default: return .pink
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            SchmerzBadge(staerke: eintrag.schmerzstaerke)
            VStack(alignment: .leading, spacing: 3) {
                Text(!eintrag.koerperstelle.isEmpty ? eintrag.koerperstelle
                     : !eintrag.hautStellen.isEmpty ? eintrag.hautStellen
                     : "Körperstelle unbekannt")
                    .font(.headline)
                HStack(spacing: 6) {
                    if !eintrag.schmerzart.isEmpty {
                        Text(eintrag.schmerzart)
                            .font(.caption).foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text("·").font(.caption).foregroundStyle(.secondary)
                    }
                    Group {
                        if Calendar.current.isDateInToday(eintrag.datum) {
                            Text(eintrag.datum, style: .relative)
                        } else if Calendar.current.isDateInYesterday(eintrag.datum) {
                            Text("Gestern")
                        } else {
                            Text(eintrag.datum, style: .date)
                        }
                    }
                    .font(.caption).foregroundStyle(.secondary)
                    if let code = eintrag.wetterCode {
                        Text("·").font(.caption).foregroundStyle(.secondary)
                        Image(systemName: WetterSnapshot.symbolFuerCode(code))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if !eintrag.ausloeser.isEmpty {
                    Text(eintrag.ausloeser)
                        .font(.caption).foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                if eintrag.istSchub {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                        Text("Schub")
                            .font(.caption2.bold())
                    }
                    .foregroundStyle(Color.red)
                }
                if eintrag.stimmung > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                        Text("\(eintrag.stimmung)")
                            .font(.caption2.bold())
                    }
                    .foregroundStyle(stimmungFarbe(eintrag.stimmung))
                }
                if eintrag.morgensteifigkeit > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "sunrise.fill")
                            .font(.caption2)
                        Text("\(eintrag.morgensteifigkeit)'")
                            .font(.caption2.bold())
                    }
                    .foregroundStyle(Color.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
