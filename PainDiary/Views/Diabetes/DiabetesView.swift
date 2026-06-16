import SwiftUI
import SwiftData

struct DiabetesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BlutzuckerEintrag.datum, order: .reverse) private var messungen: [BlutzuckerEintrag]

    @State private var zeigeForm = false
    @State private var bearbeitet: BlutzuckerEintrag? = nil

    private var messungen30: [BlutzuckerEintrag] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return messungen.filter { $0.datum >= cutoff }
    }

    var body: some View {
        List {
            statistikSektion

            Section("Weiterführend") {
                NavigationLink(destination: LaborwerteView()) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Laborwerte")
                            Text("HbA1c, Nierenwerte, Blutbild")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "testtube.2").foregroundStyle(.blue)
                    }
                }
            }

            if messungen.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Keine Messungen",
                        systemImage: "drop.fill",
                        description: Text("Tippe auf + um eine Blutzuckermessung einzutragen.")
                    )
                    .listRowSeparator(.hidden)
                }
            } else {
                Section("Messungen") {
                    ForEach(messungen) { m in
                        BlutzuckerZeile(messung: m)
                            .contentShape(Rectangle())
                            .onTapGesture { bearbeitet = m }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    modelContext.delete(m)
                                } label: { Label("Löschen", systemImage: "trash") }
                                Button { bearbeitet = m } label: { Label("Bearbeiten", systemImage: "pencil") }
                                    .tint(.blue)
                            }
                    }
                    .onDelete { idx in idx.forEach { modelContext.delete(messungen[$0]) } }
                }
            }
        }
        .navigationTitle("Diabetes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { zeigeForm = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $zeigeForm) { BlutzuckerForm() }
        .sheet(item: $bearbeitet) { BlutzuckerForm(messung: $0) }
    }

    // MARK: - Stats

    private var statistikSektion: some View {
        Section {
            let nuechtern = messungen30.filter { $0.messZeitpunkt == "Nüchtern" && $0.wert > 0 }
            let avgNuechtern: Double? = nuechtern.isEmpty ? nil
                : nuechtern.map(\.wert).reduce(0, +) / Double(nuechtern.count)
            let imZiel = messungen30.filter(\.zielbereich).count
            let pctZiel = messungen30.isEmpty ? 0
                : Int(Double(imZiel) / Double(messungen30.count) * 100)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                DiabetesStatCard(
                    wert: avgNuechtern.map { String(format: "%.1f", $0) } ?? "–",
                    label: "Ø Nüchtern mmol/L",
                    farbe: nuechternFarbe(avgNuechtern)
                )
                DiabetesStatCard(
                    wert: messungen.first.map { String(format: "%.1f", $0.wert) } ?? "–",
                    label: "Letzte Messung",
                    farbe: messungen.first.map { wertFarbe($0.wert) } ?? .secondary
                )
                DiabetesStatCard(
                    wert: "\(messungen30.count)",
                    label: "Messungen (30 T.)",
                    farbe: .secondary
                )
                DiabetesStatCard(
                    wert: messungen30.isEmpty ? "–" : "\(pctZiel)%",
                    label: "Im Zielbereich",
                    farbe: pctZiel >= 70 ? .green : .orange
                )
            }
            .padding(.vertical, 4)
        }
    }

    private func nuechternFarbe(_ wert: Double?) -> Color {
        guard let w = wert else { return .secondary }
        switch w {
        case ..<3.9:    return .red
        case 3.9..<6.0: return .green
        case 6.0..<7.0: return .orange
        default:        return .red
        }
    }

    private func wertFarbe(_ wert: Double) -> Color {
        switch wert {
        case ..<3.9:   return .red
        case 3.9..<7.8: return .green
        default:        return .orange
        }
    }
}

// MARK: - Zeile

private struct BlutzuckerZeile: View {
    let messung: BlutzuckerEintrag

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(farbe.opacity(0.15)).frame(width: 46, height: 46)
                VStack(spacing: 1) {
                    Text(String(format: "%.1f", messung.wert))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(farbe)
                    Text("mmol").font(.system(size: 8)).foregroundStyle(farbe.opacity(0.7))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(messung.datum, style: .date).font(.subheadline.bold())
                    Text(messung.datum, style: .time).font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Text(messung.messZeitpunkt).font(.caption).foregroundStyle(.secondary)
                    Text(messung.bewertung)
                        .font(.caption2.bold())
                        .foregroundStyle(farbe)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(farbe.opacity(0.12)).clipShape(Capsule())
                }
                if messung.insulinEinheiten > 0 {
                    Text(String(format: "%.0f IE Insulin (%@)", messung.insulinEinheiten, messung.insulinTyp))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }

