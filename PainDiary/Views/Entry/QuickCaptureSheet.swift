import SwiftUI
import SwiftData

/// 1-Screen-Schnellerfassung: Slider ziehen, Stelle antippen, speichern.
/// „Mehr…" öffnet den vollständigen `SchmerzForm`-Wizard.
struct QuickCaptureSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \PainEntry.datum, order: .reverse) private var alleEintraege: [PainEntry]

    var onGespeichert: (() -> Void)? = nil

    @State private var staerke = 5
    @State private var ausgewaehlt: Set<String> = []
    @State private var zeigeKoerperPicker = false
    @State private var pickerText = ""
    @State private var zeigeWizard = false
    @State private var gespeicherterEintrag: PainEntry? = nil
    @State private var detailsBearbeiten: PainEntry? = nil
    private let wetter = WetterService.shared

    private var farbe: Color { SchmerzBadge.farbe(fuer: staerke) }

    /// Häufigste Körperstellen aus bisherigen Schmerz-Einträgen
    private var haeufigeStellen: [String] {
        var zaehler: [String: Int] = [:]
        for e in alleEintraege where !e.istHautEintrag && e.koerperstelle != "Rheuma" {
            for ort in e.koerperstelle.components(separatedBy: ", ") where !ort.isEmpty {
                zaehler[ort, default: 0] += 1
            }
        }
        let top = zaehler.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }.map(\.key)
        var liste = Array(top.prefix(6))
        for std in ["Kopf", "Nacken", "Rücken", "Knie"] where liste.count < 4 && !liste.contains(std) {
            liste.append(std)
        }
        // Manuell gewählte Stellen sichtbar halten
        for a in ausgewaehlt.sorted() where !liste.contains(a) { liste.append(a) }
        return liste
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if let _ = gespeicherterEintrag {
                    erfolgAnsicht
                        .transition(.opacity)
                } else {
                    erfassungsAnsicht
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: gespeicherterEintrag == nil)
            .auroraScreen(schmerzLevel: staerke)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if gespeicherterEintrag == nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Mehr…") { zeigeWizard = true }
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground(.ultraThinMaterial)
        .onAppear { wetter.laden() }
        .sheet(isPresented: $zeigeKoerperPicker) {
            NavigationStack {
                KoerperPickerView(auswahl: $pickerText, tintColor: .systemRed)
                    .navigationTitle("Körperstelle")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Fertig") {
                                let neu = pickerText.components(separatedBy: ", ").filter { !$0.isEmpty }
                                ausgewaehlt.formUnion(neu)
                                zeigeKoerperPicker = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $zeigeWizard) {
            SchmerzForm(onGespeichert: {
                onGespeichert?()
                dismiss()
            })
        }
        .sheet(item: $detailsBearbeiten) { e in
            SchmerzForm(eintrag: e)
        }
    }

    // MARK: - Erfassung

    private var erfassungsAnsicht: some View {
        ScrollView {
            VStack(spacing: 28) {
                Text("Wie stark sind deine Schmerzen?")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)

                VStack(spacing: 6) {
                    SchmerzGauge(wert: Double(staerke), groesse: 190, zahlGroesse: 96)
                    Text(SchmerzSkala.wort(staerke))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(farbe)
                        .contentTransition(.opacity)
                        .animation(.easeInOut(duration: 0.15), value: staerke)
                }

                VStack(spacing: 10) {
                    SchmerzSlider(wert: $staerke)
                    HStack {
                        Text("Kein Schmerz")
                        Spacer()
                        Text("Unerträglich")
                    }
                    .font(.footnote).foregroundStyle(.secondary)
                }
                .glassCard(radius: 24, padding: 20)

                VStack(alignment: .leading, spacing: 12) {
                    GlassSectionLabel("Wo?")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(haeufigeStellen, id: \.self) { ort in
                                GlassChip(titel: ort, aktiv: ausgewaehlt.contains(ort), tint: .red) {
                                    if ausgewaehlt.contains(ort) { ausgewaehlt.remove(ort) } else { ausgewaehlt.insert(ort) }
                                }
                            }
                            GlassChip(titel: "Körper", symbol: "figure.stand", tint: .red) {
                                pickerText = ausgewaehlt.sorted().joined(separator: ", ")
                                zeigeKoerperPicker = true
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 6)
                    }
                }

                Button { speichern() } label: {
                    Label("Speichern", systemImage: "checkmark")
                }
                .buttonStyle(.glassPrimary(tint: farbe, hoehe: 64))
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Bestätigung

    private var erfolgAnsicht: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: gespeicherterEintrag != nil)
            Text("Gespeichert")
                .font(.title.bold())
            Text("Möchtest du noch etwas ergänzen?")
                .font(.subheadline).foregroundStyle(.secondary)

            VStack(spacing: 12) {
                Button {
                    detailsBearbeiten = gespeicherterEintrag
                } label: {
                    Label("Details ergänzen", systemImage: "list.clipboard")
                }
                .buttonStyle(.glassSecondary)

                Button { dismiss() } label: {
                    Text("Fertig")
                }
                .buttonStyle(.glassPrimary(tint: .accentColor, hoehe: 64))
            }
            .padding(.horizontal, 24)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Speichern

    private func speichern() {
        let snap = wetter.aktuell
        let neu = PainEntry(
            datum: Date(),
            schmerzstaerke: staerke,
            koerperstelle: ausgewaehlt.sorted().joined(separator: ", "),
            wetterTemperatur: snap?.temperatur,
            wetterCode: snap?.code,
            wetterWind: snap?.windgeschwindigkeit
        )
        // Schlafstunden vom heutigen letzten Eintrag übernehmen (Standard laut CLAUDE.md)
        let heute = Calendar.current.startOfDay(for: Date())
        if let letzter = alleEintraege.first(where: { $0.datum >= heute }) {
            neu.schlafStunden = letzter.schlafStunden
        }
        modelContext.insert(neu)
#if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
#endif
        onGespeichert?()
        withAnimation { gespeicherterEintrag = neu }
    }
}
