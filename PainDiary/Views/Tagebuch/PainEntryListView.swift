import SwiftUI
import SwiftData

struct PainEntryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PainEntry.datum, order: .reverse) private var eintraege: [PainEntry]
    @Query(sort: \MigraeneEintrag.datum, order: .reverse) private var migraeneAnfaelle: [MigraeneEintrag]

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

    private enum TagesbuchItem: Identifiable {
        case schmerz(PainEntry)
        case migraene(MigraeneEintrag)

        var id: String {
            switch self {
            case .schmerz(let e):  return "s-\(e.persistentModelID.hashValue)"
            case .migraene(let e): return "m-\(e.persistentModelID.hashValue)"
            }
        }
        var datum: Date {
            switch self {
            case .schmerz(let e):  return e.datum
            case .migraene(let e): return e.datum
            }
        }
    }

    private var gefilterte: [TagesbuchItem] {
        let grenze: Date? = filterZeitraum.tage.map {
            Calendar.current.date(byAdding: .day, value: -$0, to: Date()) ?? Date()
        }
        let schmerzItems: [TagesbuchItem] = eintraege.compactMap { e in
            let suchMatch = suchtext.isEmpty ||
                e.koerperstelle.localizedCaseInsensitiveContains(suchtext) ||
                e.schmerzart.localizedCaseInsensitiveContains(suchtext) ||
                e.ausloeser.localizedCaseInsensitiveContains(suchtext) ||
                e.notizen.localizedCaseInsensitiveContains(suchtext)
            let staerkeMatch = e.schmerzstaerke >= filterStaerkeMin && e.schmerzstaerke <= filterStaerkeMax
            let datumMatch = grenze == nil || e.datum >= grenze!
            return (suchMatch && staerkeMatch && datumMatch) ? .schmerz(e) : nil
        }
        let migraeneItems: [TagesbuchItem] = migraeneAnfaelle.compactMap { a in
            let suchMatch = suchtext.isEmpty ||
                a.seite.localizedCaseInsensitiveContains(suchtext) ||
                a.charakter.localizedCaseInsensitiveContains(suchtext) ||
                a.ausloeser.localizedCaseInsensitiveContains(suchtext) ||
                a.notizen.localizedCaseInsensitiveContains(suchtext)
            let datumMatch = grenze == nil || a.datum >= grenze!
            return (suchMatch && datumMatch) ? .migraene(a) : nil
        }
        return (schmerzItems + migraeneItems).sorted { $0.datum > $1.datum }
    }

    private var filterAktiv: Bool {
        filterStaerkeMin > 0 || filterStaerkeMax < 10 || filterZeitraum != .alle
    }

    var body: some View {
        List {
            if gefilterte.isEmpty {
                if eintraege.isEmpty && migraeneAnfaelle.isEmpty {
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
                ForEach(gefilterte) { item in
                    switch item {
                    case .schmerz(let eintrag):
                        NavigationLink(destination: PainEntryDetailView(eintrag: eintrag)) {
                            PainEntryZeile(eintrag: eintrag)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { modelContext.delete(eintrag) } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                    case .migraene(let anfall):
                        NavigationLink(destination: MigraeneAnfallDetailView(anfall: anfall)) {
                            MigraeneTagesbuchZeile(anfall: anfall)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                NotificationManager.shared.loescheMigraeneErinnerungen(fuer: anfall.datum)
                                modelContext.delete(anfall)
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Schmerztagebuch")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $suchtext, prompt: "Körperstelle, Schmerzart, Auslöser…")
        .toolbar {
#if os(iOS)
            ToolbarItem(placement: .navigationBarLeading) {
                Button { filterAnzeigen = true } label: {
                    Label("Filter", systemImage: filterAktiv
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease.circle")
                        .foregroundStyle(filterAktiv ? Color.accentColor : Color.primary)
                }
            }
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
                Section("Schmerzstärke (Schmerz-Einträge)") {
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
}

// MARK: - Schmerz-Zeile

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
                            Text(eintrag.datum, style: .time)
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
                        Image(systemName: "flame.fill").font(.caption2)
                        Text("Schub").font(.caption2.bold())
                    }
                    .foregroundStyle(Color.red)
                }
                if eintrag.stimmung > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "heart.fill").font(.caption2)
                        Text("\(eintrag.stimmung)").font(.caption2.bold())
                    }
                    .foregroundStyle(stimmungFarbe(eintrag.stimmung))
                }
                if eintrag.morgensteifigkeit > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "sunrise.fill").font(.caption2)
                        Text("\(eintrag.morgensteifigkeit)'").font(.caption2.bold())
                    }
                    .foregroundStyle(Color.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Migräne-Zeile

private struct MigraeneTagesbuchZeile: View {
    let anfall: MigraeneEintrag

    var body: some View {
        HStack(spacing: 12) {
            SchmerzBadge(staerke: anfall.staerke)
            VStack(alignment: .leading, spacing: 3) {
                Text(anfall.kopfschmerzTyp.isEmpty ? "Migräne" : anfall.kopfschmerzTyp)
                    .font(.headline)
                HStack(spacing: 6) {
                    if !anfall.charakter.isEmpty {
                        Text(anfall.charakterListe.first ?? "")
                            .font(.caption).foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text("·").font(.caption).foregroundStyle(.secondary)
                    }
                    Group {
                        if Calendar.current.isDateInToday(anfall.datum) {
                            Text(anfall.datum, style: .time)
                        } else if Calendar.current.isDateInYesterday(anfall.datum) {
                            Text("Gestern")
                        } else {
                            Text(anfall.datum, style: .date)
                        }
                    }
                    .font(.caption).foregroundStyle(.secondary)
                    if anfall.wetterCode != nil {
                        Text("·").font(.caption).foregroundStyle(.secondary)
                        Image(systemName: WetterSnapshot.symbolFuerCode(anfall.wetterCode!))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if !anfall.ausloeser.isEmpty {
                    Text(anfall.ausloeser)
                        .font(.caption).foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                if anfall.hatAura {
                    HStack(spacing: 2) {
                        Image(systemName: "eye.fill").font(.caption2)
                        Text("Aura").font(.caption2.bold())
                    }
                    .foregroundStyle(.purple)
                }
                if anfall.dauer > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "clock.fill").font(.caption2)
                        Text(anfall.dauerText).font(.caption2.bold())
                    }
                    .foregroundStyle(.secondary)
                }
                if !anfall.postdrom.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.clockwise.circle.fill").font(.caption2)
                        Text("Nach").font(.caption2.bold())
                    }
                    .foregroundStyle(.teal)
                }
            }
        }
        .padding(.vertical, 4)
    }

}
