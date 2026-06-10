import SwiftUI

struct DashboardAnpassenView: View {
    @Binding var kacheln: [KachelKonfiguration]
    @Environment(\.dismiss) private var dismiss
    @State private var editMode: EditMode = .inactive
    @State private var korrelationPickerAnzeigen = false

    private var analyseHinzufuegbar: [KachelTyp] {
        let bereitsIds = Set(kacheln.map(\.id))
        return [
            .wetterSchmerz, .stressSchmerz, .schlafSchmerz,
            .tageszeitVerteilung, .koerperstellen, .schmerzarten,
            .stimmungsTrend, .midasKachel
        ].filter { !bereitsIds.contains($0.rawValue) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach($kacheln) { $kachel in
                        HStack(spacing: 12) {
                            Image(systemName: kachel.typ.symbol)
                                .foregroundStyle(kachelFarbe(kachel.typ))
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(kachel.anzeigeTitel).font(.subheadline)
                                Text(kachel.typ.abschnitt)
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                withAnimation { kachel.sichtbar.toggle() }
                            } label: {
                                Image(systemName: kachel.sichtbar ? "eye.fill" : "eye.slash")
                                    .foregroundStyle(kachel.sichtbar ? .primary : .secondary.opacity(0.4))
                            }
                            .buttonStyle(.plain)
                        }
                        .opacity(kachel.sichtbar ? 1 : 0.5)
                    }
                    .onMove { kacheln.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { offsets in
                        let loeschbar = offsets.filter { !KachelTyp.basisKacheln.contains(kacheln[$0].typ) }
                        withAnimation { kacheln.remove(atOffsets: IndexSet(loeschbar)) }
                    }
                } header: {
                    HStack {
                        Text("Reihenfolge")
                        Spacer()
                        Text("Sichtbar").font(.caption2)
                    }
                } footer: {
                    Text("Tippe auf das Auge zum Ein-/Ausblenden. Im Bearbeiten-Modus: Kacheln verschieben oder Analyse-Kacheln löschen (Wischen).")
                        .font(.caption2)
                }

                if !analyseHinzufuegbar.isEmpty {
                    Section("Analyse hinzufügen") {
                        ForEach(analyseHinzufuegbar, id: \.self) { typ in
                            Button {
                                withAnimation {
                                    kacheln.append(KachelKonfiguration(id: typ.rawValue, typ: typ))
                                }
                            } label: {
                                HStack {
                                    Image(systemName: typ.symbol)
                                        .foregroundStyle(kachelFarbe(typ))
                                        .frame(width: 24)
                                    Text(typ.titel).font(.subheadline).foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "plus.circle.fill").foregroundStyle(.teal)
                                }
                            }
                        }
                    }
                }

                Section("Eigene Korrelation") {
                    Button {
                        korrelationPickerAnzeigen = true
                    } label: {
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                                .foregroundStyle(.indigo).frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Neue Korrelation konfigurieren")
                                    .font(.subheadline).foregroundStyle(.primary)
                                Text("z.B. Wetter ↔ Schmerzstärke")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "plus.circle.fill").foregroundStyle(.indigo)
                        }
                    }
                }

                Section {
                    Button("Standard wiederherstellen", role: .destructive) {
                        withAnimation { kacheln = KachelKonfiguration.standard }
                    }
                }
            }
            .environment(\.editMode, $editMode)
            .navigationTitle("Dashboard anpassen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(editMode == .active ? "Fertig" : "Bearbeiten") {
                        withAnimation {
                            editMode = editMode == .active ? .inactive : .active
                        }
                    }
                }
            }
            .sheet(isPresented: $korrelationPickerAnzeigen) {
                KorrelationsPickerView { neu in
                    withAnimation { kacheln.append(neu) }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func kachelFarbe(_ typ: KachelTyp) -> Color {
        switch typ {
        case .schmerzUebersicht, .hautveraenderung, .tageszeitVerteilung: return .orange
        case .schmerzverlauf, .medikamente, .schmerzarten: return .blue
        case .stimmungStress, .zyklus, .stimmungsTrend: return .pink
        case .schnellLinks, .konfigKorrelation: return .indigo
        case .wetterSchmerz: return .cyan
        case .stressSchmerz: return .yellow
        case .schlafSchmerz: return .purple
        case .koerperstellen: return .teal
        case .midasKachel: return .purple
        }
    }
}

// MARK: - Korrelations-Picker

struct KorrelationsPickerView: View {
    var onHinzufuegen: (KachelKonfiguration) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var xVariable = "wetter"
    @State private var yVariable = "schmerzstaerke"

    let xOptionen: [(id: String, name: String, symbol: String, farbe: Color)] = [
        ("wetter",    "Wetter",    "cloud.sun.fill",  .cyan),
        ("stress",    "Stress",    "bolt.fill",       .yellow),
        ("schlaf",    "Schlaf",    "moon.zzz.fill",   .purple),
        ("stimmung",  "Stimmung",  "heart.fill",      .pink),
        ("tageszeit", "Tageszeit", "clock.fill",      .orange),
        ("wochentag", "Wochentag", "calendar",        .blue),
    ]

    let yOptionen: [(id: String, name: String, symbol: String, farbe: Color)] = [
        ("schmerzstaerke", "Schmerzstärke", "waveform.path.ecg", .orange),
        ("stimmung",       "Stimmung",      "heart.fill",        .pink),
        ("stress",         "Stress",        "bolt.fill",         .yellow),
    ]

    private var vorschauTitel: String {
        let x = xOptionen.first { $0.id == xVariable }?.name ?? xVariable
        let y = yOptionen.first { $0.id == yVariable }?.name ?? yVariable
        return "\(x) & \(y)"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Einflussfaktor (X-Achse)") {
                    ForEach(xOptionen, id: \.id) { opt in
                        Button {
                            xVariable = opt.id
                        } label: {
                            HStack {
                                Image(systemName: opt.symbol)
                                    .foregroundStyle(opt.farbe).frame(width: 24)
                                Text(opt.name).foregroundStyle(.primary)
                                Spacer()
                                if xVariable == opt.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                }

                Section("Ergebnis (Y-Achse)") {
                    ForEach(yOptionen, id: \.id) { opt in
                        Button {
                            yVariable = opt.id
                        } label: {
                            HStack {
                                Image(systemName: opt.symbol)
                                    .foregroundStyle(opt.farbe).frame(width: 24)
                                Text(opt.name).foregroundStyle(.primary)
                                Spacer()
                                if yVariable == opt.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                }

                Section("Vorschau") {
                    HStack(spacing: 12) {
                        Image(systemName: "slider.horizontal.3").foregroundStyle(.indigo)
                        Text(vorschauTitel).font(.headline)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Eigene Korrelation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hinzufügen") {
                        let uid = String(UUID().uuidString.prefix(8))
                        let id = "konfigKorrelation_\(xVariable)_\(yVariable)_\(uid)"
                        let kachel = KachelKonfiguration(
                            id: id,
                            typ: .konfigKorrelation,
                            xVariable: xVariable,
                            yVariable: yVariable,
                            benutzertitel: vorschauTitel
                        )
                        onHinzufuegen(kachel)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}
