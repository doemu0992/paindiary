import SwiftUI
import SwiftData

struct ZyklusView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ZyklusEintrag.datum, order: .reverse) private var eintraege: [ZyklusEintrag]
    @State private var eintragAnzeigen = false
    @State private var ausgewaehlterTyp = "Periode"

    private let typen = ["Periode", "Leicht", "Mittel", "Stark", "Spotting", "PMS", "Eisprung"]

    private var zyklusLaenge: Int? {
        let perioden = eintraege.filter { $0.typ == "Periode" }
        guard perioden.count >= 2 else { return nil }
        let diff = perioden[1].datum.timeIntervalSince(perioden[0].datum)
        return abs(Int(diff / 86400))
    }

    private var letzterPeriodenbeginn: Date? {
        eintraege.first { $0.typ == "Periode" }?.datum
    }

    private var aktuellerZyklusTag: Int? {
        guard let letzter = letzterPeriodenbeginn else { return nil }
        return Calendar.current.dateComponents([.day], from: letzter, to: Date()).day.map { $0 + 1 }
    }

    var body: some View {
        List {
            statistikSektion
            erfassenSektion
            verlaufSektion
        }
        .navigationTitle("Zyklus")
        .sheet(isPresented: $eintragAnzeigen) {
            ZyklusEintragFormView()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { eintragAnzeigen = true } label: {
                    Label("Eintrag", systemImage: "plus")
                }
            }
        }
    }

    private var statistikSektion: some View {
        Section("Übersicht") {
            if let tag = aktuellerZyklusTag {
                LabeledContent("Aktueller Zyklustag", value: "Tag \(tag)")
            }
            if let laenge = zyklusLaenge {
                LabeledContent("Durchschnittliche Länge", value: "\(laenge) Tage")
            }
            if let letzter = letzterPeriodenbeginn {
                LabeledContent("Letzte Periode", value: letzter.formatted(.dateTime.day().month().year()))
            }
            if eintraege.isEmpty {
                Text("Noch keine Einträge. Tippe auf + um zu beginnen.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var erfassenSektion: some View {
        Section("Schnell erfassen") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(typen, id: \.self) { typ in
                        Button {
                            let neu = ZyklusEintrag(datum: Date(), typ: typ)
                            modelContext.insert(neu)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: symbolFuerTyp(typ))
                                    .font(.caption)
                                Text(typ)
                                    .font(.subheadline)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(farbeFuerTyp(typ).opacity(0.15))
                            .foregroundStyle(farbeFuerTyp(typ))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var verlaufSektion: some View {
        Section("Verlauf") {
            ForEach(eintraege as [ZyklusEintrag]) { eintrag in
                HStack(spacing: 12) {
                    Image(systemName: symbolFuerTyp(eintrag.typ))
                        .foregroundStyle(farbeFuerTyp(eintrag.typ))
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(eintrag.typ).font(.subheadline).fontWeight(.medium)
                        Text(eintrag.datum.formatted(.dateTime.day().month().year().hour().minute()))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if !eintrag.notizen.isEmpty {
                        Spacer()
                        Text(eintrag.notizen)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.vertical, 2)
            }
            .onDelete { idx in
                idx.forEach { modelContext.delete(eintraege[$0]) }
            }
        }
    }

    private func symbolFuerTyp(_ typ: String) -> String {
        switch typ {
        case "Periode":  return "drop.fill"
        case "Leicht":   return "drop"
        case "Spotting": return "drop.halffull"
        case "PMS":      return "cloud.drizzle"
        case "Eisprung": return "circle.fill"
        default:         return "drop.fill"
        }
    }

    private func farbeFuerTyp(_ typ: String) -> Color {
        switch typ {
        case "Periode":  return .red
        case "Leicht":   return .pink
        case "Mittel":   return .orange
        case "Stark":    return .red
        case "Spotting": return .brown
        case "PMS":      return .purple
        case "Eisprung": return .blue
        default:         return .red
        }
    }
}

private struct ZyklusEintragFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var datum = Date()
    @State private var typ = "Periode"
    @State private var notizen = ""

    private let typen = ["Periode", "Leicht", "Mittel", "Stark", "Spotting", "PMS", "Eisprung"]

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Datum & Uhrzeit", selection: $datum)
                Picker("Typ", selection: $typ) {
                    ForEach(typen, id: \.self) { Text($0).tag($0) }
                }
                Section("Notizen") {
                    TextEditor(text: $notizen).frame(minHeight: 60)
                }
            }
            .navigationTitle("Zyklus-Eintrag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        let neu = ZyklusEintrag(datum: datum, typ: typ, notizen: notizen)
                        modelContext.insert(neu)
                        dismiss()
                    }
                }
            }
        }
    }
}
