import SwiftUI
import SwiftData
import Charts

/// Diabetes-Dashboard im Bento-Aufbau: Zielbereich-Ring (30 Tage), Kacheln, Messungs-Chips.
struct DiabetesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \BlutzuckerEintrag.datum, order: .reverse) private var messungen: [BlutzuckerEintrag]

    @State private var vm = DiabetesDashboardViewModel()
    @State private var ansicht: ModulAnsicht = .heute
    @State private var zeigeForm = false
    @State private var bearbeitet: BlutzuckerEintrag? = nil
    @State private var zeigeAnalyse = false

    private let tint = Color.blue
    private let spalten = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    private var u: DiabetesUebersicht { vm.uebersicht }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                GlassSegmentPicker(auswahl: $ansicht, optionen: ModulAnsicht.allCases, titel: { $0.rawValue })

                switch ansicht {
                case .heute:
                    heroKarte
                    bentoRaster
                    GlassLinkZeile(symbol: "testtube.2", titel: "Laborwerte", untertitel: "HbA1c, Nierenwerte, Blutbild", tint: tint) {
                        LaborwerteView()
                    }
                    zuletztBereich
                case .verlauf:
                    ChipTageskarten(elemente: messungen, tag: { $0.tag }, datum: { $0.datum }, leerText: "Noch keine Messungen") {
                        messungChip($0, volleBreite: true)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .auroraScreen(.diabetes)
        .navigationTitle("Diabetes")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { zeigeForm = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Messung erfassen")
            }
        }
        .sheet(isPresented: $zeigeForm) { BlutzuckerForm() }
        .sheet(item: $bearbeitet) { BlutzuckerForm(messung: $0) }
        .sheet(isPresented: $zeigeAnalyse) { DiabetesAnalyseView() }
        .onAppear { vm.aktualisiere(messungen: messungen) }
        .onChange(of: messungen) { _, neu in vm.aktualisiere(messungen: neu) }
        .onChange(of: scenePhase) { _, phase in if phase == .active { vm.aktualisiere(messungen: messungen) } }
    }

    // MARK: - Hero

    private var heroKarte: some View {
        VStack(spacing: 12) {
            GlassSectionLabel("Im Zielbereich · 30 Tage")

            GlassRing(
                fortschritt: u.zielAnteil30 ?? 0,
                farbe: zielFarbe,
                mitte: "\(Int(((u.zielAnteil30 ?? 0) * 100).rounded())) %",
                unterzeile: "3,9–7,8 mmol/L",
                platzhalter: u.zielAnteil30 == nil,
                beschreibung: u.zielAnteil30.map { "\(Int(($0 * 100).rounded())) Prozent der Messungen im Zielbereich" } ?? "Noch keine Messungen"
            )

            Text(letzteMessungText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button { zeigeForm = true } label: {
                Label("Messung erfassen", systemImage: "plus")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .glassTintButton(tint, radius: 22)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .glassCard(radius: 28, padding: 20)
    }

    private var zielFarbe: Color { (u.zielAnteil30 ?? 0) >= 0.7 ? .green : .orange }

    private var letzteMessungText: String {
        guard let m = u.letzteMessung else { return "Noch keine Messung erfasst" }
        let zeit = TagBeschriftung.tagUndZeit(tag: m.tag, datum: m.datum)
        return "Letzte Messung \(String(format: "%.1f", m.wert)) mmol/L · \(m.bewertung) · \(zeit)"
    }

    // MARK: - Bento-Raster

    private var bentoRaster: some View {
        LazyVGrid(columns: spalten, spacing: 12) {
            BentoKachel(symbol: "chart.line.uptrend.xyaxis", label: "7-Tage-Verlauf", tint: tint, leuchtet: true) {
                sparkline
            }
            .onTapGesture { zeigeAnalyse = true }

            BentoKachel(
                symbol: "drop.fill", label: u.letzteMessung.map { "Letzte Messung · \($0.bewertung)" } ?? "Letzte Messung",
                tint: tint,
                wert: u.letzteMessung.map { String(format: "%.1f", $0.wert) } ?? "–",
                einheit: u.letzteMessung == nil ? nil : "mmol/L"
            )

            BentoKachel(
                symbol: "sunrise.fill", label: "Ø Nüchtern · 30 Tage", tint: tint,
                wert: u.nuechternSchnitt30.map { String(format: "%.1f", $0) } ?? "–",
                einheit: u.nuechternSchnitt30 == nil ? nil : "mmol/L"
            )

            BentoKachel(
                symbol: "exclamationmark.triangle.fill", label: "Unterzuckerungen · 30 Tage", tint: tint,
                leuchtet: u.hypos30 > 0, wert: "\(u.hypos30)"
            )

            BentoKachel(
                symbol: "syringe.fill", label: "Insulin heute", tint: tint,
                wert: String(format: "%.0f", u.insulinHeute), einheit: "IE"
            )

            BentoKachel(
                symbol: "checkmark.circle", label: "Messungen · 30 Tage", tint: tint,
                wert: "\(u.anzahl30)"
            )
        }
    }

    private var sparkline: some View {
        let werte = Array(u.verlauf7.enumerated())
        return Chart(werte, id: \.offset) { index, wert in
            AreaMark(x: .value("Tag", index), y: .value("mmol/L", wert))
                .foregroundStyle(LinearGradient(colors: [tint.opacity(0.45), tint.opacity(0)], startPoint: .top, endPoint: .bottom))
                .interpolationMethod(.catmullRom)
            LineMark(x: .value("Tag", index), y: .value("mmol/L", wert))
                .foregroundStyle(tint)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .interpolationMethod(.catmullRom)
            if index == werte.count - 1 {
                PointMark(x: .value("Tag", index), y: .value("mmol/L", wert))
                    .foregroundStyle(Color.white)
                    .symbolSize(50)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 2...14)
        .frame(height: 48)
        .overlay {
            if werte.isEmpty { Text("Noch keine Messungen").font(.caption2).foregroundStyle(.secondary) }
        }
        .accessibilityLabel("Blutzucker der letzten 7 Tage")
    }

    // MARK: - Zuletzt

    private var zuletztBereich: some View {
        VStack(spacing: 8) {
            ZuletztKopf { withAnimation { ansicht = .verlauf } }

            if messungen.isEmpty {
                Text("Tippe auf „Messung erfassen“, um deine erste Blutzuckermessung einzutragen.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .glassCard(radius: 22, padding: 16)
            } else {
                ChipStreifen(elemente: messungen) { messungChip($0, volleBreite: false) }

                Button { zeigeAnalyse = true } label: {
                    Label("Diabetes-Analyse öffnen", systemImage: "chart.bar.xaxis.ascending")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .glassTintButton(tint, radius: 20)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func messungChip(_ m: BlutzuckerEintrag, volleBreite: Bool) -> some View {
        var untertitel = "\(TagBeschriftung.tagUndZeit(tag: m.tag, datum: m.datum)) · \(m.messZeitpunkt)"
        if m.insulinEinheiten > 0 { untertitel += String(format: " · %.0f IE", m.insulinEinheiten) }
        return Button { bearbeitet = m } label: {
            GlassEintragChip(
                kennwert: String(format: "%.1f", m.wert),
                titel: "\(String(format: "%.1f", m.wert)) mmol/L · \(m.bewertung)",
                untertitel: untertitel,
                tint: wertFarbe(m.wert),
                hervorgehoben: m.wert < 3.9,
                volleBreite: volleBreite
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { bearbeitet = m } label: { Label("Bearbeiten", systemImage: "pencil") }
            Button(role: .destructive) { modelContext.delete(m) } label: { Label("Löschen", systemImage: "trash") }
        }
    }

    private func wertFarbe(_ wert: Double) -> Color {
        switch wert {
        case ..<3.9:    return .red
        case 3.9..<7.8: return .green
        default:        return .orange
        }
    }
}

// MARK: - Form

struct BlutzuckerForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var messung: BlutzuckerEintrag? = nil
    var onGespeichert: (() -> Void)? = nil

    @State private var schritt = 0
    @State private var vorwaerts = true
    @State private var zeigeErfolg = false
    @State private var datum = Date()
    @State private var wert = 5.5
    @State private var messZeitpunkt = "Nüchtern"
    @State private var erfasseInsulin = false
    @State private var insulinEinheiten = 0.0
    @State private var insulinTyp = "Kurzzeit"
    @State private var kohlenhydrate = 0
    @State private var notizen = ""

    private let zeitpunkte = ["Nüchtern", "Vor Essen", "2h nach Essen", "Vor Schlaf", "Beliebig"]
    private let insulinTypen = ["Kurzzeit", "Langzeit", "Mischung"]
    private let maxSchritt = 2
    private let schrittNamen = ["Messung", "Insulin & Mahlzeit", "Notizen"]
    private let progressTint: Color = .blue
    private let pflichtSchritte: Set<Int> = [0]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressBar
                    .padding(.horizontal)
                    .padding(.top, 10)

                schrittInhalt
                    .frame(maxHeight: .infinity)
                    .id(schritt)
                    .transition(.asymmetric(
                        insertion: .move(edge: vorwaerts ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: vorwaerts ? .leading : .trailing).combined(with: .opacity)
                    ))

                navigationsLeiste
            }
            .navigationTitle(messung == nil ? "Neue Messung" : "Messung bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
            }
        }
        .onAppear { laden() }
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
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 3)
                    Capsule()
                        .fill(progressTint)
                        .frame(
                            width: geo.size.width * (maxSchritt > 0 ? CGFloat(schritt) / CGFloat(maxSchritt) : 0),
                            height: 3
                        )
                        .animation(.spring(response: 0.4), value: schritt)
                }
            }
            .frame(height: 3)

            HStack {
                Text("Schritt \(schritt + 1) von \(maxSchritt + 1)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(schritt < schrittNamen.count ? schrittNamen[schritt] : "")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Step content

    @ViewBuilder
    private var schrittInhalt: some View {
        switch schritt {
        case 0:
            ScrollView {
                messungSchritt.padding(.vertical, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .auroraScreen(.diabetes)
        case 1:
            ScrollView {
                insulinMahlzeitSchritt.padding(.vertical, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .auroraScreen(.diabetes)
        default:
            ScrollView {
                notizenSchritt.padding(.vertical, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .auroraScreen(.diabetes)
        }
    }

    // MARK: - Schritt 0: Messung

    private var messungSchritt: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Image(systemName: "drop.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.blue)
                Text("Blutzucker")
                    .font(.title2.bold())
            }
            .padding(.top, 8)

            karte {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Messwert").font(.headline)
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(bewertungFarbe.opacity(0.15))
                                .frame(width: 104, height: 104)
                            Circle()
                                .strokeBorder(bewertungFarbe, lineWidth: 5)
                                .frame(width: 104, height: 104)
                            VStack(spacing: 1) {
                                Text(String(format: "%.1f", wert))
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                                    .foregroundStyle(bewertungFarbe)
                                Text("mmol/L")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: wert)
                        Spacer()
                    }
                    Text(bewertungLabel)
                        .font(.subheadline.bold())
                        .foregroundStyle(bewertungFarbe)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Slider(value: $wert, in: 1.0...30.0, step: 0.1).tint(bewertungFarbe)
                    HStack {
                        Text("1.0").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("30.0 mmol/L").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            karte {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Messzeitpunkt").font(.headline)
                    FlowLayout(zeitpunkte) { zp in
                        Button {
                            messZeitpunkt = zp
                        } label: {
                            Text(zp)
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(messZeitpunkt == zp ? Color.blue : Color.glassFill)
                                .foregroundStyle(messZeitpunkt == zp ? .white : .primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            karte {
                DatePicker("Datum & Uhrzeit", selection: $datum, displayedComponents: [.date, .hourAndMinute])
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    // MARK: - Schritt 1: Insulin & Mahlzeit

    private var insulinMahlzeitSchritt: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Image(systemName: "syringe.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.blue)
                Text("Insulin & Mahlzeit")
                    .font(.title2.bold())
            }
            .padding(.top, 8)

            karte {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: $erfasseInsulin) {
                        HStack(spacing: 10) {
                            Image(systemName: "syringe")
                                .foregroundStyle(.blue)
                            Text("Insulin injiziert")
                                .font(.headline)
                        }
                    }
                    .tint(.blue)

                    if erfasseInsulin {
                        Divider()
                        Stepper(String(format: "%.0f IE", insulinEinheiten),
                                value: $insulinEinheiten, in: 0...100, step: 0.5)
                            .font(.subheadline)

                        HStack(spacing: 8) {
                            ForEach(insulinTypen, id: \.self) { typ in
                                Button {
                                    insulinTyp = typ
                                } label: {
                                    Text(typ)
                                        .font(.subheadline)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(insulinTyp == typ ? Color.blue : Color.glassFill)
                                        .foregroundStyle(insulinTyp == typ ? .white : .primary)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            karte {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Mahlzeit").font(.headline)
                    Stepper("\(kohlenhydrate) g Kohlenhydrate",
                            value: $kohlenhydrate, in: 0...300, step: 5)
                        .font(.subheadline)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    // MARK: - Schritt 2: Notizen

    private var notizenSchritt: some View {
        VStack(spacing: 16) {
            Text("Notizen")
                .font(.title2.bold())
                .padding(.top, 8)

            karte {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notizen").font(.headline)
                    TextEditor(text: $notizen)
                        .frame(minHeight: 120)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    // MARK: - Navigation bar

    private var navigationsLeiste: some View {
        HStack(spacing: 12) {
            if schritt > 0 {
                Button {
                    vorwaerts = false
                    withAnimation(.easeInOut(duration: 0.25)) { schritt -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 40, height: 40)
                        .background(Color.glassFill, in: Circle())
                }
                .buttonStyle(.plain)
            } else {
                Spacer().frame(width: 40)
            }

            Spacer()

            if !pflichtSchritte.contains(schritt) && schritt < maxSchritt {
                Button {
                    vorwaerts = true
                    withAnimation(.easeInOut(duration: 0.25)) { schritt += 1 }
                } label: {
                    Text("Überspringen")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if schritt < maxSchritt {
                Button {
                    vorwaerts = true
                    withAnimation(.easeInOut(duration: 0.25)) { schritt += 1 }
                } label: {
                    Text("Weiter ›")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(progressTint, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            } else {
                Button { speichern() } label: {
                    Text("✓ Speichern")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(Color.green, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(wert <= 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(.bar)
    }

    // MARK: - Card helper

    @ViewBuilder
    private func karte<C: View>(@ViewBuilder content: () -> C) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassFill()
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Computed helpers

    private var bewertungLabel: String {
        switch wert {
        case ..<3.9:    return "Hypo ⚠"
        case 3.9..<6.0: return "Normal ✓"
        case 6.0..<7.8: return "Erhöht"
        default:        return "Zu hoch"
        }
    }

    private var bewertungFarbe: Color {
        switch wert {
        case ..<3.9:    return .red
        case 3.9..<7.8: return .green
        default:        return .orange
        }
    }

    // MARK: - Load / Save

    private func laden() {
        guard let m = messung else { return }
        datum = m.datum; wert = m.wert; messZeitpunkt = m.messZeitpunkt
        erfasseInsulin = m.insulinEinheiten > 0
        insulinEinheiten = m.insulinEinheiten
        insulinTyp = m.insulinTyp.isEmpty ? "Kurzzeit" : m.insulinTyp
        kohlenhydrate = m.kohlenhydrate; notizen = m.notizen
    }

    private func speichern() {
        if let m = messung {
            m.datum = datum; m.wert = wert; m.messZeitpunkt = messZeitpunkt
            m.insulinEinheiten = erfasseInsulin ? insulinEinheiten : 0
            m.insulinTyp = erfasseInsulin ? insulinTyp : ""
            m.kohlenhydrate = kohlenhydrate; m.notizen = notizen
        } else {
            let neu = BlutzuckerEintrag(
                datum: datum, wert: wert, messZeitpunkt: messZeitpunkt,
                insulinEinheiten: erfasseInsulin ? insulinEinheiten : 0,
                insulinTyp: erfasseInsulin ? insulinTyp : "",
                kohlenhydrate: kohlenhydrate, notizen: notizen
            )
            if (try? modelContext.einfuegenValidiert(neu)) == nil {
                // Wert außerhalb des Messbereichs → begrenzen statt Erfassung zu verlieren
                neu.wert = neu.wert.isFinite ? neu.wert.begrenzt(auf: Wertebereich.blutzucker) : Wertebereich.blutzucker.lowerBound
                modelContext.insert(neu)
            }
        }
#if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
#endif
        zeigeErfolg = true
        onGespeichert?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { dismiss() }
    }
}
