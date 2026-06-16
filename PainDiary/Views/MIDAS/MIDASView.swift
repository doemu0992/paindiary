import SwiftUI
import SwiftData
import Charts

struct MIDASView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MIDASBewertung.datum, order: .reverse) private var bewertungen: [MIDASBewertung]
    @State private var zeigeForm = false

    var body: some View {
        List {
            if let letzter = bewertungen.first {
                Section {
                    scoreKarte(letzter)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            }

            if bewertungen.count >= 2 {
                Section("Verlauf") {
                    let daten = bewertungen.sorted { $0.datum < $1.datum }
                    Chart(daten) { b in
                        LineMark(
                            x: .value("Datum", b.datum, unit: .day),
                            y: .value("MIDAS", b.score)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Color.purple)
                        PointMark(
                            x: .value("Datum", b.datum, unit: .day),
                            y: .value("MIDAS", b.score)
                        )
                        .foregroundStyle(Color.purple)
                    }
                    .chartYScale(domain: 0...50)
                    .chartYAxis {
                        AxisMarks(values: [0, 5, 10, 20, 30]) { v in
                            AxisGridLine()
                            AxisValueLabel { if let i = v.as(Int.self) { Text("\(i)") } }
                        }
                    }
                    .frame(height: 140)
                    .padding(.vertical, 4)
                }
            }

            Section {
                infoBox
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)

            Section(bewertungen.isEmpty ? "" : "Einträge") {
                if bewertungen.isEmpty {
                    ContentUnavailableView(
                        "Noch kein MIDAS erfasst",
                        systemImage: "list.clipboard.fill",
                        description: Text("Tippe auf + um den Fragebogen auszufüllen.")
                    )
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(bewertungen) { b in
                        MIDASZeile(bewertung: b)
                    }
                    .onDelete { idx in idx.forEach { modelContext.delete(bewertungen[$0]) } }
                }
            }
        }
        .navigationTitle("MIDAS-Score")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { zeigeForm = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $zeigeForm) { MIDASFragebogenView() }
    }

    @ViewBuilder
    private func scoreKarte(_ b: MIDASBewertung) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Letzter MIDAS-Score", systemImage: "list.clipboard.fill")
                .font(.headline).foregroundStyle(.purple)
            Divider()
            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("\(b.score)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(gradFarbe(b.score))
                    Text("Punkte").font(.caption).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(b.gradText)
                        .font(.subheadline.bold())
                        .foregroundStyle(gradFarbe(b.score))
                    Text(b.datum, style: .date)
                        .font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.caption)
                        Text("Zeitraum: 3 Monate")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func gradFarbe(_ score: Int) -> Color {
        switch score {
        case 0...5:   return .green
        case 6...10:  return .yellow
        case 11...20: return .orange
        default:      return .red
        }
    }

    private var infoBox: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 10) {
                Text("Der MIDAS-Score misst, wie stark Migräne deinen Alltag in den letzten 3 Monaten beeinträchtigt hat. 5 Fragen zählen verlorene oder eingeschränkte Tage.")
                    .font(.caption).foregroundStyle(.secondary)
                Divider()
                infoPill("0–5",   label: "Grad I – Minimale Beeinträchtigung",  farbe: .green)
                infoPill("6–10",  label: "Grad II – Leichte Beeinträchtigung",  farbe: .yellow)
                infoPill("11–20", label: "Grad III – Mässige Beeinträchtigung", farbe: .orange)
                infoPill("≥ 21",  label: "Grad IV – Schwere Beeinträchtigung",  farbe: .red)
            }
            .padding(.top, 6)
        } label: {
            Label("Was ist der MIDAS-Score?", systemImage: "info.circle")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func infoPill(_ wert: String, label: String, farbe: Color) -> some View {
        HStack(spacing: 8) {
            Circle().fill(farbe).frame(width: 8, height: 8)
            Text(wert).font(.caption.bold()).foregroundStyle(farbe).frame(width: 36, alignment: .leading)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Zeile

private struct MIDASZeile: View {
    let bewertung: MIDASBewertung

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(gradFarbe.opacity(0.2)).frame(width: 48, height: 48)
                Text("\(bewertung.score)")
                    .font(.title3.bold())
                    .foregroundStyle(gradFarbe)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(bewertung.gradText).font(.headline)
                Text(bewertung.datum, style: .date).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(bewertung.score) Pkt.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var gradFarbe: Color {
        switch bewertung.score {
        case 0...5:   return .green
        case 6...10:  return .yellow
        case 11...20: return .orange
        default:      return .red
        }
    }
}

// MARK: - Form

struct MIDASFragebogenView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var q1 = 0
    @State private var q2 = 0
    @State private var q3 = 0
    @State private var q4 = 0
    @State private var q5 = 0
    @State private var notizen = ""

    private var score: Int { q1 + q2 + q3 + q4 + q5 }

    private var gradText: String {
        switch score {
        case 0...5:   return "Grad I – Minimal"
        case 6...10:  return "Grad II – Leicht"
        case 11...20: return "Grad III – Mässig"
        default:      return "Grad IV – Schwer"
        }
    }

    private var gradFarbe: Color {
        switch score {
        case 0...5:   return .green
        case 6...10:  return .yellow
        case 11...20: return .orange
        default:      return .red
        }
    }

    private let fragen: [(titel: String, frage: String)] = [
        ("Arbeit / Schule – eingeschränkt",
         "An wie vielen Tagen konntest du bei der Arbeit oder in der Schule weniger als die Hälfte deiner normalen Leistung erbringen?"),
        ("Arbeit / Schule – gefehlt",
         "An wie vielen Tagen hast du wegen Kopfschmerzen die Arbeit oder Schule komplett versäumt?"),
        ("Haushalt – eingeschränkt",
         "An wie vielen Tagen konntest du im Haushalt weniger als die Hälfte deiner normalen Arbeit erledigen?"),
        ("Haushalt – gefehlt",
         "An wie vielen Tagen hast du Hausarbeiten wegen Kopfschmerzen komplett versäumt?"),
        ("Freizeit & Soziales",
         "An wie vielen Tagen hast du Freizeit-, Familien- oder soziale Aktivitäten wegen Kopfschmerzen verpasst?")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Zeitraum: letzte 3 Monate")
                                .font(.subheadline.bold())
                            Text("Zähle Tage mit Migräne oder starken Kopfschmerzen.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(score)")
                                .font(.title2.bold())
                                .foregroundStyle(gradFarbe)
                                .animation(.easeInOut, value: score)
                            Text("Punkte").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                ForEach(fragen.indices, id: \.self) { i in
                    let frage = fragen[i]
                    MIDASFrageSektion(
                        index: i,
                        titel: frage.titel,
                        frageText: frage.frage,
                        tage: wert(i),
                        onMinus: { if wert(i) > 0 { setWert(i, wert(i) - 1) } },
                        onPlus:  { if wert(i) < 90 { setWert(i, wert(i) + 1) } }
                    )
                }

                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(gradText)
                                .font(.headline)
                                .foregroundStyle(gradFarbe)
                            Text("MIDAS-Score: \(score) Punkte")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        ZStack {
                            Circle().fill(gradFarbe.opacity(0.15)).frame(width: 52, height: 52)
                            Text("\(score)")
                                .font(.title2.bold())
                                .foregroundStyle(gradFarbe)
                        }
                        .animation(.easeInOut, value: score)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Ergebnis")
                }

                Section("Notizen") {
                    TextField("Optionale Notizen", text: $notizen, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("MIDAS-Fragebogen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { speichern() }
                }
            }
        }
    }

    private func wert(_ i: Int) -> Int {
        switch i { case 0: return q1; case 1: return q2; case 2: return q3; case 3: return q4; default: return q5 }
    }

    private func setWert(_ i: Int, _ v: Int) {
        switch i { case 0: q1 = v; case 1: q2 = v; case 2: q3 = v; case 3: q4 = v; default: q5 = v }
    }

    private func speichern() {
        let neu = MIDASBewertung(
            tageArbeitEingeschraenkt: q1, tageArbeitGefehlt: q2,
            tageHaushaltEingeschraenkt: q3, tageHaushaltGefehlt: q4,
            tageFreizeit: q5, notizen: notizen
        )
        modelContext.insert(neu)
        dismiss()
    }
}

// MARK: - Frage-Sektion (ausgelagert zur Entlastung des Type-Checkers)

private struct MIDASFrageSektion: View {
    let index: Int
    let titel: String
    let frageText: String
    let tage: Int
    let onMinus: () -> Void
    let onPlus: () -> Void

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text(frageText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 0) {
                    Button(action: onMinus) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title)
                            .foregroundStyle(tage > 0 ? Color.purple : Color.secondary)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    VStack(spacing: 2) {
                        Text("\(tage)")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(tage == 0 ? Color.secondary : Color.purple)
                            .animation(.spring(response: 0.2), value: tage)
                        Text("Tage")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(minWidth: 80)

                    Spacer()

                    Button(action: onPlus) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundStyle(Color.purple)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }
            .padding(.vertical, 4)
        } header: {
            Text("Frage \(index + 1): \(titel)")
        }
    }
}
