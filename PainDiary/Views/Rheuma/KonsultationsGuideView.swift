import SwiftUI
import SwiftData

struct KonsultationsGuideView: View {
    @Query(sort: \PainEntry.datum, order: .reverse) private var alleEintraege: [PainEntry]
    @Environment(\.dismiss) private var dismiss

    @State private var verbesserungen = ""
    @State private var sorgen = ""
    @State private var fragen = ""
    @State private var zeigeTeilen = false

    private var letzteVierwochenEintraege: [PainEntry] {
        let grenze = Calendar.current.date(byAdding: .day, value: -28, to: Date()) ?? Date()
        return alleEintraege.filter { $0.datum >= grenze && $0.koerperstelle == "Rheuma" }
    }

    private var avgSchmerz: Double {
        let e = letzteVierwochenEintraege
        guard !e.isEmpty else { return 0 }
        return Double(e.map(\.schmerzstaerke).reduce(0, +)) / Double(e.count)
    }

    private var anzahlSchubs: Int {
        letzteVierwochenEintraege.filter(\.istSchub).count
    }

    private var avgMorgensteifigkeit: Double {
        let e = letzteVierwochenEintraege.filter { $0.morgensteifigkeit > 0 }
        guard !e.isEmpty else { return 0 }
        return Double(e.map(\.morgensteifigkeit).reduce(0, +)) / Double(e.count)
    }

    private var avgFatigue: Double {
        let e = letzteVierwochenEintraege.filter { $0.fatigue > 0 }
        guard !e.isEmpty else { return 0 }
        return Double(e.map(\.fatigue).reduce(0, +)) / Double(e.count)
    }

    private var avgSchlaf: Double {
        let e = letzteVierwochenEintraege.filter { $0.schlafStunden > 0 }
        guard !e.isEmpty else { return 0 }
        return e.map(\.schlafStunden).reduce(0, +) / Double(e.count)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    summaryKarte
                    fragenKarte(
                        titel: "Was hat sich verbessert?",
                        symbol: "arrow.up.circle.fill",
                        farbe: .green,
                        text: $verbesserungen,
                        placeholder: "z.B. Schwellung zurückgegangen, weniger Morgensteifigkeit…"
                    )
                    fragenKarte(
                        titel: "Was bereitet mir Sorgen?",
                        symbol: "exclamationmark.triangle.fill",
                        farbe: .orange,
                        text: $sorgen,
                        placeholder: "z.B. neue Gelenke betroffen, Nebenwirkungen…"
                    )
                    fragenKarte(
                        titel: "Meine Fragen für den Arzt",
                        symbol: "questionmark.circle.fill",
                        farbe: .blue,
                        text: $fragen,
                        placeholder: "z.B. Therapieanpassung, Laborwerte, nächste Kontrolle…"
                    )
                    Button { zeigeTeilen = true } label: {
                        Label("Zusammenfassung teilen", systemImage: "square.and.arrow.up")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.blue, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Termin vorbereiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .sheet(isPresented: $zeigeTeilen) {
                TextShareSheet(text: zusammenfassungsText)
            }
        }
    }

    // MARK: - Summary card

    private var summaryKarte: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Letzte 4 Wochen", systemImage: "chart.bar.fill")
                    .font(.headline)
                Spacer()
                Text("\(letzteVierwochenEintraege.count) Einträge")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if letzteVierwochenEintraege.isEmpty {
                Text("Noch keine Rheuma-Einträge der letzten 4 Wochen.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    statChip(label: "Ø Schmerz", wert: String(format: "%.1f/10", avgSchmerz), farbe: .red)
                    statChip(label: "Schübe", wert: "\(anzahlSchubs)", farbe: .orange)
                    if avgMorgensteifigkeit > 0 {
                        statChip(label: "Ø Steifigkeit", wert: String(format: "%.0f min", avgMorgensteifigkeit), farbe: .yellow)
                    }
                    if avgFatigue > 0 {
                        statChip(label: "Ø Fatigue", wert: String(format: "%.1f/10", avgFatigue), farbe: .purple)
                    }
                    if avgSchlaf > 0 {
                        statChip(label: "Ø Schlaf", wert: String(format: "%.1f h", avgSchlaf), farbe: .indigo)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func statChip(label: String, wert: String, farbe: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(wert)
                .font(.subheadline.bold())
                .foregroundStyle(farbe)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(farbe.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Input card

    private func fragenKarte(titel: String, symbol: String, farbe: Color, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(titel, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(farbe)
            ZStack(alignment: .topLeading) {
                TextEditor(text: text)
                    .frame(minHeight: 70)
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 4)
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Share text

    private var zusammenfassungsText: String {
        var lines: [String] = ["=== Termin-Vorbereitung ==="]
        lines.append("Letzte 4 Wochen (\(letzteVierwochenEintraege.count) Einträge):")
        if !letzteVierwochenEintraege.isEmpty {
            lines.append(String(format: "• Ø Schmerz: %.1f/10", avgSchmerz))
            lines.append("• Schübe: \(anzahlSchubs)")
            if avgMorgensteifigkeit > 0 {
                lines.append(String(format: "• Ø Morgensteifigkeit: %.0f min", avgMorgensteifigkeit))
            }
            if avgFatigue > 0 {
                lines.append(String(format: "• Ø Fatigue: %.1f/10", avgFatigue))
            }
            if avgSchlaf > 0 {
                lines.append(String(format: "• Ø Schlaf: %.1f h", avgSchlaf))
            }
        }
        if !verbesserungen.isEmpty { lines.append("\nVerbessert:\n\(verbesserungen)") }
        if !sorgen.isEmpty { lines.append("\nSorgen:\n\(sorgen)") }
        if !fragen.isEmpty { lines.append("\nFragen für den Arzt:\n\(fragen)") }
        return lines.joined(separator: "\n")
    }
}

// MARK: - TextShareSheet

struct TextShareSheet: UIViewControllerRepresentable {
    let text: String
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
