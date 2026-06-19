import SwiftUI
import SwiftData

struct DiabetesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BlutzuckerEintrag.datum, order: .reverse) private var messungen: [BlutzuckerEintrag]

    @State private var zeigeForm = false
    @State private var bearbeitet: BlutzuckerEintrag? = nil
    @State private var zeigeAnalyse = false

    private var messungen30: [BlutzuckerEintrag] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return messungen.filter { $0.datum >= cutoff }
    }

    var body: some View {
        List {
            statistikSektion

            Section("Weiterführend") {
                NavigationLink(destination: LaborwerteView()) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Laborwerte")
                            Text("HbA1c, Nierenwerte, Blutbild")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "testtube.2").foregroundStyle(.blue)
                    }
                }
            }

            if messungen.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Keine Messungen",
                        systemImage: "drop.fill",
                        description: Text("Tippe auf + um eine Blutzuckermessung einzutragen.")
                    )
                    .listRowSeparator(.hidden)
                }
            } else {
                Section("Messungen") {
                    ForEach(messungen) { m in
                        BlutzuckerZeile(messung: m)
                            .contentShape(Rectangle())
                            .onTapGesture { bearbeitet = m }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    modelContext.delete(m)
                                } label: { Label("Löschen", systemImage: "trash") }
                                Button { bearbeitet = m } label: { Label("Bearbeiten", systemImage: "pencil") }
                                    .tint(.blue)
                            }
                    }
                    .onDelete { idx in idx.forEach { modelContext.delete(messungen[$0]) } }
                }
            }
        }
        .navigationTitle("Diabetes")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { zeigeForm = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $zeigeForm) { BlutzuckerForm() }
        .sheet(item: $bearbeitet) { BlutzuckerForm(messung: $0) }
        .sheet(isPresented: $zeigeAnalyse) { DiabetesAnalyseView() }
    }

    // MARK: - Stats

    private var statistikSektion: some View {
        Section {
            let nuechtern = messungen30.filter { $0.messZeitpunkt == "Nüchtern" && $0.wert > 0 }
            let avgNuechtern: Double? = nuechtern.isEmpty ? nil
                : nuechtern.map(\.wert).reduce(0, +) / Double(nuechtern.count)
            let imZiel = messungen30.filter(\.zielbereich).count
            let pctZiel = messungen30.isEmpty ? 0
                : Int(Double(imZiel) / Double(messungen30.count) * 100)

            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    Label("30-Tage-Überblick", systemImage: "chart.bar.fill")
                        .font(.headline).foregroundStyle(.blue)
                    Divider()
                    HStack(spacing: 0) {
                        statPill(
                            avgNuechtern.map { String(format: "%.1f", $0) } ?? "–",
                            label: "Ø Nüchtern",
                            farbe: nuechternFarbe(avgNuechtern)
                        )
                        Divider().frame(height: 40)
                        statPill(
                            messungen.first.map { String(format: "%.1f", $0.wert) } ?? "–",
                            label: "Letzte Messung",
                            farbe: messungen.first.map { wertFarbe($0.wert) } ?? .secondary
                        )
                        Divider().frame(height: 40)
                        statPill(
                            messungen30.isEmpty ? "–" : "\(pctZiel)%",
                            label: "Im Zielbereich",
                            farbe: pctZiel >= 70 ? .green : .orange
                        )
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)

                Button { zeigeAnalyse = true } label: {
                    Label("Diabetes-Analyse öffnen", systemImage: "chart.bar.xaxis.ascending")
                        .font(.subheadline.bold()).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color.blue, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.clear)
    }

    private func statPill(_ wert: String, label: String, farbe: Color) -> some View {
        VStack(spacing: 4) {
            Text(wert).font(.title2.bold()).foregroundStyle(farbe)
            Text(label).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func nuechternFarbe(_ wert: Double?) -> Color {
        guard let w = wert else { return .secondary }
        switch w {
        case ..<3.9:    return .red
        case 3.9..<6.0: return .green
        case 6.0..<7.0: return .orange
        default:        return .red
        }
    }

    private func wertFarbe(_ wert: Double) -> Color {
        switch wert {
        case ..<3.9:   return .red
        case 3.9..<7.8: return .green
        default:        return .orange
        }
    }
}

// MARK: - Zeile

private struct BlutzuckerZeile: View {
    let messung: BlutzuckerEintrag

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(farbe.opacity(0.15)).frame(width: 46, height: 46)
                VStack(spacing: 1) {
                    Text(String(format: "%.1f", messung.wert))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(farbe)
                    Text("mmol").font(.system(size: 8)).foregroundStyle(farbe.opacity(0.7))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(messung.datum, style: .date).font(.subheadline.bold())
                    Text(messung.datum, style: .time).font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Text(messung.messZeitpunkt).font(.caption).foregroundStyle(.secondary)
                    Text(messung.bewertung)
                        .font(.caption2.bold())
                        .foregroundStyle(farbe)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(farbe.opacity(0.12)).clipShape(Capsule())
                }
                if messung.insulinEinheiten > 0 {
                    Text(String(format: "%.0f IE Insulin (%@)", messung.insulinEinheiten, messung.insulinTyp))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }

    private var farbe: Color {
        switch messung.wert {
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
            .background(Color(.systemGroupedBackground))
        case 1:
            ScrollView {
                insulinMahlzeitSchritt.padding(.vertical, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
        default:
            ScrollView {
                notizenSchritt.padding(.vertical, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
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
                                .background(messZeitpunkt == zp ? Color.blue : Color(.tertiarySystemBackground))
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
                                        .background(insulinTyp == typ ? Color.blue : Color(.tertiarySystemBackground))
                                        .foregroundStyle(insulinTyp == typ ? .white : .primary)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
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
                        .background(Color(.secondarySystemBackground), in: Circle())
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
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
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
