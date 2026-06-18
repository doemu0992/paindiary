import SwiftUI
import SwiftData
import UIKit

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

            Section("Vorschau") {
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
