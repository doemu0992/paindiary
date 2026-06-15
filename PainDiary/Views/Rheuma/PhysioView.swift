import SwiftUI
import SwiftData

struct PhysioView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PhysioSession.datum, order: .reverse) private var sessions: [PhysioSession]

    @State private var zeigeForm = false

    var body: some View {
        List {
            if !sessions.isEmpty {
                Section {
                    statistikKarte
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            }

            Section(sessions.isEmpty ? "" : "Einträge") {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "Noch keine Sessions erfasst",
                        systemImage: "figure.walk.motion",
                        description: Text("Tippe auf + um eine Physiotherapie-Session einzutragen.")
                    )
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(sessions) { s in
                        PhysioZeile(session: s)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    modelContext.delete(s)
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .navigationTitle("Physiotherapie")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { zeigeForm = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $zeigeForm) { PhysioFormView() }
    }

    private var statistikKarte: some View {
        let gesamtMinuten = sessions.map(\.dauerMinuten).reduce(0, +)
        let gesamtStunden = Double(gesamtMinuten) / 60.0
        let diffs = sessions.map { $0.schmerzNachher - $0.schmerzVorher }
        let avgDiff = diffs.isEmpty ? 0.0 : Double(diffs.reduce(0, +)) / Double(diffs.count)

        return VStack(alignment: .leading, spacing: 12) {
            Label("Statistik", systemImage: "chart.bar.fill")
                .font(.headline).foregroundStyle(.teal)
            Divider()
            HStack(spacing: 0) {
                statPill("\(sessions.count)", label: "Sessions", farbe: .teal)
                Divider().frame(height: 40)
                statPill(String(format: "%.1f h", gesamtStunden), label: "Gesamtdauer", farbe: .teal)
                Divider().frame(height: 40)
                let diffFarbe: Color = avgDiff < 0 ? .green : avgDiff == 0 ? .secondary : .orange
                let diffText = avgDiff == 0
                    ? "±0"
                    : String(format: "%+.1f", avgDiff)
                statPill(diffText, label: "Ø Schmerzveränd.", farbe: diffFarbe)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func statPill(_ wert: String, label: String, farbe: Color) -> some View {
        VStack(spacing: 4) {
            Text(wert).font(.title2.bold()).foregroundStyle(farbe)
            Text(label).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct PhysioZeile: View {
    let session: PhysioSession

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: session.typSymbol)
                .font(.title2)
                .foregroundStyle(.teal)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(session.typ).font(.subheadline.bold())
                HStack(spacing: 4) {
                    Text(session.datum, style: .date).font(.caption).foregroundStyle(.secondary)
                    Text("·").font(.caption).foregroundStyle(.secondary)
                    Text("\(session.dauerMinuten) min").font(.caption).foregroundStyle(.secondary)
                }
                if session.schmerzVorher != 0 || session.schmerzNachher != 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right")
                            .font(.caption2).foregroundStyle(.secondary)
                        Text("Schmerz: vor \(session.schmerzVorher) → nach \(session.schmerzNachher)")
                            .font(.caption)
                            .foregroundStyle(session.schmerzNachher < session.schmerzVorher ? .green : .secondary)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Form

struct PhysioFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var datum          = Date()
    @State private var typ            = PhysioTyp.physiotherapie
    @State private var dauerMinuten   = 30
    @State private var uebungen       = ""
    @State private var schmerzVorher  = 0
    @State private var schmerzNachher = 0
    @State private var notizen        = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Session") {
                    DatePicker("Datum", selection: $datum, displayedComponents: [.date])

                    Picker("Typ", selection: $typ) {
                        ForEach(PhysioTyp.allCases, id: \.self) { t in
                            Label(t.rawValue, systemImage: t.symbol).tag(t)
                        }
                    }

                    Stepper("Dauer: \(dauerMinuten) min",
                            value: $dauerMinuten, in: 5...180, step: 5)
                }

                Section("Übungen") {
                    TextField("Durchgeführte Übungen", text: $uebungen, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Schmerzentwicklung") {
                    HStack {
                        Text("Vorher")
                        Spacer()
                        Text("\(schmerzVorher)").font(.headline.bold()).foregroundStyle(schmerzFarbe(schmerzVorher))
                    }
                    Slider(value: Binding(
                        get: { Double(schmerzVorher) },
                        set: { schmerzVorher = Int($0) }
                    ), in: 0...10, step: 1)
                    .tint(schmerzFarbe(schmerzVorher))

                    HStack {
                        Text("Nachher")
                        Spacer()
                        Text("\(schmerzNachher)").font(.headline.bold()).foregroundStyle(schmerzFarbe(schmerzNachher))
                    }
                    Slider(value: Binding(
                        get: { Double(schmerzNachher) },
                        set: { schmerzNachher = Int($0) }
                    ), in: 0...10, step: 1)
                    .tint(schmerzFarbe(schmerzNachher))
                }

                Section("Notizen") {
                    TextField("Optionale Notizen", text: $notizen, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Neue Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Speichern") { speichern() } }
            }
        }
    }

    private func schmerzFarbe(_ wert: Int) -> Color {
        switch wert {
        case 0...3: return .green
        case 4...6: return .orange
        default:    return .red
        }
    }

    private func speichern() {
        let neu = PhysioSession(datum: datum, typ: typ.rawValue)
        neu.dauerMinuten   = dauerMinuten
        neu.uebungen       = uebungen
        neu.schmerzVorher  = schmerzVorher
        neu.schmerzNachher = schmerzNachher
        neu.notizen        = notizen
        modelContext.insert(neu)
        dismiss()
    }
}
