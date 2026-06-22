import SwiftUI
import SwiftData

struct PainEntryFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var eintrag: PainEntry?

    @State private var datum = Date()
    @State private var schmerzstaerke = 5
    @State private var koerperstelle = ""
    @State private var schmerzart = ""
    @State private var dauerMinuten = 0
    @State private var ausloeser = ""
    @State private var begleiterscheinungen = ""
    @State private var massnahmen = ""
    @State private var notizen = ""
    @State private var stimmung = 3
    @State private var schlafStunden = 7.0

    var body: some View {
        NavigationStack {
            Form {
                Section("Zeitpunkt") {
                    DatePicker("Datum & Uhrzeit", selection: $datum)
                }

                Section("Schmerz") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Schmerzstärke")
                            Spacer()
                            SchmerzBadge(staerke: schmerzstaerke)
                        }
                        Slider(value: Binding(
                            get: { Double(schmerzstaerke) },
                            set: { schmerzstaerke = Int($0) }
                        ), in: 0...10, step: 1)
                        .tint(SchmerzBadge.farbe(fuer: schmerzstaerke))
                    }
                    .padding(.vertical, 4)

                    TextField("Körperstelle", text: $koerperstelle)
                    TextField("Schmerzart", text: $schmerzart)

                    Stepper("Dauer: \(formatierteDauer(dauerMinuten))", value: $dauerMinuten, in: 0...480, step: 15)
                }

                Section("Auslöser & Symptome") {
                    TextField("Auslöser", text: $ausloeser)
                    TextField("Begleiterscheinungen", text: $begleiterscheinungen)
                    TextField("Massnahmen", text: $massnahmen)
                }

                Section("Wohlbefinden") {
                    HStack {
                        Text("Stimmung")
                        Spacer()
                        HStack(spacing: 6) {
                            ForEach(1...5, id: \.self) { i in
                                Image(systemName: i <= stimmung ? "heart.fill" : "heart")
                                    .font(.title3)
                                    .foregroundStyle(i <= stimmung ? .red : .secondary.opacity(0.4))
                                    .onTapGesture { stimmung = i }
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Schlaf")
                            Spacer()
                            Text(String(format: "%.1f Std.", schlafStunden))
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $schlafStunden, in: 0...12, step: 0.5)
                    }
                    .padding(.vertical, 4)
                }

                Section("Notizen") {
                    TextEditor(text: $notizen)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle(eintrag == nil ? "Neuer Eintrag" : "Eintrag bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { speichern() }
                }
            }
            .onAppear {
                ladeVorhandeneWerte()
                if eintrag == nil { ladeTagesSchlaf() }
            }
        }
    }

    private func ladeTagesSchlaf() {
        let heute = Calendar.current.startOfDay(for: Date())
        let desc = FetchDescriptor<PainEntry>(
            predicate: #Predicate { $0.datum >= heute },
            sortBy: [SortDescriptor(\.datum, order: .reverse)]
        )
        if let letzterHeute = try? modelContext.fetch(desc).first {
            schlafStunden = letzterHeute.schlafStunden
        }
    }

    private func ladeVorhandeneWerte() {
        guard let e = eintrag else { return }
        datum = e.datum
        schmerzstaerke = e.schmerzstaerke
        koerperstelle = e.koerperstelle
        schmerzart = e.schmerzart
        dauerMinuten = e.dauerMinuten
        ausloeser = e.ausloeser
        begleiterscheinungen = e.begleiterscheinungen
        massnahmen = e.massnahmen
        notizen = e.notizen
        stimmung = e.stimmung
        schlafStunden = e.schlafStunden
    }

    private func speichern() {
        if let e = eintrag {
            e.datum = datum
            e.schmerzstaerke = schmerzstaerke
            e.koerperstelle = koerperstelle
            e.schmerzart = schmerzart
            e.dauerMinuten = dauerMinuten
            e.ausloeser = ausloeser
            e.begleiterscheinungen = begleiterscheinungen
            e.massnahmen = massnahmen
            e.notizen = notizen
            e.stimmung = stimmung
            e.schlafStunden = schlafStunden
        } else {
            let neu = PainEntry(
                datum: datum,
                schmerzstaerke: schmerzstaerke,
                koerperstelle: koerperstelle,
                schmerzart: schmerzart,
                dauerMinuten: dauerMinuten,
                ausloeser: ausloeser,
                begleiterscheinungen: begleiterscheinungen,
                massnahmen: massnahmen,
                notizen: notizen,
                stimmung: stimmung,
                schlafStunden: schlafStunden
            )
            modelContext.insert(neu)
        }
        dismiss()
    }

    private func formatierteDauer(_ min: Int) -> String {
        if min == 0 { return "–" }
        let h = min / 60; let m = min % 60
        if h == 0 { return "\(m) Min." }
        if m == 0 { return "\(h) Std." }
        return "\(h) Std. \(m) Min."
    }
}
