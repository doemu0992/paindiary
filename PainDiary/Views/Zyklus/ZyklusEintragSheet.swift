import SwiftUI
import SwiftData
import Charts

/// Tages-Sheet des Zyklus-Trackers (Glas-Karten, ein Bildschirm).
/// Ein Eintrag pro Kalendertag: existiert für den Tag bereits einer, wird er bearbeitet statt dupliziert.
struct ZyklusEintragSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ZyklusEintrag.datum, order: .reverse) private var alleEintraege: [ZyklusEintrag]

    let datum: Date
    let bestehend: ZyklusEintrag?

    @AppStorage("zusatzSymptome") private var zusatzSymptomeLegacy: String = ""
    @State private var customSymptome: [String] = []
    @State private var neuesSymptom = ""
    @State private var zeigeLoeschDialog = false

    @State private var fluss: Blutungsfluss
    @State private var nurHalberTag: Bool
    @State private var symptome: Set<String>
    @State private var lhTest: LHTest
    @State private var schleim: Zervixschleim
    @State private var basaltemperatur: String
    @State private var sexAktivitaet: SexAktivitaet
    @State private var notizen: String
    @State private var eisprungBestaetigt: Bool

    private static let chipSchluessel = "zyklusCustomSymptome"

    private let basisSymptome = [
        "Krämpfe", "Kopfschmerzen", "Rückenschmerzen", "Brustspannen",
        "Völlegefühl", "Blähungen", "Übelkeit", "Müdigkeit",
        "Reizbarkeit", "Stimmungsschwankungen", "Akne", "Schlafprobleme",
        "Hitzewallungen", "Appetitsteigerung"
    ]

    init(datum: Date, bestehend: ZyklusEintrag?) {
        self.datum = datum
        self.bestehend = bestehend
        if let e = bestehend {
            _fluss = State(initialValue: e.hatBlutung ? (e.fluss == .keine ? .mittel : e.fluss) : .keine)
            _nurHalberTag = State(initialValue: e.nurHalberTag)
            _symptome = State(initialValue: Set(ListenFeld.parse(e.symptome)))
            _lhTest = State(initialValue: e.lhTest)
            _schleim = State(initialValue: e.schleim)
            _basaltemperatur = State(initialValue: e.basaltemperatur > 0 ? String(format: "%.2f", e.basaltemperatur) : "")
            _sexAktivitaet = State(initialValue: e.sexAktivitaet)
            _notizen = State(initialValue: e.notizen)
            _eisprungBestaetigt = State(initialValue: e.eisprungBestaetigt)
        } else {
            _fluss = State(initialValue: .keine)
            _nurHalberTag = State(initialValue: false)
            _symptome = State(initialValue: [])
            _lhTest = State(initialValue: .keine)
            _schleim = State(initialValue: .keine)
            _basaltemperatur = State(initialValue: "")
            _sexAktivitaet = State(initialValue: .keine)
            _notizen = State(initialValue: "")
            _eisprungBestaetigt = State(initialValue: false)
        }
    }

    // MARK: - Abgeleitete Werte

    private var kal: Calendar { Calendar.current }

    private var vorhandenerEintrag: ZyklusEintrag? {
        bestehend ?? alleEintraege.first { $0.tag == DayKey(datum, zeitzone: kal.timeZone) }
    }

    private var bbtWert: Double? {
        let text = basaltemperatur.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        return text.isEmpty ? nil : Double(text)
    }

    private var bbtGueltig: Bool {
        guard let w = bbtWert else { return basaltemperatur.trimmingCharacters(in: .whitespaces).isEmpty }
        return ZyklusGrenzen.bbtBereich.contains(w)
    }

    private var istLeer: Bool {
        fluss == .keine &&
        symptome.isEmpty &&
        lhTest == .keine &&
        schleim == .keine &&
        bbtWert == nil &&
        sexAktivitaet == .keine &&
        !eisprungBestaetigt &&
        notizen.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var alleSymptome: [String] {
        let extra = customSymptome.filter { !basisSymptome.contains($0) }
        let uebrige = symptome.filter { !basisSymptome.contains($0) && !extra.contains($0) }.sorted()
        return basisSymptome + extra + uebrige
    }

    private var kontextText: String? {
        let analyse = ZyklusRechner.analyse(eintraege: alleEintraege)
        guard let start = analyse.zyklusStarts.last(where: { $0 <= kal.startOfDay(for: datum) }) else { return nil }
        let zt = (kal.dateComponents([.day], from: start, to: kal.startOfDay(for: datum)).day ?? 0) + 1
        guard zt <= 91 else { return nil }
        let phase = ZyklusRechner.phase(for: datum, analyse: analyse)?.rawValue
        return phase.map { "Zyklustag \(zt) · \($0)" } ?? "Zyklustag \(zt)"
    }

    private var bbtVerlauf: [ZyklusEintrag] {
        guard let von = kal.date(byAdding: .day, value: -20, to: datum),
              let bis = kal.date(byAdding: .day, value: 1, to: kal.startOfDay(for: datum)) else { return [] }
        return alleEintraege.filter { $0.basaltemperatur > 0 && $0.datum >= von && $0.datum < bis }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if let k = kontextText {
                        Text(k)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    blutungKarte
                    schleimKarte
                    lhKarte
                    temperaturKarte
                    symptomKarte
                    sexKarte
                    notizKarte
                    if vorhandenerEintrag != nil {
                        Button(role: .destructive) { zeigeLoeschDialog = true } label: {
                            Label("Eintrag löschen", systemImage: "trash")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red)
                        .glassCard(radius: 16, padding: 0)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .auroraScreen(.zyklus)
            .navigationTitle(datum.formatted(.dateTime.weekday(.abbreviated).day().month(.wide).year().locale(ZyklusLocale.de)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { speichern() }
                        .fontWeight(.bold)
                        .disabled(!bbtGueltig)
                }
            }
            .confirmationDialog("Eintrag für diesen Tag löschen?", isPresented: $zeigeLoeschDialog, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) { loeschen() }
                Button("Abbrechen", role: .cancel) {}
            }
        }
        .environment(\.locale, ZyklusLocale.de)
        .presentationDragIndicator(.visible)
        .onAppear(perform: ladeCustomSymptome)
    }

    // MARK: - Karten

    private func karte<Inhalt: View>(_ titel: String, info: (String, String)? = nil,
                                     @ViewBuilder inhalt: () -> Inhalt) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                Text(titel.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if let info { InfoButton(titel: info.0, text: info.1) }
                Spacer(minLength: 0)
            }
            inhalt()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 20, padding: 0)
    }

    private var blutungKarte: some View {
        karte("Blutung") {
            OptionsZeile(
                optionen: [Blutungsfluss.keine, .schmierblutung, .leicht, .mittel, .stark],
                auswahl: $fluss, farbe: ZyklusFarbe.periode,
                titel: { $0 == .schmierblutung ? "Schmier" : $0.titel },
                symbol: { $0 == .keine ? "circle" : "drop.fill" }
            )
            if fluss == .schmierblutung {
                Text("Schmierblutungen (Spotting) zählen nicht als Zyklusstart.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            if fluss != .keine {
                Toggle("Nur halber Tag", isOn: $nurHalberTag)
                    .font(.subheadline)
            }
        }
    }

    private var schleimKarte: some View {
        karte("Zervixschleim", info: ("Zervixschleim-Typen",
              "Trocken: kein Schleim, eher unfruchtbar.\nKlebrig: zäh, trüb.\nCremig: weiß, cremig – Übergang.\nWässrig: klar, fließend – fruchtbar.\nEiweiß: dehnbar wie rohes Eiweiß – höchste Fruchtbarkeit, typisch um den Eisprung.")) {
            OptionsZeile(
                optionen: [Zervixschleim.trocken, .klebrig, .cremig, .waessrig, .eiweiss],
                auswahl: Binding(get: { schleim }, set: { schleim = ($0 == schleim) ? .keine : $0 }),
                farbe: .blue,
                titel: { $0.titel },
                symbol: { s in
                    switch s {
                    case .trocken:  return "wind"
                    case .klebrig:  return "link"
                    case .cremig:   return "cloud.fill"
                    case .waessrig: return "drop.fill"
                    case .eiweiss:  return "oval.fill"
                    case .keine:    return "minus"
                    }
                }
            )
        }
    }

    private var lhKarte: some View {
        karte("Ovulationstest (LH)", info: ("Ovulationstest (LH-Test)",
              "Ein LH-Test zeigt den Anstieg des luteinisierenden Hormons, der etwa 24–36 Stunden vor dem Eisprung auftritt. Ein positiver Test verschiebt die Eisprung-Prognose der App auf den Folgetag.")) {
            OptionsZeile(
                optionen: [LHTest.keine, .negativ, .positiv, .unklar],
                auswahl: $lhTest, farbe: ZyklusFarbe.eisprung,
                titel: { $0.titel }
            )
            Toggle(isOn: $eisprungBestaetigt) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Eisprung an diesem Tag bestätigt").font(.subheadline.weight(.semibold))
                    Text("Du weißt es sicher (z. B. Ultraschall, Schmerz, Temperatur). Die App richtet Fruchtbarkeit und nächste Periode danach aus.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .tint(ZyklusFarbe.eisprung)
        }
    }

    private var temperaturKarte: some View {
        karte("Basaltemperatur", info: ("Basaltemperatur",
              "Morgentemperatur direkt nach dem Aufwachen, vor jeder Aktivität. Nach dem Eisprung steigt sie um etwa 0,2–0,5 °C und bleibt bis zur nächsten Periode erhöht. Die App bestätigt den Eisprung rückblickend nach der 3-über-6-Regel (mind. 9 Messungen im Zyklus).")) {
            HStack {
                TextField("36,50", text: $basaltemperatur)
                    .keyboardType(.decimalPad)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.leading)
                Text("°C").foregroundStyle(.secondary)
            }
            if !bbtGueltig {
                Text("Bitte einen Wert zwischen 34,0 und 42,0 °C eingeben.")
                    .font(.caption).foregroundStyle(.red)
            }
            let verlauf = bbtVerlauf
            if verlauf.count >= 2 {
                Chart(verlauf, id: \.persistentModelID) { e in
                    LineMark(x: .value("Tag", e.datum, unit: .day), y: .value("°C", e.basaltemperatur))
                        .foregroundStyle(Color.pink)
                        .interpolationMethod(.monotone)
                    PointMark(x: .value("Tag", e.datum, unit: .day), y: .value("°C", e.basaltemperatur))
                        .foregroundStyle(Color.pink)
                        .symbolSize(18)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 56)
            }
        }
    }

    private var symptomKarte: some View {
        karte("Symptome") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                ForEach(alleSymptome, id: \.self) { s in
                    let aktiv = symptome.contains(s)
                    Button {
                        if aktiv { symptome.remove(s) } else { symptome.insert(s) }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: aktiv ? "checkmark.circle.fill" : "circle")
                                .font(.caption)
                            Text(s).font(.caption).lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(aktiv ? Color.pink : Color.primary)
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(aktiv ? Color.pink.opacity(0.15) : Color.secondary.opacity(0.08),
                                    in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(aktiv ? .isSelected : [])
                }
            }
            HStack(spacing: 8) {
                TextField("Eigenes Symptom", text: $neuesSymptom)
                    .font(.subheadline)
                    .submitLabel(.done)
                    .onSubmit(symptomHinzufuegen)
                Button(action: symptomHinzufuegen) {
                    Image(systemName: "plus.circle.fill").font(.title3).foregroundStyle(.pink)
                }
                .buttonStyle(.plain)
                .disabled(neuesSymptom.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel("Symptom hinzufügen")
            }
        }
    }

    private var sexKarte: some View {
        karte("Sexuelle Aktivität") {
            OptionsZeile(
                optionen: [SexAktivitaet.keine, .geschuetzt, .ungeschuetzt],
                auswahl: $sexAktivitaet, farbe: .pink,
                titel: { $0.titel }
            )
        }
    }

    private var notizKarte: some View {
        karte("Notizen") {
            TextEditor(text: $notizen)
                .font(.subheadline)
                .frame(minHeight: 70)
                .scrollContentBackground(.hidden)
        }
    }

    // MARK: - Aktionen

    private func ladeCustomSymptome() {
        // Migration: alte `|`-getrennte Liste → ChipSpeicher (CLAUDE.md: Custom-Chip-Persistenz)
        if !zusatzSymptomeLegacy.isEmpty {
            for s in zusatzSymptomeLegacy.components(separatedBy: "|") where !s.isEmpty {
                ChipSpeicher.hinzufuegen(s, schluessel: Self.chipSchluessel)
            }
            zusatzSymptomeLegacy = ""
        }
        customSymptome = ChipSpeicher.laden(schluessel: Self.chipSchluessel)
    }

    private func symptomHinzufuegen() {
        let s = ListenFeld.bereinige(neuesSymptom)
        neuesSymptom = ""
        guard !s.isEmpty else { return }
        ChipSpeicher.hinzufuegen(s, schluessel: Self.chipSchluessel)
        customSymptome = ChipSpeicher.laden(schluessel: Self.chipSchluessel)
        symptome.insert(s)
    }

    /// Notification-IDs des Zyklus sind global → nach jeder Änderung neu planen (nicht nur löschen).
    private func erinnerungenNeuPlanen(entfernt: ZyklusEintrag?, neu: ZyklusEintrag?) {
        var liste = alleEintraege.filter { $0 !== entfernt }
        if let neu, !liste.contains(where: { $0 === neu }) { liste.append(neu) }
        NotificationManager.shared.planeZyklusErinnerungen(eintraege: liste)
    }

    private func speichern() {
        guard bbtGueltig else { return }
        let vorhanden = vorhandenerEintrag

        if istLeer {
            if let alt = vorhanden { modelContext.delete(alt) }
            erinnerungenNeuPlanen(entfernt: vorhanden, neu: nil)
            dismiss()
            return
        }

        let eintrag: ZyklusEintrag
        if let alt = vorhanden {
            eintrag = alt
        } else {
            eintrag = ZyklusEintrag(datum: kal.startOfDay(for: datum))
            modelContext.insert(eintrag)
        }
        eintrag.typ = ""   // Legacy-Feld: sonst bliebe ein alter "Periode"-Typ trotz Abwahl wirksam
        eintrag.istPeriode = fluss != .keine
        eintrag.fluss = fluss
        eintrag.nurHalberTag = fluss != .keine ? nurHalberTag : false
        eintrag.symptome = ListenFeld.join(symptome.sorted())
        eintrag.lhTest = lhTest
        eintrag.schleim = schleim
        eintrag.basaltemperatur = bbtWert ?? 0
        eintrag.sexAktivitaet = sexAktivitaet
        eintrag.notizen = notizen
        eintrag.eisprungBestaetigt = eisprungBestaetigt
        erinnerungenNeuPlanen(entfernt: nil, neu: eintrag)
        dismiss()
    }

    private func loeschen() {
        let vorhanden = vorhandenerEintrag
        if let alt = vorhanden { modelContext.delete(alt) }
        erinnerungenNeuPlanen(entfernt: vorhanden, neu: nil)
        dismiss()
    }
}

// MARK: - Options-Zeile (Button-Grid in einer Reihe)

private struct OptionsZeile<T: Hashable>: View {
    let optionen: [T]
    @Binding var auswahl: T
    let farbe: Color
    let titel: (T) -> String
    var symbol: ((T) -> String)? = nil

    var body: some View {
        HStack(spacing: 6) {
            ForEach(optionen, id: \.self) { option in
                let aktiv = auswahl == option
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { auswahl = option }
                } label: {
                    VStack(spacing: 4) {
                        if let symbol {
                            Image(systemName: symbol(option)).font(.system(size: 16))
                        }
                        Text(titel(option))
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(aktiv ? farbe : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(aktiv ? farbe.opacity(0.18) : Color.secondary.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(aktiv ? farbe.opacity(0.6) : Color.clear, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(aktiv ? .isSelected : [])
            }
        }
    }
}
