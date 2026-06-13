import SwiftUI

struct TagesDetailSheet: View {
    let datum: Date
    let eintraege: [PainEntry]
    @Environment(\.dismiss) private var dismiss

    private var tagesEintraege: [PainEntry] {
        eintraege
            .filter { !$0.istHautEintrag && Calendar.current.isDate($0.datum, inSameDayAs: datum) }
            .sorted { $0.datum < $1.datum }
    }

    private func schmerzFarbe(_ w: Int) -> Color {
        w <= 3 ? .green : w <= 6 ? Color(red: 0.95, green: 0.75, blue: 0) : w <= 8 ? .orange : .red
    }

    var body: some View {
        NavigationStack {
            Group {
                if tagesEintraege.isEmpty {
                    ContentUnavailableView(
                        "Keine Einträge",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("Für diesen Tag wurden keine Schmerzeinträge erfasst.")
                    )
                } else {
                    List(tagesEintraege) { eintrag in
                        eintragZeile(eintrag)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(datum.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "de_DE"))))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    private func eintragZeile(_ e: PainEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(e.schmerzstaerke)")
                        .font(.title2.bold())
                        .foregroundStyle(schmerzFarbe(e.schmerzstaerke))
                    Text("/ 10")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(e.datum.formatted(.dateTime.hour().minute()))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !e.koerperstelle.isEmpty {
                Label(e.koerperstelle, systemImage: "location")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !e.ausloeser.isEmpty {
                Label(e.ausloeser, systemImage: "bolt")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !e.begleiterscheinungen.isEmpty {
                Label(e.begleiterscheinungen, systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !e.massnahmen.isEmpty {
                Label(e.massnahmen, systemImage: "cross.case")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !e.notizen.isEmpty {
                Text(e.notizen)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 4)
    }
}
