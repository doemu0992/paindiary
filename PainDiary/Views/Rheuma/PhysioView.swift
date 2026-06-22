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
        .navigationBarTitleDisplayMode(.large)
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
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
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

    @State private var schritt = 0
    private let maxSchritt = 1
    private let pflichtSchritte: Set<Int> = [0, 1]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.teal.opacity(0.15)).frame(height: 3)
                        Capsule().fill(Color.teal)
                            .frame(width: geo.size.width * CGFloat(schritt + 1) / CGFloat(maxSchritt + 1), height: 3)
                            .animation(.easeInOut(duration: 0.3), value: schritt)
                    }
                }
                .frame(height: 3).padding(.horizontal).padding(.top, 10)

                Group {
                    switch schritt {
                    case 0: schritt0
                    default: schritt1
                    }
                }
                .frame(maxHeight: .infinity)

                navigationsLeiste
            }
            .navigationTitle(schritt == 0 ? "Neue Session" : "Bewertung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
            }
        }
    }

    private var schritt0: some View {
        ScrollView {
            VStack(spacing: 20) {
                schrittHeader(symbol: "figure.walk", titel: "Physiotherapie", untertitel: "Session-Daten erfassen")

                VStack(spacing: 0) {
                    HStack {
                        Text("Datum").foregroundStyle(.secondary)
                        Spacer()
                        DatePicker("", selection: $datum, displayedComponents: [.date]).labelsHidden()
                    }
                    .font(.subheadline).padding(16)
                    Divider().padding(.leading, 16)
                    HStack {
                        Text("Dauer").foregroundStyle(.secondary)
                        Spacer()
                        Text("\(dauerMinuten) min").font(.subheadline.bold())
                        Stepper("", value: $dauerMinuten, in: 5...180, step: 5).labelsHidden()
                    }
                    .font(.subheadline).padding(16)
                    Divider().padding(.leading, 16)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Übungsart").font(.subheadline).foregroundStyle(.secondary)
                            .padding(.horizontal, 16).padding(.top, 12)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                            ForEach(PhysioTyp.allCases, id: \.self) { t in
                                let sel = typ == t
                                Button { typ = t } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: t.symbol).font(.title3)
                                        Text(t.rawValue).font(.caption2).multilineTextAlignment(.center)
                                    }
                                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                                    .background(sel ? Color.teal : Color(.tertiarySystemGroupedBackground),
                                                in: RoundedRectangle(cornerRadius: 10))
                                    .foregroundStyle(sel ? .white : .primary)
                                    .animation(.easeInOut(duration: 0.15), value: sel)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16).padding(.bottom, 12)
                    }
                }
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal).padding(.vertical, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground))
    }

    private var schritt1: some View {
        ScrollView {
            VStack(spacing: 20) {
                schrittHeader(symbol: "chart.bar.fill", titel: "Bewertung", untertitel: "Schmerzentwicklung & Notizen")

                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Schmerz vorher").foregroundStyle(.secondary)
                            Spacer()
                            Text("\(schmerzVorher)").font(.headline.bold()).foregroundStyle(schmerzFarbe(schmerzVorher))
                        }
                        .font(.subheadline)
                        Slider(value: Binding(get: { Double(schmerzVorher) }, set: { schmerzVorher = Int($0) }),
                               in: 0...10, step: 1).tint(schmerzFarbe(schmerzVorher))
                    }
                    .padding(16)
                    Divider().padding(.leading, 16)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Schmerz nachher").foregroundStyle(.secondary)
                            Spacer()
                            Text("\(schmerzNachher)").font(.headline.bold()).foregroundStyle(schmerzFarbe(schmerzNachher))
                        }
                        .font(.subheadline)
                        Slider(value: Binding(get: { Double(schmerzNachher) }, set: { schmerzNachher = Int($0) }),
                               in: 0...10, step: 1).tint(schmerzFarbe(schmerzNachher))
                    }
                    .padding(16)
                    Divider().padding(.leading, 16)
                    TextField("Optionale Notizen", text: $notizen, axis: .vertical)
                        .lineLimit(3...6).font(.subheadline).padding(16)
                }
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal).padding(.vertical, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground))
    }

    private var navigationsLeiste: some View {
        HStack(spacing: 12) {
            if schritt > 0 {
                Button { withAnimation { schritt -= 1 } } label: {
                    Text("Zurück").font(.subheadline.bold()).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
            }
            if !pflichtSchritte.contains(schritt) && schritt < maxSchritt {
                Button { withAnimation { schritt += 1 } } label: {
                    Text("Überspringen").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            if schritt < maxSchritt {
                Button { withAnimation { schritt += 1 } } label: {
                    Text("Weiter ›").font(.subheadline.bold()).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color.teal, in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
            } else {
                Button { speichern() } label: {
                    Label("Speichern", systemImage: "checkmark").font(.subheadline.bold()).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color.teal, in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
            }
        }
        .padding().background(.ultraThinMaterial)
    }

    private func schrittHeader(symbol: String, titel: String, untertitel: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 32)).foregroundStyle(.teal)
            Text(titel).font(.title3.bold())
            Text(untertitel).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.bottom, 4)
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
