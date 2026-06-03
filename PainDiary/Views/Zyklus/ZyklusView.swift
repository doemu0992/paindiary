import SwiftUI
import SwiftData
import Charts

struct ZyklusView: View {
    @Query(sort: \ZyklusEintrag.datum, order: .reverse) private var eintraege: [ZyklusEintrag]
    @Query(sort: \PainEntry.datum, order: .reverse) private var painEntries: [PainEntry]
    @Environment(\.modelContext) private var modelContext

    @State private var anzeigeMonat = Date()
    @State private var ausgewaehlterTag: Date? = nil
    @State private var eintragSheetAnzeigen = false

    private var analyse: ZyklusAnalyse { ZyklusRechner.analyse(eintraege: Array(eintraege)) }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                zyklusHeader
                kalender
                quickLog
                statistik
                if !painEntries.isEmpty && !analyse.zyklusStarts.isEmpty {
                    schmerzKorrelation
                }
            }
            .padding(.bottom, 30)
        }
        .navigationTitle("Zyklus")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { wechselMonat(-1) } label: { Image(systemName: "chevron.left") }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { wechselMonat(1) } label: { Image(systemName: "chevron.right") }
            }
        }
        .sheet(isPresented: $eintragSheetAnzeigen) {
            if let tag = ausgewaehlterTag {
                ZyklusEintragSheet(
                    datum: tag,
                    bestehend: eintraege.first { Calendar.current.isDate($0.datum, inSameDayAs: tag) }
                )
            }
        }
    }

    private func wechselMonat(_ richtung: Int) {
        withAnimation {
            anzeigeMonat = Calendar.current.date(byAdding: .month, value: richtung, to: anzeigeMonat) ?? anzeigeMonat
        }
    }

    // MARK: - Header

    private var zyklusHeader: some View {
        VStack(spacing: 12) {
            if let tag = analyse.aktuellerZyklustag {
                HStack(spacing: 0) {
                    headerBadge(wert: "\(tag)", einheit: "Tag", label: "Zyklustag", farbe: .pink)
                    Divider().frame(height: 40)
                    headerBadge(
                        wert: naechstePeriodeBadge,
                        einheit: "",
                        label: "Nächste Periode",
                        farbe: .red
                    )
                    Divider().frame(height: 40)
                    headerBadge(
                        wert: String(format: "%.0f", analyse.zykluslaenge),
                        einheit: "d",
                        label: "Ø Zyklus",
                        farbe: .purple
                    )
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            } else {
                Text("Erfasse deinen ersten Periodentag um zu beginnen.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }

            legende
        }
        .padding(.horizontal)
    }

    private var naechstePeriodeBadge: String {
        guard let n = analyse.naechstePeriodeStart else { return "–" }
        let tage = Calendar.current.dateComponents([.day], from: Date(), to: n).day ?? 0
        if tage <= 0 { return "Heute" }
        return "in \(tage)d"
    }

    private func headerBadge(wert: String, einheit: String, label: String, farbe: Color) -> some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(wert).font(.title3.bold()).foregroundStyle(farbe)
                if !einheit.isEmpty {
                    Text(einheit).font(.caption).foregroundStyle(farbe.opacity(0.7))
                }
            }
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var legende: some View {
        HStack(spacing: 14) {
            legendeItem(farbe: .red, gefuellt: true, text: "Periode")
            legendeItem(farbe: .red, gefuellt: false, text: "Vorhergesagt")
            legendeItem(farbe: .teal, gefuellt: true, text: "Fruchtbar")
            legendeItem(farbe: .orange, gefuellt: true, text: "Eisprung")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func legendeItem(farbe: Color, gefuellt: Bool, text: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(gefuellt ? farbe : farbe.opacity(0.15))
                .overlay(gefuellt ? nil : Circle().stroke(farbe, style: StrokeStyle(lineWidth: 1, dash: [2])))
                .frame(width: 9, height: 9)
            Text(text)
        }
    }

    // MARK: - Calendar

    private var kalender: some View {
        ZyklusKalender(
            monat: anzeigeMonat,
            eintraege: Array(eintraege),
            analyse: analyse
        ) { tag in
            ausgewaehlterTag = tag
            eintragSheetAnzeigen = true
        }
        .padding(.horizontal)
    }

    // MARK: - Quick Log

    private var quickLog: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Heute erfassen").font(.headline).padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    quickBtn("drop.fill", .red, "Periode") { logHeute(istPeriode: true, fluss: "mittel") }
                    quickBtn("circle.dotted", .orange, "Eisprung") { logHeute(ovuTest: "positiv") }
                    quickBtn("thermometer.medium", .blue, "Temperatur") { oeffneHeuteSheet() }
                    quickBtn("heart.text.square", .purple, "Symptome") { oeffneHeuteSheet() }
                    quickBtn("drop.halffull", .pink, "Schmierblutung") { logHeute(istPeriode: true, fluss: "schmierblutung") }
                    quickBtn("pencil", .green, "Notiz") { oeffneHeuteSheet() }
                }
                .padding(.horizontal)
            }
        }
    }

    private func quickBtn(_ symbol: String, _ farbe: Color, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle().fill(farbe.opacity(0.15)).frame(width: 52, height: 52)
                    Image(systemName: symbol).foregroundStyle(farbe).font(.system(size: 20))
                }
                Text(label).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func logHeute(istPeriode: Bool = false, fluss: String = "", ovuTest: String = "") {
        let heute = Calendar.current.startOfDay(for: Date())
        if let alt = eintraege.first(where: { Calendar.current.isDate($0.datum, inSameDayAs: heute) }) {
            if istPeriode { alt.istPeriode = true; alt.blutungsfluss = fluss }
            if !ovuTest.isEmpty { alt.ovulationstest = ovuTest }
        } else {
            let neu = ZyklusEintrag(datum: heute)
            neu.istPeriode = istPeriode
            neu.blutungsfluss = fluss
            neu.ovulationstest = ovuTest
            modelContext.insert(neu)
        }
    }

    private func oeffneHeuteSheet() {
        ausgewaehlterTag = Calendar.current.startOfDay(for: Date())
        eintragSheetAnzeigen = true
    }

    // MARK: - Statistik

    private var statistik: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistik").font(.headline).padding(.horizontal)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statKarte("Ø Zyklus", String(format: "%.0f Tage", analyse.zykluslaenge), "arrow.clockwise", .pink)
                statKarte("Ø Periode", String(format: "%.0f Tage", analyse.periodendauer), "drop.fill", .red)
                statKarte("Variation", String(format: "±%.1f Tage", analyse.variation), "chart.bar", .orange)
                if let ov = analyse.vorhergesagteOvulation {
                    statKarte("Nächster Eisprung", ov.formatted(.dateTime.day().month()), "circle.fill", .teal)
                } else if let n = analyse.naechstePeriodeStart {
                    statKarte("Nächste Periode", n.formatted(.dateTime.day().month()), "calendar", .purple)
                }
            }
            .padding(.horizontal)
        }
    }

    private func statKarte(_ titel: String, _ wert: String, _ symbol: String, _ farbe: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).foregroundStyle(farbe).font(.title3).frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(titel).font(.caption).foregroundStyle(.secondary)
                Text(wert).font(.subheadline.bold())
            }
            Spacer()
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Pain Correlation

    private var schmerzKorrelation: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Schmerz & Zyklus").font(.headline)
                Text("Ø Schmerzstärke je Zyklusphase")
                    .font(.caption).foregroundStyle(.secondary)
            }

            let daten = ZyklusRechner.schmerzJePhase(painEntries: Array(painEntries), analyse: analyse)

            if daten.isEmpty {
                Text("Noch nicht genug überlappende Daten.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Chart(daten, id: \.phase.rawValue) { d in
                    BarMark(x: .value("Phase", d.phase.rawValue), y: .value("Schmerz", d.avgSchmerz))
                        .foregroundStyle(phaseFarbe(d.phase).gradient)
                        .cornerRadius(6)
                        .annotation(position: .top) {
                            Text(String(format: "%.1f", d.avgSchmerz))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                }
                .chartYScale(domain: 0...10)
                .frame(height: 170)

                VStack(spacing: 4) {
                    ForEach(daten, id: \.phase.rawValue) { d in
                        HStack {
                            Circle().fill(phaseFarbe(d.phase)).frame(width: 8, height: 8)
                            Text(d.phase.rawValue).font(.caption)
                            Spacer()
                            Text("\(d.anzahl) Einträge").font(.caption2).foregroundStyle(.secondary)
                            Text(String(format: "Ø %.1f", d.avgSchmerz)).font(.caption.bold())
                        }
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func phaseFarbe(_ p: ZyklusRechner.Zyklusphase) -> Color {
        switch p {
        case .menstruation: return .red
        case .follikelphase: return .yellow
        case .ovulation: return .orange
        case .lutealphase: return .purple
        }
    }
}

// MARK: - Calendar

private struct ZyklusKalender: View {
    let monat: Date
    let eintraege: [ZyklusEintrag]
    let analyse: ZyklusAnalyse
    let onTap: (Date) -> Void

    private let wochentage = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
    private let kal = Calendar.current

    private var monatsTitel: String {
        monat.formatted(.dateTime.month(.wide).year())
    }

    private var tageImMonat: [Date?] {
        guard let erster = kal.date(from: kal.dateComponents([.year, .month], from: monat)),
              let anzahl = kal.range(of: .day, in: .month, for: monat)?.count else { return [] }
        let wt = (kal.component(.weekday, from: erster) + 5) % 7
        var tage: [Date?] = Array(repeating: nil, count: wt)
        for d in 0..<anzahl {
            tage.append(kal.date(byAdding: .day, value: d, to: erster))
        }
        while tage.count % 7 != 0 { tage.append(nil) }
        return tage
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(monatsTitel).font(.title3.bold())

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                ForEach(wochentage, id: \.self) { tag in
                    Text(tag)
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 6)
                }

                ForEach(Array(tageImMonat.enumerated()), id: \.offset) { _, datum in
                    if let datum {
                        let zustand = ZyklusRechner.tagZustand(datum: datum, analyse: analyse)
                        let hatEintrag = eintraege.contains { kal.isDate($0.datum, inSameDayAs: datum) }
                        TagZelle(datum: datum, zustand: zustand, hatEintrag: hatEintrag) {
                            onTap(datum)
                        }
                    } else {
                        Color.clear.frame(height: 38)
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Day Cell

private struct TagZelle: View {
    let datum: Date
    let zustand: ZyklusTagZustand
    let hatEintrag: Bool
    let action: () -> Void

    private var istHeute: Bool { Calendar.current.isDateInToday(datum) }
    private var tagNummer: String { "\(Calendar.current.component(.day, from: datum))" }

    var body: some View {
        Button(action: action) {
            ZStack {
                // Streak band
                GeometryReader { geo in
                    if zustand.periode {
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.red.opacity(zustand.verbundenLinks ? 0.22 : 0))
                                .frame(width: geo.size.width / 2)
                            Rectangle()
                                .fill(Color.red.opacity(zustand.verbundenRechts ? 0.22 : 0))
                                .frame(width: geo.size.width / 2)
                        }
                        .frame(height: 32)
                        .frame(maxHeight: .infinity, alignment: .center)
                    } else if zustand.fruchtbar {
                        Rectangle()
                            .fill(Color.teal.opacity(0.12))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }

                VStack(spacing: 2) {
                    ZStack {
                        // Background circle
                        if zustand.periode {
                            Circle().fill(Color.red)
                        } else if zustand.ovulation {
                            Circle().fill(Color.orange)
                        } else if zustand.vorhergesagtePeriode {
                            Circle()
                                .fill(Color.red.opacity(0.1))
                                .overlay(Circle().stroke(Color.red.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
                        } else if zustand.fruchtbar {
                            Circle().fill(Color.teal.opacity(0.25))
                        }

                        // Today ring (when not period/ovulation)
                        if istHeute && !zustand.periode && !zustand.ovulation {
                            Circle().stroke(Color.primary, lineWidth: 1.5)
                        }

                        Text(tagNummer)
                            .font(.system(size: 13, weight: zustand.periode || istHeute ? .semibold : .regular))
                            .foregroundStyle(tagTextFarbe)
                    }
                    .frame(width: 30, height: 30)

                    // Symptom dot
                    Circle()
                        .fill(hatEintrag && !zustand.periode ? Color.purple.opacity(0.6) : Color.clear)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(height: 38)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.2), value: zustand.periode)
    }

    private var tagTextFarbe: Color {
        if zustand.periode || zustand.ovulation { return .white }
        if zustand.vorhergesagtePeriode { return .red.opacity(0.7) }
        if zustand.fruchtbar { return .teal }
        if istHeute { return .primary }
        return .secondary
    }
}

// MARK: - Entry Sheet

struct ZyklusEintragSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let datum: Date
    let bestehend: ZyklusEintrag?

    @State private var istPeriode = false
    @State private var blutungsfluss = "mittel"
    @State private var symptome: Set<String> = []
    @State private var ovulationstest = ""
    @State private var zervixschleim = ""
    @State private var basaltemperatur = ""
    @State private var sexuelleAktivitaet = ""
    @State private var notizen = ""

    private let flussOptionen = ["schmierblutung", "leicht", "mittel", "stark"]
    private let symptomOptionen = [
        "Krämpfe", "Kopfschmerzen", "Rückenschmerzen", "Brustspannen",
        "Blähungen", "Übelkeit", "Müdigkeit", "Stimmungsschwankungen",
        "Akne", "Schlafprobleme", "Hitzewallungen", "Appetitsteigerung"
    ]
    private let schleimOptionen = ["trocken", "klebrig", "cremig", "wässrig", "Eiweiss"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(datum.formatted(.dateTime.day().month(.wide).year()))
                        .font(.subheadline.bold())
                }

                Section("Periode") {
                    Toggle("Blutung", isOn: $istPeriode)
                    if istPeriode {
                        Picker("Stärke", selection: $blutungsfluss) {
                            ForEach(flussOptionen, id: \.self) { Text($0.capitalized).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                Section("Symptome") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        ForEach(symptomOptionen, id: \.self) { s in
                            Button {
                                symptome.contains(s) ? symptome.remove(s) : symptome.insert(s)
                            } label: {
                                HStack {
                                    Image(systemName: symptome.contains(s) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(symptome.contains(s) ? .pink : .secondary)
                                    Text(s).font(.caption)
                                    Spacer()
                                }
                                .padding(.vertical, 3)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Eisprung") {
                    Picker("Ovulationstest", selection: $ovulationstest) {
                        Text("Kein Test").tag("")
                        Text("Positiv").tag("positiv")
                        Text("Negativ").tag("negativ")
                        Text("Unklar").tag("unklar")
                    }
                }

                Section("Zervixschleim") {
                    Picker("Art", selection: $zervixschleim) {
                        Text("Nicht erfasst").tag("")
                        ForEach(schleimOptionen, id: \.self) { Text($0.capitalized).tag($0) }
                    }
                }

                Section {
                    HStack {
                        TextField("z.B. 36.4", text: $basaltemperatur).keyboardType(.decimalPad)
                        Text("°C").foregroundStyle(.secondary)
                    }
                } header: { Text("Basaltemperatur") }

                Section("Sexuelle Aktivität") {
                    Picker("", selection: $sexuelleAktivitaet) {
                        Text("Keine Angabe").tag("")
                        Text("Geschützt").tag("geschützt")
                        Text("Ungeschützt").tag("ungeschützt")
                    }
                    .pickerStyle(.segmented)
                }

                Section("Notizen") {
                    TextEditor(text: $notizen).frame(minHeight: 60)
                }
            }
            .navigationTitle("Tageseintrag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Speichern") { speichern() } }
            }
            .onAppear { laden() }
        }
    }

    private func laden() {
        guard let e = bestehend else { return }
        istPeriode = e.istPeriode
        blutungsfluss = e.blutungsfluss.isEmpty ? "mittel" : e.blutungsfluss
        symptome = Set(e.symptome.components(separatedBy: ", ").filter { !$0.isEmpty })
        ovulationstest = e.ovulationstest
        zervixschleim = e.zervixschleim
        basaltemperatur = e.basaltemperatur > 0 ? String(format: "%.1f", e.basaltemperatur) : ""
        sexuelleAktivitaet = e.sexuelleAktivitaet
        notizen = e.notizen
    }

    private func speichern() {
        if let alt = bestehend { modelContext.delete(alt) }
        let neu = ZyklusEintrag(datum: Calendar.current.startOfDay(for: datum))
        neu.istPeriode = istPeriode
        neu.blutungsfluss = istPeriode ? blutungsfluss : ""
        neu.symptome = symptome.sorted().joined(separator: ", ")
        neu.ovulationstest = ovulationstest
        neu.zervixschleim = zervixschleim
        neu.basaltemperatur = Double(basaltemperatur.replacingOccurrences(of: ",", with: ".")) ?? 0
        neu.sexuelleAktivitaet = sexuelleAktivitaet
        neu.notizen = notizen
        modelContext.insert(neu)
        dismiss()
    }
}
