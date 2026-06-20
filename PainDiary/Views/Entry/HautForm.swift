import SwiftUI
import SwiftData

struct HautForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var eintrag: PainEntry? = nil
    var onGespeichert: (() -> Void)? = nil

    @StateObject private var scanService = BodyScanService.shared
    @State private var schritt = 0
    @State private var vorwaerts = true
    @State private var datum = Date()
    @State private var hautStellen = ""
    @State private var scanSetupAnzeigen = false
    @State private var hautArt = ""
    @State private var fotoDateiname = ""
    @State private var verlauf = ""
    @State private var stimmung = 3
    @State private var stressLevel = 3
    @State private var schlafStunden = 7.0
    @State private var notizen = ""
    @State private var zeigeErfolg = false
    @State private var wetterTemperatur: Double? = nil
    @State private var wetterCode: Int? = nil
    @State private var wetterWind: Double? = nil

    private let wetter = WetterService.shared
    private let maxSchritt = 2
    private let schrittNamen = ["Körperstelle", "Hautbild", "Wohlbefinden"]
    private let progressTint: Color = .orange
    private let pflichtSchritte: Set<Int> = [0]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressBar
                    .padding(.horizontal)
                    .padding(.top, 10)

                Group {
                    schrittInhalt
                }
                .frame(maxHeight: .infinity)
                .id(schritt)
                .transition(.asymmetric(
                    insertion: .move(edge: vorwaerts ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: vorwaerts ? .leading : .trailing).combined(with: .opacity)
                ))

                navigationsLeiste
            }
            .navigationTitle(eintrag == nil ? "Hautveränderung" : "Eintrag bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
        .onAppear { laden() }
        .sheet(isPresented: $scanSetupAnzeigen) { BodyScanSetupView() }
        .overlay {
            if zeigeErfolg {
                ZStack {
                    Color.black.opacity(0.25).ignoresSafeArea()
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 72, height: 72)
                                .shadow(color: .green.opacity(0.4), radius: 16, y: 4)
                            Image(systemName: "checkmark")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .scaleEffect(zeigeErfolg ? 1 : 0.3)
                        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: zeigeErfolg)
                        Text("Gespeichert")
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                            .opacity(zeigeErfolg ? 1 : 0)
                            .animation(.easeIn.delay(0.1), value: zeigeErfolg)
                    }
                }
                .transition(.opacity)
            }
        }
    }

    // MARK: - Progress bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(progressTint.opacity(0.15)).frame(height: 3)
                Capsule().fill(progressTint)
                    .frame(width: geo.size.width * CGFloat(schritt + 1) / CGFloat(maxSchritt + 1), height: 3)
                    .animation(.easeInOut(duration: 0.3), value: schritt)
            }
        }
        .frame(height: 3)
    }

    // MARK: - Step content

    @ViewBuilder
    private var schrittInhalt: some View {
        switch schritt {
        case 0:
            koerperstelleSchritt
        case 1:
            ScrollView {
                VStack(spacing: 20) {
                    schrittHeader(symbol: "bandage", titel: "Was zeigt sich?", untertitel: "Hautbild und betroffene Stellen")

                    karte {
                        VStack(alignment: .leading, spacing: 10) {
                            DatePicker("Datum & Uhrzeit", selection: $datum, displayedComponents: [.date, .hourAndMinute])
                            if let snap = wetterAnzeige {
                                Divider()
                                HStack(spacing: 6) {
                                    Image(systemName: snap.symbol)
                                        .foregroundStyle(.yellow)
                                    Text(String(format: "%.0f°C", snap.temperatur))
                                        .font(.caption.bold())
                                    if !snap.luftdruckText.isEmpty {
                                        Text(snap.luftdruckText)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }

                    HautArtFotoStepView(hautArt: $hautArt, fotoDateiname: $fotoDateiname)
                }
                .padding(.horizontal)
                .padding(.vertical, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
        default:
            ScrollView {
                WohlbefindenStepView(
                    stimmung: $stimmung,
                    schlafStunden: $schlafStunden,
                    stressLevel: $stressLevel,
                    notizen: $notizen
                )
                .padding(.vertical, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
        }
    }

    // MARK: - Schritt 0: Körperstelle (Vollbild)

    private var koerperstelleSchritt: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Betroffene Hautstellen")
                    .font(.subheadline.bold())
                Spacer()
                Button {
                    scanSetupAnzeigen = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.stand")
                        Text("Proportionen")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            KoerperPickerView(
                auswahl: $hautStellen,
                tintColor: .systemOrange,
                subRegionenMap: SubRegionen.hautMap
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            let ausgewaehlt = Set(hautStellen.components(separatedBy: ", ").filter { !$0.isEmpty })
            if ausgewaehlt.isEmpty {
                Text("Tippe auf das Modell um eine Stelle auszuwählen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 12)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(ausgewaehlt.sorted(), id: \.self) { r in
                            Button {
                                var s = ausgewaehlt; s.remove(r)
                                hautStellen = s.sorted().joined(separator: ", ")
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                                    Text(r).font(.caption)
                                }
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color.orange.opacity(0.15))
                                .clipShape(Capsule())
                                .foregroundStyle(.orange)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Navigation bar

    private var navigationsLeiste: some View {
        HStack(spacing: 12) {
            if schritt > 0 {
                Button {
                    vorwaerts = false
                    withAnimation { schritt -= 1 }
                } label: {
                    Text("Zurück").font(.subheadline.bold()).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
            }
            if !pflichtSchritte.contains(schritt) && schritt < maxSchritt {
                Button {
                    vorwaerts = true
                    withAnimation { schritt += 1 }
                } label: {
                    Text("Überspringen").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            if schritt < maxSchritt {
                Button {
                    vorwaerts = true
                    withAnimation { schritt += 1 }
                } label: {
                    Text("Weiter ›").font(.subheadline.bold()).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(progressTint, in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
            } else {
                Button { speichern() } label: {
                    Label("Speichern", systemImage: "checkmark").font(.subheadline.bold()).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(progressTint, in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    // MARK: - Card helper

    @ViewBuilder
    private func karte<C: View>(@ViewBuilder content: () -> C) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func schrittHeader(symbol: String, titel: String, untertitel: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 32)).foregroundStyle(progressTint)
            Text(titel).font(.title3.bold())
            Text(untertitel).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.bottom, 4)
    }

    // MARK: - Computed

    private var wetterAnzeige: WetterSnapshot? {
        if let temp = wetterTemperatur, let code = wetterCode {
            return WetterSnapshot(temperatur: temp, code: code, windgeschwindigkeit: wetterWind ?? 0)
        }
        return wetter.aktuell
    }

    // MARK: - Load / Save

    private func laden() {
        if let e = eintrag {
            datum = e.datum
            hautStellen = e.hautStellen
            hautArt = e.hautArt
            fotoDateiname = e.fotoDateiname
            verlauf = e.verlauf
            stimmung = e.stimmung
            schlafStunden = e.schlafStunden
            stressLevel = e.stressLevel
            notizen = e.notizen
            wetterTemperatur = e.wetterTemperatur
            wetterCode = e.wetterCode
            wetterWind = e.wetterWind
            return
        }

        if let snap = wetter.aktuell {
            wetterTemperatur = snap.temperatur
            wetterCode = snap.code
            wetterWind = snap.windgeschwindigkeit
        } else {
            wetter.laden()
        }

        let heute = Calendar.current.startOfDay(for: Date())
        let heuteDesc = FetchDescriptor<PainEntry>(
            predicate: #Predicate { $0.datum >= heute },
            sortBy: [SortDescriptor(\.datum, order: .reverse)]
        )
        if let letzterHeute = try? modelContext.fetch(heuteDesc).first {
            schlafStunden = letzterHeute.schlafStunden
        }
    }

    private func speichern() {
        if let e = eintrag {
            e.datum = datum
            e.hautStellen = hautStellen
            e.koerperstelle = hautStellen
            e.hautArt = hautArt
            e.fotoDateiname = fotoDateiname
            e.verlauf = verlauf
            e.stimmung = stimmung
            e.schlafStunden = schlafStunden
            e.stressLevel = stressLevel
            e.notizen = notizen
        } else {
            let snap = wetter.aktuell
            let finalTemp = wetterTemperatur ?? snap?.temperatur
            let finalCode = wetterCode ?? snap?.code
            let finalWind = wetterWind ?? snap?.windgeschwindigkeit

            let neu = PainEntry(
                datum: datum,
                schmerzstaerke: 0,
                koerperstelle: hautStellen,
                notizen: notizen,
                stimmung: stimmung,
                schlafStunden: schlafStunden,
                stressLevel: stressLevel,
                wetterTemperatur: finalTemp,
                wetterCode: finalCode,
                wetterWind: finalWind,
                hautStellen: hautStellen,
                hautArt: hautArt,
                fotoDateiname: fotoDateiname,
                verlauf: verlauf
            )
            neu.istHautEintrag = true
            modelContext.insert(neu)
        }

#if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
#endif
        zeigeErfolg = true
        onGespeichert?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { dismiss() }
    }
}
