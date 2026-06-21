import SwiftUI
import SwiftData

// MARK: - Modul-Filter

enum ModulFilter: String, CaseIterable {
    case alle      = "Alle"
    case schmerz   = "Schmerz"
    case rheuma    = "Rheuma"
    case migraene  = "Migräne"
    case haut      = "Haut"
    case zyklus    = "Zyklus"
    case diabetes  = "Diabetes"

    var farbe: Color {
        switch self {
        case .alle:     return .primary
        case .schmerz:  return .red
        case .rheuma:   return .teal
        case .migraene: return .purple
        case .haut:     return .orange
        case .zyklus:   return .pink
        case .diabetes: return .blue
        }
    }
}

// MARK: - Main View

struct PainEntryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PainEntry.datum, order: .reverse) private var eintraege: [PainEntry]
    @Query(sort: \MigraeneEintrag.datum, order: .reverse) private var migraeneAnfaelle: [MigraeneEintrag]
    @Query(sort: \ZyklusEintrag.datum, order: .reverse) private var zyklusEintraege: [ZyklusEintrag]
    @Query(sort: \BlutzuckerEintrag.datum, order: .reverse) private var blutzuckerMessungen: [BlutzuckerEintrag]
    @AppStorage("zyklusModulAktiv") private var zyklusModulAktiv = false
    @AppStorage("diabetesModulAktiv") private var diabetesModulAktiv = false

    @State private var wizardAnzeigen = false
    @State private var suchtext = ""
    @State private var filterAnzeigen = false
    @State private var filterStaerkeMin = 0
    @State private var filterStaerkeMax = 10
    @State private var filterZeitraum = Zeitraum.alle
    @State private var modulFilter: ModulFilter = .alle

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
        case zyklus(ZyklusEintrag)
        case diabetes(BlutzuckerEintrag)

        var id: String {
            switch self {
            case .schmerz(let e):  return "s-\(e.persistentModelID.hashValue)"
            case .migraene(let e): return "m-\(e.persistentModelID.hashValue)"
            case .zyklus(let e):   return "z-\(e.persistentModelID.hashValue)"
            case .diabetes(let e): return "d-\(e.persistentModelID.hashValue)"
            }
        }
        var datum: Date {
            switch self {
            case .schmerz(let e):  return e.datum
            case .migraene(let e): return e.datum
            case .zyklus(let e):   return e.datum
            case .diabetes(let e): return e.datum
            }
        }
    }

    // MARK: - Filtering

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
        let zyklusItems: [TagesbuchItem] = zyklusModulAktiv ? zyklusEintraege.compactMap { e in
            let datumMatch = grenze == nil || e.datum >= grenze!
            let suchMatch = suchtext.isEmpty || e.notizen.localizedCaseInsensitiveContains(suchtext)
            return (suchMatch && datumMatch) ? .zyklus(e) : nil
        } : []
        let diabetesItems: [TagesbuchItem] = diabetesModulAktiv ? blutzuckerMessungen.compactMap { e in
            let datumMatch = grenze == nil || e.datum >= grenze!
            let suchMatch = suchtext.isEmpty ||
                e.messZeitpunkt.localizedCaseInsensitiveContains(suchtext) ||
                e.notizen.localizedCaseInsensitiveContains(suchtext)
            return (suchMatch && datumMatch) ? .diabetes(e) : nil
        } : []

        let alle = (schmerzItems + migraeneItems + zyklusItems + diabetesItems)
            .sorted { $0.datum > $1.datum }

        switch modulFilter {
        case .alle:
            return alle
        case .schmerz:
            return alle.filter {
                if case .schmerz(let e) = $0 { return !e.istHautEintrag && e.koerperstelle != "Rheuma" }
                return false
            }
        case .rheuma:
            return alle.filter {
                if case .schmerz(let e) = $0 { return e.koerperstelle == "Rheuma" }
                return false
            }
        case .migraene:
            return alle.filter {
                if case .migraene = $0 { return true }
                return false
            }
        case .haut:
            return alle.filter {
                if case .schmerz(let e) = $0 { return e.istHautEintrag }
                return false
            }
        case .zyklus:
            return alle.filter {
                if case .zyklus = $0 { return true }
                return false
            }
        case .diabetes:
            return alle.filter {
                if case .diabetes = $0 { return true }
                return false
            }
        }
    }

    private var filterAktiv: Bool {
        filterStaerkeMin > 0 || filterStaerkeMax < 10 || filterZeitraum != .alle
    }

    // MARK: - Date Grouping

    private var gruppiertNachDatum: [(tag: Date, items: [TagesbuchItem])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: gefilterte) { cal.startOfDay(for: $0.datum) }
        return grouped.sorted { $0.key > $1.key }
            .map { (tag: $0.key, items: $0.value.sorted { $0.datum > $1.datum }) }
    }

    private func tagLabel(_ datum: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(datum)     { return "Heute" }
        if cal.isDateInYesterday(datum) { return "Gestern" }
        return datum.formatted(.dateTime.weekday(.abbreviated).day().month())
    }

    // MARK: - Body

    var body: some View {
        List {
            // 1. Sparkline-Header (letzte 7 Tage)
            Section {
                sparklineHeader
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            // 2. Filter-Chips
            Section {
                filterChips
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            // 3. Gruppierte Einträge
            if gefilterte.isEmpty {
                Section {
                    if eintraege.isEmpty && migraeneAnfaelle.isEmpty && zyklusEintraege.isEmpty && blutzuckerMessungen.isEmpty {
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
                }
                .listRowBackground(Color.clear)
            } else {
                ForEach(gruppiertNachDatum, id: \.tag) { gruppe in
                    Section {
                        ForEach(gruppe.items) { item in
                            switch item {
                            case .schmerz(let eintrag):
                                NavigationLink(destination: PainEntryDetailView(eintrag: eintrag)) {
                                    SchmerzZeile(eintrag: eintrag)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        if eintrag.istHautEintrag {
                                            FotoManager.loeschen(dateiname: eintrag.fotoDateiname)
                                        }
                                        modelContext.delete(eintrag)
                                    } label: {
                                        Label("Löschen", systemImage: "trash")
                                    }
                                }
                            case .migraene(let anfall):
                                NavigationLink(destination: MigraeneAnfallDetailView(anfall: anfall)) {
                                    MigraeneZeile(anfall: anfall)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        NotificationManager.shared.loescheMigraeneErinnerungen(fuer: anfall.datum)
                                        modelContext.delete(anfall)
                                    } label: {
                                        Label("Löschen", systemImage: "trash")
                                    }
                                }
                            case .zyklus(let eintrag):
                                ZyklusTagesbuchZeile(eintrag: eintrag)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            modelContext.delete(eintrag)
                                        } label: {
                                            Label("Löschen", systemImage: "trash")
                                        }
                                    }
                            case .diabetes(let messung):
                                DiabetesTagesbuchZeile(messung: messung)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            modelContext.delete(messung)
                                        } label: {
                                            Label("Löschen", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    } header: {
                        Text(tagLabel(gruppe.tag))
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                            .textCase(nil)
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

    // MARK: - Sparkline Header

    private var sparklineHeader: some View {
        let cal = Calendar.current
        let heute = cal.startOfDay(for: Date())
        let tage = (0..<7).reversed().map { cal.date(byAdding: .day, value: -$0, to: heute)! }
        let alleItems: [TagesbuchItem] = eintraege.map { .schmerz($0) }
            + migraeneAnfaelle.map { .migraene($0) }
            + (zyklusModulAktiv ? zyklusEintraege.map { .zyklus($0) } : [])
            + (diabetesModulAktiv ? blutzuckerMessungen.map { .diabetes($0) } : [])

        return HStack(spacing: 0) {
            ForEach(tage, id: \.self) { tag in
                let tagItems = alleItems.filter { cal.isDate($0.datum, inSameDayAs: tag) }
                let isHeute = cal.isDateInToday(tag)

                VStack(spacing: 4) {
                    Text(tag.formatted(.dateTime.weekday(.narrow)))
                        .font(.system(size: 10))
                        .foregroundStyle(isHeute ? .primary : .secondary)

                    if tagItems.isEmpty {
                        Circle()
                            .fill(Color.secondary.opacity(0.15))
                            .frame(width: 8, height: 8)
                    } else {
                        let modulFarben = uniqueModulFarben(aus: tagItems)
                        VStack(spacing: 2) {
                            ForEach(Array(modulFarben.prefix(3).enumerated()), id: \.offset) { _, farbe in
                                Circle().fill(farbe).frame(width: 6, height: 6)
                            }
                        }
                    }

                    Text(tag.formatted(.dateTime.day()))
                        .font(.system(size: 10, weight: isHeute ? .bold : .regular))
                        .foregroundStyle(isHeute ? .primary : .secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    isHeute ? Color.secondary.opacity(0.08) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 8)
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private func uniqueModulFarben(aus items: [TagesbuchItem]) -> [Color] {
        var farben: [Color] = []
        var seen = Set<String>()
        for item in items {
            let (farbe, key): (Color, String)
            switch item {
            case .schmerz(let e) where e.koerperstelle == "Rheuma":
                (farbe, key) = (.teal, "rheuma")
            case .schmerz(let e) where e.istHautEintrag:
                (farbe, key) = (.orange, "haut")
            case .schmerz:
                (farbe, key) = (.red, "schmerz")
            case .migraene:
                (farbe, key) = (.purple, "migraene")
            case .zyklus:
                (farbe, key) = (.pink, "zyklus")
            case .diabetes:
                (farbe, key) = (.blue, "diabetes")
            }
            if seen.insert(key).inserted { farben.append(farbe) }
        }
        return farben
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ModulFilter.allCases, id: \.self) { filter in
                    let aktiv = modulFilter == filter
                    Button {
                        withAnimation { modulFilter = filter }
                    } label: {
                        Text(filter.rawValue)
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(aktiv ? filter.farbe : Color.secondary.opacity(0.12))
                            .foregroundStyle(aktiv ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Filter Sheet

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

// MARK: - Modul-Kreis

private struct ModulKreis: View {
    let farbe: Color
    let symbol: String
    let zahl: Int?

    var body: some View {
        ZStack {
            Circle()
                .fill(farbe.opacity(0.18))
                .frame(width: 40, height: 40)
            if let n = zahl {
                Text("\(n)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(farbe)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(farbe)
            }
        }
    }
}

// MARK: - Schmerz-Zeile

private struct SchmerzZeile: View {
    let eintrag: PainEntry

    private var isRheuma: Bool { eintrag.koerperstelle == "Rheuma" }
    private var isHaut: Bool   { eintrag.istHautEintrag }

    private var modulFarbe: Color {
        if isRheuma { return .teal }
        if isHaut   { return .orange }
        return .red
    }

    var body: some View {
        HStack(spacing: 12) {
            if isHaut {
                ModulKreis(farbe: .orange, symbol: "bandage.fill", zahl: nil)
            } else {
                ModulKreis(farbe: modulFarbe, symbol: "", zahl: eintrag.schmerzstaerke)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(titelText)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if !subtitelPart.isEmpty {
                        Text(subtitelPart)
                            .font(.caption).foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text("·").font(.caption).foregroundStyle(.secondary)
                    }
                    Text(eintrag.datum, style: .time)
                        .font(.caption).foregroundStyle(.secondary)
                    if let code = eintrag.wetterCode {
                        Text("·").font(.caption).foregroundStyle(.secondary)
                        Image(systemName: WetterSnapshot.symbolFuerCode(code))
                            .font(.caption).foregroundStyle(.secondary)
                    }
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
                if isRheuma && eintrag.morgensteifigkeit > 0 {
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

    private var titelText: String {
        if isHaut {
            return eintrag.hautStellen.isEmpty ? "Haut" : eintrag.hautStellen
        }
        return eintrag.koerperstelle.isEmpty ? "Körperstelle unbekannt" : eintrag.koerperstelle
    }

    private var subtitelPart: String {
        if isHaut {
            return eintrag.schmerzart.isEmpty ? "" : eintrag.schmerzart
        }
        return eintrag.schmerzart
    }
}

// MARK: - Migräne-Zeile

private struct MigraeneZeile: View {
    let anfall: MigraeneEintrag

    var body: some View {
        HStack(spacing: 12) {
            ModulKreis(farbe: .purple, symbol: "", zahl: anfall.staerke)

            VStack(alignment: .leading, spacing: 3) {
                Text(anfall.kopfschmerzTyp.isEmpty ? "Migräne" : anfall.kopfschmerzTyp)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if !anfall.charakter.isEmpty {
                        Text(anfall.charakterListe.first ?? "")
                            .font(.caption).foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text("·").font(.caption).foregroundStyle(.secondary)
                    }
                    Text(anfall.datum, style: .time)
                        .font(.caption).foregroundStyle(.secondary)
                    if let code = anfall.wetterCode {
                        Text("·").font(.caption).foregroundStyle(.secondary)
                        Image(systemName: WetterSnapshot.symbolFuerCode(code))
                            .font(.caption).foregroundStyle(.secondary)
                    }
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
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Zyklus-Zeile

struct ZyklusTagesbuchZeile: View {
    let eintrag: ZyklusEintrag
    @State private var zeigeBearbeiten = false

    var body: some View {
        Button { zeigeBearbeiten = true } label: {
            HStack(spacing: 12) {
                ModulKreis(
                    farbe: .pink,
                    symbol: eintrag.istPeriode ? "drop.fill" : "circle.dotted",
                    zahl: nil
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(eintrag.istPeriode ? "Periode" : "Zyklus-Eintrag")
                        .font(.headline)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(eintrag.datum, style: .time)
                        if !eintrag.blutungsfluss.isEmpty && eintrag.istPeriode {
                            Text("·").foregroundStyle(.secondary)
                            Text(eintrag.blutungsfluss.capitalized)
                        } else if !eintrag.symptome.isEmpty {
                            Text("·").foregroundStyle(.secondary)
                            Text(eintrag.symptome.components(separatedBy: ", ").prefix(2).joined(separator: ", "))
                                .lineLimit(1)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $zeigeBearbeiten) {
            ZyklusEintragSheet(datum: eintrag.datum, bestehend: eintrag)
        }
    }
}

// MARK: - Diabetes-Zeile

struct DiabetesTagesbuchZeile: View {
    let messung: BlutzuckerEintrag
    @State private var zeigeBearbeiten = false

    private var wertFarbe: Color {
        messung.wert < 3.9 ? .red : messung.wert <= 7.8 ? .green : .orange
    }

    var body: some View {
        Button { zeigeBearbeiten = true } label: {
            HStack(spacing: 12) {
                ModulKreis(farbe: wertFarbe, symbol: "drop.triangle.fill", zahl: nil)

                VStack(alignment: .leading, spacing: 2) {
                    Text(messung.wertText)
                        .font(.headline)
                        .foregroundStyle(wertFarbe)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(messung.datum, style: .time)
                        Text("·").foregroundStyle(.secondary)
                        Text(messung.messZeitpunkt)
                        if messung.insulinEinheiten > 0 {
                            Text("·").foregroundStyle(.secondary)
                            Text("\(String(format: "%.0f", messung.insulinEinheiten)) IE")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()

                if messung.insulinEinheiten > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "syringe.fill").font(.caption2)
                        Text("\(String(format: "%.0f", messung.insulinEinheiten)) IE").font(.caption2.bold())
                    }
                    .foregroundStyle(.blue)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $zeigeBearbeiten) {
            BlutzuckerForm(messung: messung)
        }
    }
}