    private var farbe: Color {
        switch messung.wert {
        case ..<3.9:    return .red
        case 3.9..<7.8: return .green
        default:        return .orange
        }
    }
}

// MARK: - Stat Card

private struct DiabetesStatCard: View {
    let wert: String; let label: String; let farbe: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(wert).font(.title2.bold()).foregroundStyle(farbe)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(farbe.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Form

struct BlutzuckerForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var messung: BlutzuckerEintrag? = nil
    var onGespeichert: (() -> Void)? = nil

    @State private var datum = Date()
    @State private var wert = 5.5
    @State private var messZeitpunkt = "Nüchtern"
    @State private var erfasseInsulin = false
    @State private var insulinEinheiten = 0.0
    @State private var insulinTyp = "Kurzzeit"
    @State private var kohlenhydrate = 0
    @State private var notizen = ""

    private let zeitpunkte = ["Nüchtern", "Vor Essen", "2h nach Essen", "Vor Schlaf", "Beliebig"]
    private let insulinTypen = ["Kurzzeit", "Langzeit", "Mischung"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Messung") {
                    DatePicker("Datum & Uhrzeit", selection: $datum)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(String(format: "Blutzucker: %.1f mmol/L", wert))
                            Spacer()
                            Text(bewertungLabel)
                                .font(.caption.bold())
                                .foregroundStyle(bewertungFarbe)
                        }
                        Slider(value: $wert, in: 1.0...30.0, step: 0.1).tint(bewertungFarbe)
                    }

                    Picker("Messzeitpunkt", selection: $messZeitpunkt) {
                        ForEach(zeitpunkte, id: \.self) { Text($0).tag($0) }
                    }
                }

                Section("Insulin") {
                    Toggle("Insulin injiziert", isOn: $erfasseInsulin)
                    if erfasseInsulin {
                        Stepper(String(format: "%.0f IE", insulinEinheiten),
                                value: $insulinEinheiten, in: 0...100, step: 0.5)
                        Picker("Typ", selection: $insulinTyp) {
                            ForEach(insulinTypen, id: \.self) { Text($0).tag($0) }
                        }
                    }
                }

                Section("Mahlzeit") {
                    Stepper("\(kohlenhydrate) g Kohlenhydrate", value: $kohlenhydrate, in: 0...300, step: 5)
                }

                Section("Notizen") {
                    TextEditor(text: $notizen).frame(minHeight: 60)
                }
            }
            .navigationTitle(messung == nil ? "Neue Messung" : "Messung bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { speichern() }.disabled(wert <= 0)
                }
            }
        }
        .onAppear { laden() }
    }

    private var bewertungLabel: String {
        switch wert {
        case ..<3.9:    return "Hypo ⚠"
        case 3.9..<6.0: return "Normal ✓"
        case 6.0..<7.8: return "Erhöht"
        default:        return "Zu hoch"
        }
    }

    private var bewertungFarbe: Color {
        switch wert {
        case ..<3.9:    return .red
        case 3.9..<7.8: return .green
        default:        return .orange
        }
    }

    private func laden() {
        guard let m = messung else { return }
        datum = m.datum; wert = m.wert; messZeitpunkt = m.messZeitpunkt
        erfasseInsulin = m.insulinEinheiten > 0
        insulinEinheiten = m.insulinEinheiten
        insulinTyp = m.insulinTyp.isEmpty ? "Kurzzeit" : m.insulinTyp
        kohlenhydrate = m.kohlenhydrate; notizen = m.notizen
    }

    private func speichern() {
        if let m = messung {
            m.datum = datum; m.wert = wert; m.messZeitpunkt = messZeitpunkt
            m.insulinEinheiten = erfasseInsulin ? insulinEinheiten : 0
            m.insulinTyp = erfasseInsulin ? insulinTyp : ""
            m.kohlenhydrate = kohlenhydrate; m.notizen = notizen
        } else {
            let neu = BlutzuckerEintrag(
                datum: datum, wert: wert, messZeitpunkt: messZeitpunkt,
                insulinEinheiten: erfasseInsulin ? insulinEinheiten : 0,
                insulinTyp: erfasseInsulin ? insulinTyp : "",
                kohlenhydrate: kohlenhydrate, notizen: notizen
            )
            modelContext.insert(neu)
        }
        onGespeichert?()
        dismiss()
    }
}
