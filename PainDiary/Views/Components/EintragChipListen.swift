import SwiftUI
import SwiftData

/// Darstellung eines `PainEntry` als Chip (modulabhängig, vom Aufrufer geliefert).
struct EintragChipInhalt {
    var zahl: Int? = nil
    var symbol: String? = nil
    let titel: String
    let untertitel: String
    var hervorgehoben = false
}

/// Beschriftung von Tagen („Heute", „Gestern", „Mo. 5. Okt.").
enum TagBeschriftung {
    static func kurz(_ tag: DayKey, heute: DayKey = .heute()) -> String {
        if tag == heute { return "Heute" }
        if tag.tage(bis: heute) == 1 { return "Gestern" }
        return tag.beginn().formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    static func lang(_ tag: DayKey, heute: DayKey = .heute()) -> String {
        if tag == heute { return "Heute" }
        if tag.tage(bis: heute) == 1 { return "Gestern" }
        return tag.beginn().formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    /// „Heute 08:12" / „Gestern 21:40" — Tag und Uhrzeit eines Eintrags.
    static func tagUndZeit(_ eintrag: PainEntry) -> String {
        "\(kurz(eintrag.tag)) \(eintrag.datum.formatted(date: .omitted, time: .shortened))"
    }
}

/// Ein Eintrag als Glas-Chip, der zur Detailansicht führt. Löschen per Kontextmenü (über `EintragLoeschService`).
struct EintragChipLink: View {
    let eintrag: PainEntry
    let tint: Color
    let inhalt: EintragChipInhalt
    var volleBreite = false

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationLink(destination: PainEntryDetailView(eintrag: eintrag)) {
            GlassEintragChip(
                zahl: inhalt.zahl,
                symbol: inhalt.symbol,
                titel: inhalt.titel,
                untertitel: inhalt.untertitel,
                tint: tint,
                hervorgehoben: inhalt.hervorgehoben,
                volleBreite: volleBreite
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                EintragLoeschService(context: modelContext).loesche(eintrag)
            } label: { Label("Löschen", systemImage: "trash") }
        }
    }
}

/// Horizontal scrollbarer Streifen der letzten Einträge.
struct EintragChipStreifen: View {
    let eintraege: [PainEntry]
    let tint: Color
    var maximal = 8
    let inhalt: (PainEntry) -> EintragChipInhalt

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(eintraege.prefix(maximal)) { eintrag in
                    EintragChipLink(eintrag: eintrag, tint: tint, inhalt: inhalt(eintrag))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .padding(.horizontal, -16)
    }
}

/// Verlauf: pro Tag eine Glas-Karte mit vollbreiten Chips.
struct EintragTageskarten: View {
    let eintraege: [PainEntry]
    let tint: Color
    var leerText = "Noch keine Einträge"
    let inhalt: (PainEntry) -> EintragChipInhalt

    private var gruppiert: [(tag: DayKey, items: [PainEntry])] {
        Dictionary(grouping: eintraege, by: \.tag)
            .sorted { $0.key > $1.key }
            .map { (tag: $0.key, items: $0.value.sorted { $0.datum > $1.datum }) }
    }

    var body: some View {
        LazyVStack(spacing: 12) {
            if eintraege.isEmpty {
                Text(leerText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .glassCard(radius: 22, padding: 20)
            }
            ForEach(gruppiert, id: \.tag) { gruppe in
                VStack(alignment: .leading, spacing: 10) {
                    Text(TagBeschriftung.lang(gruppe.tag)).font(.headline)
                    ForEach(gruppe.items) { eintrag in
                        EintragChipLink(eintrag: eintrag, tint: tint, inhalt: inhalt(eintrag), volleBreite: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard(radius: 24, padding: 16)
            }
        }
    }
}

/// Abschnittskopf „Zuletzt" mit „Alle ansehen".
struct ZuletztKopf: View {
    var titel = "Zuletzt"
    let alleAnsehen: () -> Void

    var body: some View {
        HStack {
            Text(titel).font(.title3.bold())
            Spacer()
            Button("Alle ansehen", action: alleAnsehen)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }
}
