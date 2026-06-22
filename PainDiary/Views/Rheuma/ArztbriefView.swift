import SwiftUI
import SwiftData
import UIKit
#if canImport(FoundationModels)
import FoundationModels
#endif

struct ArztbriefView: View {
    @Query(sort: \PainEntry.datum, order: .reverse) private var eintraege: [PainEntry]
    @Query(sort: \Dauermedikation.name) private var medikamente: [Dauermedikation]
    @Query(sort: \Laborwert.datum, order: .reverse) private var laborwerte: [Laborwert]
    @Query(sort: \Arztbesuch.datum, order: .reverse) private var besuche: [Arztbesuch]
    @Query private var profile: [Benutzerprofil]

    @State private var zeitraum = 30
    @State private var zeigeTeilen = false

    private let zeitraeume = [7: "7 Tage", 14: "14 Tage", 30: "30 Tage", 90: "3 Monate"]

    var body: some View {
        List {
            Section("Zeitraum") {
                Picker("Zeitraum", selection: $zeitraum) {
                    ForEach(Array(zeitraeume.keys).sorted(), id: \.self) { k in
                        Text(zeitraeume[k]!).tag(k)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                Button {
                    zeigeTeilen = true
                } label: {
                    Label("Arztbrief teilen", systemImage: "square.and.arrow.up")
                }

                Button {
                    UIPasteboard.general.string = erzeugeBrief()
                } label: {
                    Label("In Zwischenablage kopieren", systemImage: "doc.on.doc")
                }
            }

            Section("KI-Arztbrief") {
                KIArztbriefKarte(rohdaten: erzeugeBrief(), patientenName: patientenName)
                    .id(zeitraum)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
            }

            Section("Strukturierte Vorschau") {
                Text(erzeugeBrief())
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Arztbrief")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $zeigeTeilen) {
            TextShareSheet(text: erzeugeBrief())
        }
    }

    private var patientenName: String {
        guard let p = profile.first, !p.vorname.isEmpty else { return "" }
        return "\(p.vorname) \(p.nachname)"
    }

    private func erzeugeBrief() -> String {
        let kal = Calendar.current
        let heute = Date()
        guard let von = kal.date(byAdding: .day, value: -zeitraum, to: heute) else { return "" }

        let gefiltert = eintraege.filter { $0.datum >= von }
        let aktiveMeds = medikamente.filter { $0.aktiv }
        let labs = laborwerte.filter { $0.datum >= von }
        let visits = besuche.filter { $0.datum >= von }

        let df = DateFormatter()
        df.locale = Locale(identifier: "de_CH")
        df.dateStyle = .medium
        var text = ""

        text += "SCHMERZTAGEBUCH – ZUSAMMENFASSUNG\n"
        text += "Zeitraum: \(df.string(from: von)) – \(df.string(from: heute))\n"
        if let p = profile.first, !p.vorname.isEmpty {
            text += "Patient: \(p.vorname) \(p.nachname)\n"
            if let geb = p.geburtsdatum { text += "Geburtsdatum: \(df.string(from: geb))\n" }
        }
        text += "\n"

        if !gefiltert.isEmpty {
            let avg = Double(gefiltert.map(\.schmerzstaerke).reduce(0,+)) / Double(gefiltert.count)
            let schube = gefiltert.filter(\.istSchub).count
            text += "SCHMERZ (\(gefiltert.count) Einträge)\n"
            text += "  Durchschnitt: \(String(format: "%.1f", avg))/10, Maximum: \(gefiltert.map(\.schmerzstaerke).max() ?? 0)/10\n"
            if schube > 0 { text += "  Schübe: \(schube)\n" }
            let stellen = Dictionary(grouping: gefiltert.filter { !$0.koerperstelle.isEmpty }, by: \.koerperstelle)
                .sorted { $0.value.count > $1.value.count }.prefix(3)
                .map { "\($0.key) (\($0.value.count)x)" }.joined(separator: ", ")
            if !stellen.isEmpty { text += "  Hauptlokalisation: \(stellen)\n" }
            let mgEintraege = gefiltert.filter { $0.morgensteifigkeit > 0 }
            if !mgEintraege.isEmpty {
                let avgMg = Double(mgEintraege.map(\.morgensteifigkeit).reduce(0,+)) / Double(mgEintraege.count)
                text += "  Morgensteifigkeit Ø: \(String(format: "%.0f", avgMg)) Min\n"
            }
        } else {
            text += "SCHMERZ: Keine Einträge im Zeitraum\n"
        }
        text += "\n"

        if !aktiveMeds.isEmpty {
            text += "AKTUELLE MEDIKAMENTE\n"
            for m in aktiveMeds {
                text += "  • \(m.name)"
                if !m.dosierung.isEmpty { text += " \(m.dosierung)" }
                if !m.frequenz.isEmpty { text += " (\(m.frequenz))" }
                text += "\n"
            }
            text += "\n"
        }

        if !labs.isEmpty {
            text += "LABORWERTE\n"
            for l in labs {
                text += "  \(df.string(from: l.datum)) – \(l.typ): \(String(format: "%.1f", l.wert)) \(l.einheit)"
                if let max = l.referenzMax, l.wert > max { text += " ⚠️ erhöht" }
                text += "\n"
            }
            text += "\n"
        }

        if !visits.isEmpty {
            text += "ARZTBESUCHE\n"
            for v in visits {
                text += "  \(df.string(from: v.datum))"
                if !v.arzt.isEmpty { text += " – \(v.arzt)" }
                if !v.fachgebiet.isEmpty { text += " (\(v.fachgebiet))" }
                text += "\n"
                if !v.befund.isEmpty { text += "    Befund: \(v.befund)\n" }
                if !v.therapieaenderung.isEmpty { text += "    Therapie: \(v.therapieaenderung)\n" }
            }
            text += "\n"
        }

        text += "Erstellt mit PainDiary · \(df.string(from: heute))\n"
        return text
    }
}

// MARK: - KI Arztbrief Karte

struct KIArztbriefKarte: View {
    let rohdaten: String
    let patientenName: String

    var body: some View {
#if canImport(FoundationModels)
        if #available(iOS 26, *) {
            KIArztbriefContent(rohdaten: rohdaten, patientenName: patientenName)
        }
#endif
    }
}

#if canImport(FoundationModels)
@available(iOS 26, *)
private struct KIArztbriefContent: View {
    let rohdaten: String
    let patientenName: String

    @State private var session: LanguageModelSession? = nil
    @State private var brief = ""
    @State private var isGenerating = false
    @State private var hatGeneriert = false
    @State private var fehler: String? = nil

    private var systemPrompt: String {
        "Du bist ein medizinischer Schreibassistent für PainDiary. " +
        "Erstelle auf Basis der Rohdaten einen formellen, professionellen Arztbrief auf Deutsch. " +
        "Struktur: Briefkopf (Datum, Patient), Betreff, Anrede, Anamnese, aktueller Befund, " +
        "Medikation, Laborwerte (falls vorhanden), Verlauf, freundliche Schlussformel. " +
        "Klar und sachlich formulieren. Keine Diagnosen stellen."
    }

    private var prompt: String {
        "Erstelle einen Arztbrief für \(patientenName.isEmpty ? "den Patienten" : patientenName) " +
        "basierend auf diesen PainDiary-Daten:\n\n\(rohdaten)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Label("KI-Arztbrief", systemImage: "sparkles")
                    .font(.headline).foregroundStyle(.teal)
                Spacer()
                if isGenerating {
                    ProgressView().scaleEffect(0.75)
                } else if hatGeneriert {
                    HStack(spacing: 12) {
                        Button {
                            UIPasteboard.general.string = brief
                        } label: {
                            Image(systemName: "doc.on.doc").font(.caption.bold()).foregroundStyle(.teal)
                        }
                        .buttonStyle(.plain)
                        Button { Task { await generieren() } } label: {
                            Image(systemName: "arrow.clockwise").font(.caption.bold()).foregroundStyle(.teal)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Divider()

            if hatGeneriert || isGenerating {
                Text(brief.isEmpty ? " " : brief)
                    .font(.subheadline)
                    .lineSpacing(4)
                    .animation(.easeIn, value: brief)
            } else if let f = fehler {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                    Text(f).font(.caption).foregroundStyle(.secondary)
                }
                Button("Erneut versuchen") { Task { await generieren() } }
                    .font(.caption.bold()).foregroundStyle(.teal)
            } else {
                Text("Apple Intelligence erstellt einen formellen Arztbrief aus deinen PainDiary-Daten.")
                    .font(.caption).foregroundStyle(.secondary).padding(.bottom, 4)
                Button { Task { await generieren() } } label: {
                    Label("Arztbrief generieren", systemImage: "sparkles")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.teal, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(isGenerating)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }

    private func generieren() async {
        if session == nil {
            session = LanguageModelSession(instructions: systemPrompt)
        }
        guard let session else { return }
        isGenerating = true
        hatGeneriert = true
        brief = ""
        fehler = nil
        do {
            let stream = session.streamResponse(to: prompt)
            for try await partial in stream {
                brief = partial.content
            }
        } catch {
            fehler = "Apple Intelligence nicht verfügbar. Aktiviere es unter Einstellungen → Apple Intelligence."
            hatGeneriert = false
        }
        isGenerating = false
    }
}
#endif
