import SwiftUI
import SwiftData

struct MIDASView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MIDASBewertung.datum, order: .reverse) private var bewertungen: [MIDASBewertung]
    @State private var fragebogenAnzeigen = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Der MIDAS-Score misst, wie stark Migräne/Kopfschmerzen deinen Alltag in den letzten 3 Monaten beeinträchtigt haben.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Neue Bewertung starten") { fragebogenAnzeigen = true }
                        .buttonStyle(.borderedProminent)
                }
                .padding(.vertical, 4)
            }

            if !bewertungen.isEmpty {
                Section("Verlauf") {
                    ForEach(bewertungen as [MIDASBewertung]) { b in
                        MIDASZeile(bewertung: b)
                    }
                    .onDelete { idx in
                        idx.forEach { modelContext.delete(bewertungen[$0]) }
                    }
                }
            }
        }
        .navigationTitle("MIDAS-Score")
        .sheet(isPresented: $fragebogenAnzeigen) {
            MIDASFragebogenView()
        }
    }
}

private struct MIDASZeile: View {
    let bewertung: MIDASBewertung

    private var farbe: Color {
        switch bewertung.score {
        case 0...5:   return .green
        case 6...10:  return .yellow
        case 11...20: return .orange
        default:      return .red
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(farbe.opacity(0.2)).frame(width: 48, height: 48)
                Text("\(bewertung.score)")
                    .font(.title3.bold())
                    .foregroundStyle(farbe)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(bewertung.gradText).font(.headline)
                Text(bewertung.datum, style: .date).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

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

    private let fragen = [
        ("Arbeit / Schule – eingeschränkt", "An wie vielen Tagen konntest du bei der Arbeit oder in der Schule weniger als 50% leisten?"),
        ("Arbeit / Schule – gefehlt", "An wie vielen Tagen hast du wegen Kopfschmerzen Arbeit oder Schule komplett versäumt?"),
        ("Haushalt – eingeschränkt", "An wie vielen Tagen konntest du im Haushalt weniger als 50% leisten?"),
        ("Haushalt – gefehlt", "An wie vielen Tagen hast du Hausarbeiten wegen Kopfschmerzen komplett versäumt?"),
        ("Freizeit & Soziales", "An wie vielen Tagen hast du Freizeit-, Familien- oder soziale Aktivitäten verpasst?")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Beantworte diese 5 Fragen für die letzten **3 Monate**.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ForEach(Array(zip(fragen.indices, fragen)), id: \.0) { i, frage in
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(frage.1)
                                .font(.subheadline)
                            Stepper("\(wert(i)) Tage", value: binding(i), in: 0...90)
                                .font(.headline)
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("Frage \(i + 1): \(frage.0)")
                    }
                }

                Section("Ergebnis") {
                    HStack {
                        Text("MIDAS-Score")
                        Spacer()
                        Text("\(score)")
                            .font(.title2.bold())
                            .foregroundStyle(gradFarbe)
                    }
                    HStack {
                        Text("Beeinträchtigung")
                        Spacer()
                        Text(gradText)
                            .foregroundStyle(gradFarbe)
                            .fontWeight(.medium)
                    }
                }

                Section("Notizen") {
                    TextEditor(text: $notizen).frame(minHeight: 60)
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

    private func binding(_ i: Int) -> Binding<Int> {
        switch i {
        case 0: return $q1; case 1: return $q2; case 2: return $q3; case 3: return $q4; default: return $q5
        }
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
