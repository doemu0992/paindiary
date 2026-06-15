import SwiftUI
import SwiftData
import Charts

struct HAQView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HAQEintrag.datum, order: .reverse) private var eintraege: [HAQEintrag]
    @Query(sort: \Laborwert.datum, order: .reverse) private var laborwerte: [Laborwert]
    @Query(sort: \PainEntry.datum, order: .reverse) private var painEintraege: [PainEntry]

    private var letzterGelenkStatus: [String: GelenkZustand] {
        guard let eintrag = painEintraege.first(where: { !$0.gelenkStatus.isEmpty }) else { return [:] }
        return GelenkStatusCoder.decode(eintrag.gelenkStatus)
    }

    @State private var zeigeForm = false

    var body: some View {
        List {
            // DAS28 Calculator
            if let letzterHAQ = eintraege.first {
                Section {
                    das28Karte(letzterHAQ: letzterHAQ)
                }
            }

            // HAQ Score History
            if eintraege.count >= 2 {
                Section("Verlauf") {
                    let daten = eintraege.sorted { $0.datum < $1.datum }
                    Chart(daten) { e in
                        LineMark(
                            x: .value("Datum", e.datum, unit: .day),
                            y: .value("HAQ-DI", e.haqScore)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Color.purple)
                        PointMark(
                            x: .value("Datum", e.datum, unit: .day),
                            y: .value("HAQ-DI", e.haqScore)
                        )
                        .foregroundStyle(Color.purple)
                    }
                    .chartYScale(domain: 0...3)
                    .chartYAxis {
                        AxisMarks(values: [0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0]) { v in
                            AxisGridLine()
                            AxisValueLabel { if let d = v.as(Double.self) { Text(String(format: "%.1f", d)) } }
                        }
                    }
                    .frame(height: 140)
                    .padding(.vertical, 4)
                }
            }

            // Score explanation
            Section {
                scoreInfoBox
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)

            // History List
            Section(eintraege.isEmpty ? "" : "Einträge") {
                if eintraege.isEmpty {
                    ContentUnavailableView(
                        "Kein HAQ erfasst",
                        systemImage: "checklist",
                        description: Text("Tippe auf + um den Fragebogen auszufüllen.")
                    )
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(eintraege) { e in
                        HAQZeile(eintrag: e)
                    }
                    .onDelete(perform: loeschen)
                }
            }
        }
        .navigationTitle("HAQ & DAS28")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { zeigeForm = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $zeigeForm) { HAQFormView() }
    }

    @ViewBuilder
    private func das28Karte(letzterHAQ: HAQEintrag) -> some View {
        let crpWert = laborwerte.first(where: { $0.typ == "CRP" })?.wert
        let bsgWert = laborwerte.first(where: { $0.typ == "BSG" })?.wert

        let gelenke = letzterGelenkStatus
        let tjc = DAS28Rechner.tjc28(gelenke)
        let sjc = DAS28Rechner.sjc28(gelenke)
        let hatGelenke = !gelenke.isEmpty

        VStack(alignment: .leading, spacing: 12) {
            Label("DAS28 Aktivitätsscore", systemImage: "chart.bar.fill")
                .font(.headline).foregroundStyle(.purple)
            Divider()

            HStack(spacing: 12) {
                scoreBox(label: "HAQ-DI", wert: String(format: "%.2f", letzterHAQ.haqScore), farbe: .purple)
                if hatGelenke {
                    scoreBox(label: "TJC", wert: "\(tjc)", farbe: .red)
                    scoreBox(label: "SJC", wert: "\(sjc)", farbe: .blue)
                }
                if let crp = crpWert {
                    let score = DAS28Rechner.das28crp(tjc: tjc, sjc: sjc, crp: crp, gh: letzterHAQ.globalBewertung)
                    scoreBox(label: "DAS28-CRP", wert: String(format: "%.1f", score),
                             farbe: DAS28Rechner.aktivitaetsFarbe(score))
                    Text(DAS28Rechner.aktivitaetsText(score))
                        .font(.caption.bold())
                        .foregroundStyle(DAS28Rechner.aktivitaetsFarbe(score))
                }
                if let bsg = bsgWert, crpWert == nil {
                    let score = DAS28Rechner.das28esr(tjc: tjc, sjc: sjc, bsg: bsg, gh: letzterHAQ.globalBewertung)
                    scoreBox(label: "DAS28-BSG", wert: String(format: "%.1f", score),
                             farbe: DAS28Rechner.aktivitaetsFarbe(score))
                    Text(DAS28Rechner.aktivitaetsText(score))
                        .font(.caption.bold())
                        .foregroundStyle(DAS28Rechner.aktivitaetsFarbe(score))
                }
            }

            if let crp = crpWert, hatGelenke {
                let pga = Double(letzterHAQ.globalBewertung) / 10.0
                let sdai = Double(tjc + sjc) + pga + (crp * 0.1)
                Divider()
                HStack(spacing: 12) {
                    scoreBox(label: "SDAI", wert: String(format: "%.1f", sdai),
                             farbe: sdaiFarbe(sdai))
                    Text(sdaiText(sdai))
                        .font(.caption.bold())
                        .foregroundStyle(sdaiFarbe(sdai))
                }
            }

            if !hatGelenke {
                Label("Gelenkstatus erfassen für TJC/SJC", systemImage: "hand.point.up.left")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if crpWert == nil && bsgWert == nil {
                Label("CRP oder BSG eintragen für vollständigen DAS28", systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func sdaiFarbe(_ score: Double) -> Color {
        switch score {
        case ...3.3:  return .green
        case ...11.0: return .mint
        case ...26.0: return .orange
        default:      return .red
        }
    }

    private func sdaiText(_ score: Double) -> String {
        switch score {
        case ...3.3:  return "Remission"
        case ...11.0: return "Niedrige Aktivität"
        case ...26.0: return "Mässige Aktivität"
        default:      return "Hohe Aktivität"
        }
    }


    private func scoreBox(label: String, wert: String, farbe: Color) -> some View {
        VStack(spacing: 4) {
            Text(wert).font(.title2.bold()).foregroundStyle(farbe)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(minWidth: 70)
        .padding(10)
        .background(farbe.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }

    private var scoreInfoBox: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("HAQ-DI – Funktionseinschränkung")
                        .font(.subheadline.bold())
                    infoPill("0.0 – 0.5", label: "Keine / minimale Einschränkung", farbe: .green)
                    infoPill("0.5 – 1.0", label: "Leichte Einschränkung", farbe: .yellow)
                    infoPill("1.0 – 2.0", label: "Mässige Einschränkung", farbe: .orange)
                    infoPill("2.0 – 3.0", label: "Schwere Einschränkung", farbe: .red)
                }
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("DAS28 – Krankheitsaktivität")
                        .font(.subheadline.bold())
                    infoPill("< 2.6", label: "Remission", farbe: .green)
                    infoPill("2.6 – 3.2", label: "Niedrige Aktivität", farbe: .yellow)
                    infoPill("3.2 – 5.1", label: "Moderate Aktivität", farbe: .orange)
                    infoPill("> 5.1", label: "Hohe Aktivität", farbe: .red)
                }
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("SDAI – Vereinfachter Aktivitätsindex")
                        .font(.subheadline.bold())
                    Text("SDAI = TJC + SJC + PGA(0–10) + CRP(mg/dL)")
                        .font(.caption2).foregroundStyle(.tertiary)
                    infoPill("≤ 3.3", label: "Remission", farbe: .green)
                    infoPill("≤ 11", label: "Niedrige Aktivität", farbe: .mint)
                    infoPill("≤ 26", label: "Mässige Aktivität", farbe: .orange)
                    infoPill("> 26", label: "Hohe Aktivität", farbe: .red)
                }
            }
            .padding(.top, 6)
        } label: {
            Label("Was bedeuten die Scores?", systemImage: "info.circle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func infoPill(_ wert: String, label: String, farbe: Color) -> some View {
        HStack(spacing: 8) {
            Circle().fill(farbe).frame(width: 8, height: 8)
            Text(wert).font(.caption.bold()).foregroundStyle(farbe).frame(width: 60, alignment: .leading)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func loeschen(_ offsets: IndexSet) {
        offsets.map { eintraege[$0] }.forEach { modelContext.delete($0) }
    }
}

private struct HAQZeile: View {
    let eintrag: HAQEintrag
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(eintrag.datum, style: .date).font(.subheadline.bold())
                Text(eintrag.haqGradText).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(String(format: "%.2f", eintrag.haqScore))
                    .font(.subheadline.bold()).foregroundStyle(.purple)
                Text("HAQ-DI").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Form

struct HAQFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var datum = Date()
    @State private var ankleiden = 0
    @State private var aufstehen = 0
    @State private var essen = 0
    @State private var gehen = 0
    @State private var hygiene = 0
    @State private var greifen = 0
    @State private var aktivitaeten = 0
    @State private var globalBewertung = 50

    private let stufenKurz = ["Keine", "Einige", "Grosse", "Nicht\nmöglich"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Datum") {
                    DatePicker("Datum", selection: $datum, displayedComponents: [.date])
                }

                Section {
                    haqFrage("Ankleiden & Körperpflege", wert: $ankleiden,
                             beispiel: "Knöpfe öffnen, Haare kämmen")
                    haqFrage("Aufstehen", wert: $aufstehen,
                             beispiel: "Vom Stuhl/Bett aufstehen")
                    haqFrage("Essen", wert: $essen,
                             beispiel: "Glas heben, Messer benutzen")
                    haqFrage("Gehen", wert: $gehen,
                             beispiel: "Ebene Strecken, Treppensteigen")
                    haqFrage("Hygiene", wert: $hygiene,
                             beispiel: "Waschen, Baden, WC-Benutzung")
                    haqFrage("Greifen", wert: $greifen,
                             beispiel: "Objekte heben, Türen öffnen")
                    haqFrage("Andere Aktivitäten", wert: $aktivitaeten,
                             beispiel: "Einkaufen, Auto fahren")
                } header: {
                    Text("Aktivitätskategorien (HAQ-DI)")
                } footer: {
                    let score = Double([ankleiden, aufstehen, essen, gehen, hygiene, greifen, aktivitaeten].reduce(0,+)) / 7.0
                    Text(String(format: "Aktueller HAQ-DI Score: %.2f", score))
                }

                Section("Allgemeines Befinden (0–100)") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Globale Selbsteinschätzung")
                                .font(.subheadline)
                            Spacer()
                            Text("\(globalBewertung)")
                                .font(.subheadline.bold())
                                .foregroundStyle(globalFarbe)
                        }
                        Slider(value: Binding(
                            get: { Double(globalBewertung) },
                            set: { globalBewertung = Int($0) }
                        ), in: 0...100, step: 5)
                        .tint(globalFarbe)
                        HStack {
                            Text("Sehr gut").font(.caption2).foregroundStyle(.secondary)
                            Spacer()
                            Text("Sehr schlecht").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("HAQ-Fragebogen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Speichern") { speichern() } }
            }
        }
    }

    private func haqFrage(_ titel: String, wert: Binding<Int>, beispiel: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(titel).font(.subheadline.bold())
                Text(beispiel).font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                ForEach(0...3, id: \.self) { i in
                    Button {
                        wert.wrappedValue = i
                    } label: {
                        VStack(spacing: 3) {
                            Text("\(i)")
                                .font(.headline.bold())
                            Text(stufenKurz[i])
                                .font(.system(size: 9, weight: .medium))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            wert.wrappedValue == i
                                ? stufenFarbe(i).opacity(0.18)
                                : Color(.tertiarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(wert.wrappedValue == i ? stufenFarbe(i) : Color.clear, lineWidth: 1.5)
                        )
                        .foregroundStyle(wert.wrappedValue == i ? stufenFarbe(i) : .secondary)
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(response: 0.2), value: wert.wrappedValue)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func stufenFarbe(_ i: Int) -> Color {
        switch i {
        case 0:  return .green
        case 1:  return .yellow
        case 2:  return .orange
        default: return .red
        }
    }

    private var globalFarbe: Color {
        switch globalBewertung {
        case 0...25: return .green
        case 26...50: return .yellow
        case 51...75: return .orange
        default:     return .red
        }
    }

    private func speichern() {
        let neu = HAQEintrag(datum: datum)
        neu.ankleiden = ankleiden; neu.aufstehen = aufstehen; neu.essen = essen
        neu.gehen = gehen; neu.hygiene = hygiene; neu.greifen = greifen
        neu.aktivitaeten = aktivitaeten; neu.globalBewertung = globalBewertung
        modelContext.insert(neu)
        dismiss()
    }
}
