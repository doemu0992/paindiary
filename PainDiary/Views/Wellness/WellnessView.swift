import SwiftUI
import SwiftData
import Charts

struct WellnessView: View {

    // MARK: - Wasser
    @State private var wasserMl: Int = 0
    @State private var wasserZielMl: Int = 2000
    @AppStorage("wasserErinnerungAktiv") private var wasserErinnerungAktiv = false
    @AppStorage("wasserErinnerungZeit") private var wasserErinnerungZeitSek = 54000.0

    // MARK: - Ernährung
    @State private var koffeinTassen: Int = 0
    @State private var alkoholGlaeser: Int = 0
    @State private var fruehstueck: Bool = false
    @State private var mittag: Bool = false
    @State private var abend: Bool = false

    // MARK: - Pain entries für Stimmung/Stress/Schlaf-Analyse
    @Query(sort: \PainEntry.datum, order: .reverse) private var eintraege: [PainEntry]

    @State private var trendTage: Int = 7

    private let notif = NotificationManager.shared

    // MARK: - HealthKit
    @State private var hkSchlaf: Double? = nil
    @State private var hkSchritte: Int? = nil

    // MARK: - Bindings & Keys

    private var wasserErinnerungZeit: Binding<Date> {
        Binding(
            get: { Date(timeIntervalSinceReferenceDate: wasserErinnerungZeitSek) },
            set: { wasserErinnerungZeitSek = $0.timeIntervalSinceReferenceDate }
        )
    }

    private static func datumString(_ offset: Int = 0) -> String {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        return df.string(from: Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date())
    }
    private static let wasserZielKey = "wasserZielMl"
    private func wasserKey(_ offset: Int = 0) -> String { "wasserMl_\(Self.datumString(offset))" }
    private var koffeinKey: String { "koffeinTassen_\(Self.datumString())" }
    private var alkoholKey: String { "alkoholGlaeser_\(Self.datumString())" }
    private var fruehstueckKey: String { "mahlzeitFruehstueck_\(Self.datumString())" }
    private var mittagKey: String { "mahlzeitMittag_\(Self.datumString())" }
    private var abendKey: String { "mahlzeitAbend_\(Self.datumString())" }

    // MARK: - Analytics

    private struct TagesWerte: Identifiable {
        let id = UUID()
        let datum: Date
        let stimmung: Double
        let stress: Double
        let schlaf: Double
    }

    private var trendDaten: [TagesWerte] {
        let kal = Calendar.current
        let heute = kal.startOfDay(for: Date())
        return (0..<trendTage).reversed().compactMap { offset -> TagesWerte? in
            guard let tag = kal.date(byAdding: .day, value: -offset, to: heute) else { return nil }
            let tage = eintraege.filter { kal.isDate($0.datum, inSameDayAs: tag) }
            guard !tage.isEmpty else { return nil }
            let avgS   = Double(tage.map(\.stimmung).reduce(0,+)) / Double(tage.count)
            let avgSt  = Double(tage.map(\.stressLevel).reduce(0,+)) / Double(tage.count)
            let avgSch = tage.map(\.schlafStunden).reduce(0,+) / Double(tage.count)
            return TagesWerte(datum: tag, stimmung: avgS, stress: avgSt, schlaf: avgSch)
        }
    }

    private var wochenAvg: (stimmung: Double, stress: Double, schlaf: Double) {
        let tage = trendDaten
        guard !tage.isEmpty else { return (0, 0, 0) }
        let s   = tage.map(\.stimmung).reduce(0,+) / Double(tage.count)
        let st  = tage.map(\.stress).reduce(0,+) / Double(tage.count)
        let sch = tage.filter { $0.schlaf > 0 }.map(\.schlaf)
        return (s, st, sch.isEmpty ? 0 : sch.reduce(0,+) / Double(sch.count))
    }

    private var trendLabel: String {
        switch trendTage {
        case 30: return "30 Tage"
        case 90: return "90 Tage"
        default: return "7 Tage"
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                wochenZusammenfassung
                if HealthKitManager.shared.istVerfuegbar { healthKitKarte }
                wasserTrackerKarte
                ernaehrungKarte
                if !trendDaten.isEmpty {
                    stimmungStressKarte
                    schlafKarte
                }
                streakKarte
            }
            .padding()
            .padding(.bottom, 30)
        }
        .navigationTitle("Wohlbefinden")
        .onAppear {
            ladeDaten()
            Task {
                await HealthKitManager.shared.berechtigungAnfordern()
                hkSchlaf   = await HealthKitManager.shared.schlafStundenLetztteNacht()
                hkSchritte = await HealthKitManager.shared.schritteDiesemTag()
            }
        }
    }

    // MARK: - HealthKit Karte

    private var healthKitKarte: some View {
        VStack(spacing: 14) {
            HStack {
                Label("Gesundheit (HealthKit)", systemImage: "heart.text.square.fill")
                    .font(.headline).foregroundStyle(.red)
                Spacer()
                Button {
                    Task {
                        hkSchlaf   = await HealthKitManager.shared.schlafStundenLetztteNacht()
                        hkSchritte = await HealthKitManager.shared.schritteDiesemTag()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise").font(.caption).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 0) {
                VStack(spacing: 6) {
                    Image(systemName: "moon.zzz.fill").font(.title2).foregroundStyle(.indigo)
                    if let schlaf = hkSchlaf {
                        Text(String(format: "%.1fh", schlaf))
                            .font(.title3.bold()).foregroundStyle(.indigo)
                        Text(schlaf >= 7 ? "Gut" : schlaf >= 6 ? "Okay" : "Zu wenig")
                            .font(.caption2.bold())
                            .foregroundStyle(schlaf >= 7 ? .green : schlaf >= 6 ? .orange : .red)
                    } else {
                        Text("–").font(.title3.bold()).foregroundStyle(.secondary)
                        Text("Keine Daten").font(.caption2).foregroundStyle(.secondary)
                    }
                    Text("Schlaf letzte Nacht").font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 64)

                VStack(spacing: 6) {
                    Image(systemName: "figure.walk").font(.title2).foregroundStyle(.green)
                    if let schritte = hkSchritte {
                        Text("\(schritte)")
                            .font(.title3.bold()).foregroundStyle(.green)
                        Text(schritte >= 10000 ? "Tagesziel erreicht!" : "von 10'000")
                            .font(.caption2.bold())
                            .foregroundStyle(schritte >= 10000 ? .green : .secondary)
                    } else {
                        Text("–").font(.title3.bold()).foregroundStyle(.secondary)
                        Text("Keine Daten").font(.caption2).foregroundStyle(.secondary)
                    }
                    Text("Schritte heute").font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Wochen-Zusammenfassung

    private var wochenZusammenfassung: some View {
        let avg = wochenAvg
        let wasserFort = min(Double(wasserMl) / Double(wasserZielMl), 1.0)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Diese Woche", systemImage: "calendar.badge.checkmark")
                    .font(.headline)
                Spacer()
            }
            HStack(spacing: 0) {
                wochenSpalte(symbol: "drop.fill", farbe: .teal,
                             wert: String(format: "%.0f%%", wasserFort * 100), label: "Wasser")
                Divider().frame(height: 44)
                wochenSpalte(symbol: "heart.fill", farbe: .red,
                             wert: avg.stimmung > 0 ? String(format: "%.1f/5", avg.stimmung) : "–",
                             label: "Stimmung")
                Divider().frame(height: 44)
                wochenSpalte(symbol: "bolt.fill", farbe: .orange,
                             wert: avg.stress > 0 ? String(format: "%.1f/5", avg.stress) : "–",
                             label: "Stress")
                Divider().frame(height: 44)
                wochenSpalte(symbol: "moon.fill", farbe: .indigo,
                             wert: avg.schlaf > 0 ? String(format: "%.1fh", avg.schlaf) : "–",
                             label: "Schlaf")
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func wochenSpalte(symbol: String, farbe: Color, wert: String, label: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: symbol).foregroundStyle(farbe).font(.title3)
            Text(wert).font(.caption.bold())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Wasser-Tracker

    private var wasserTrackerKarte: some View {
        let fortschritt = min(Double(wasserMl) / Double(wasserZielMl), 1.0)
        return VStack(spacing: 16) {
            HStack {
                Label("Wasser-Tracker", systemImage: "drop.fill")
                    .font(.headline).foregroundStyle(.teal)
                Spacer()
            }

            ZStack {
                Circle().stroke(Color.teal.opacity(0.15), lineWidth: 14)
                Circle()
                    .trim(from: 0, to: fortschritt)
                    .stroke(Color.teal, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5), value: wasserMl)
                VStack(spacing: 4) {
                    Text("\(wasserMl)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.teal)
                    Text("von \(wasserZielMl) ml").font(.caption).foregroundStyle(.secondary)
                    Text(String(format: "%.0f%%", fortschritt * 100))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(width: 160, height: 160)
            .padding(.vertical, 8)

            HStack(spacing: 10) {
                ForEach([150, 200, 330, 500], id: \.self) { menge in
                    Button { trinken(ml: menge) } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "drop.fill").font(.caption).foregroundStyle(.teal)
                            Text("+\(menge)").font(.caption.bold())
                            Text("ml").font(.caption2).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.teal.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }

            if wasserMl > 0 {
                Button {
                    wasserMl = max(0, wasserMl - 150)
                    UserDefaults.standard.set(wasserMl, forKey: wasserKey())
                } label: {
                    Label("Rückgängig", systemImage: "arrow.uturn.backward")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            HStack {
                Text("Tagesziel").font(.subheadline)
                Spacer()
                Stepper("\(wasserZielMl) ml", value: $wasserZielMl, in: 1000...4000, step: 100)
                    .fixedSize()
                    .onChange(of: wasserZielMl) { _, neu in
                        UserDefaults.standard.set(neu, forKey: Self.wasserZielKey)
                    }
            }

            Divider()

            Toggle(isOn: $wasserErinnerungAktiv) {
                Label("Wasser-Erinnerung", systemImage: "bell.badge")
            }
            .onChange(of: wasserErinnerungAktiv) { _, aktiv in
                if aktiv {
                    Task {
                        let granted = await notif.berechtigungAnfordern()
                        if granted {
                            let dc = Calendar.current.dateComponents([.hour, .minute], from: wasserErinnerungZeit.wrappedValue)
                            notif.planeWasserErinnerung(stunde: dc.hour ?? 15, minute: dc.minute ?? 0)
                        } else {
                            wasserErinnerungAktiv = false
                        }
                    }
                } else {
                    notif.loescheWasserErinnerung()
                }
            }

            if wasserErinnerungAktiv {
                DatePicker("Uhrzeit", selection: wasserErinnerungZeit, displayedComponents: .hourAndMinute)
                    .onChange(of: wasserErinnerungZeit.wrappedValue) { _, neue in
                        let dc = Calendar.current.dateComponents([.hour, .minute], from: neue)
                        notif.planeWasserErinnerung(stunde: dc.hour ?? 15, minute: dc.minute ?? 0)
                    }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Ernährung

    private var ernaehrungKarte: some View {
        let braun = Color(red: 0.55, green: 0.35, blue: 0.15)
        return VStack(spacing: 16) {
            HStack {
                Label("Ernährung heute", systemImage: "fork.knife")
                    .font(.headline).foregroundStyle(braun)
                Spacer()
            }

            zaehlerZeile(symbol: "cup.and.saucer.fill", farbe: braun,
                         label: "Koffein", einheit: "Tassen", wert: $koffeinTassen,
                         speichern: { UserDefaults.standard.set($0, forKey: koffeinKey) })
            Divider()
            zaehlerZeile(symbol: "wineglass.fill", farbe: .purple,
                         label: "Alkohol", einheit: "Gläser", wert: $alkoholGlaeser,
                         speichern: { UserDefaults.standard.set($0, forKey: alkoholKey) })
            Divider()

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "sun.horizon.fill").foregroundStyle(.orange)
                    Text("Mahlzeiten").font(.subheadline)
                }
                HStack(spacing: 10) {
                    mahlzeitChip("Frühstück",   icon: "sunrise.fill",    aktiv: $fruehstueck, key: fruehstueckKey)
                    mahlzeitChip("Mittag",      icon: "sun.max.fill",    aktiv: $mittag,      key: mittagKey)
                    mahlzeitChip("Abendessen",  icon: "moon.stars.fill", aktiv: $abend,       key: abendKey)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func zaehlerZeile(symbol: String, farbe: Color, label: String, einheit: String,
                               wert: Binding<Int>, speichern: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(farbe).font(.title3).frame(width: 28)
            Text(label).font(.subheadline)
            Spacer()
            Button {
                guard wert.wrappedValue > 0 else { return }
                wert.wrappedValue -= 1; speichern(wert.wrappedValue)
            } label: {
                Image(systemName: "minus.circle.fill").font(.title2)
                    .foregroundStyle(wert.wrappedValue > 0 ? farbe : .secondary.opacity(0.25))
            }
            .buttonStyle(.plain)
            Text("\(wert.wrappedValue)")
                .font(.title3.bold()).frame(width: 32, alignment: .center)
                .foregroundStyle(wert.wrappedValue > 0 ? farbe : .secondary)
            Button {
                wert.wrappedValue += 1; speichern(wert.wrappedValue)
            } label: {
                Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(farbe)
            }
            .buttonStyle(.plain)
            Text(einheit).font(.caption).foregroundStyle(.secondary).frame(width: 46, alignment: .leading)
        }
    }

    private func mahlzeitChip(_ titel: String, icon: String, aktiv: Binding<Bool>, key: String) -> some View {
        Button {
            aktiv.wrappedValue.toggle()
            UserDefaults.standard.set(aktiv.wrappedValue, forKey: key)
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.title3)
                    .foregroundStyle(aktiv.wrappedValue ? .orange : .secondary.opacity(0.4))
                Text(titel).font(.caption2)
                    .foregroundStyle(aktiv.wrappedValue ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                aktiv.wrappedValue ? Color.orange.opacity(0.12) : Color.secondary.opacity(0.07),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(aktiv.wrappedValue ? Color.orange.opacity(0.5) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Trend-Picker

    private var trendPicker: some View {
        Picker("Zeitraum", selection: $trendTage) {
            Text("7T").tag(7)
            Text("30T").tag(30)
            Text("90T").tag(90)
        }
        .pickerStyle(.segmented)
        .fixedSize()
    }

    // MARK: - Stimmung & Stress

    private var stimmungStressKarte: some View {
        VStack(spacing: 12) {
            HStack {
                Label("Stimmung & Stress", systemImage: "waveform.path.ecg.rectangle")
                    .font(.headline).foregroundStyle(.pink)
                Spacer()
                trendPicker
            }

            Chart {
                ForEach(trendDaten) { tag in
                    LineMark(
                        x: .value("Tag", tag.datum, unit: .day),
                        y: .value("Wert", tag.stimmung)
                    )
                    .foregroundStyle(by: .value("Typ", "Stimmung"))
                    .interpolationMethod(.catmullRom)
                    .symbol(.circle)

                    LineMark(
                        x: .value("Tag", tag.datum, unit: .day),
                        y: .value("Wert", tag.stress)
                    )
                    .foregroundStyle(by: .value("Typ", "Stress"))
                    .interpolationMethod(.catmullRom)
                    .symbol(.square)
                }
            }
            .chartForegroundStyleScale(["Stimmung": Color.red, "Stress": Color.orange])
            .chartYScale(domain: 1...5)
            .chartXAxis {
                AxisMarks(values: .stride(by: trendTage <= 7 ? .day : .weekOfYear)) {
                    AxisValueLabel(format: trendTage <= 7 ? .dateTime.weekday(.narrow) : .dateTime.day().month(.abbreviated))
                }
            }
            .chartLegend(position: .bottom, alignment: .leading)
            .frame(height: 130)

            if trendDaten.count < 3 {
                Text("Mehr Schmerzeinträge erfassen für aussagekräftige Trends")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Schlaf

    private var schlafKarte: some View {
        let tagenMitSchlaf = trendDaten.filter { $0.schlaf > 0 }
        let avg = tagenMitSchlaf.isEmpty ? 0.0
            : tagenMitSchlaf.map(\.schlaf).reduce(0,+) / Double(tagenMitSchlaf.count)

        return VStack(spacing: 12) {
            HStack {
                Label("Schlaf", systemImage: "moon.zzz.fill")
                    .font(.headline).foregroundStyle(.indigo)
                Spacer()
                Text(trendLabel).font(.caption).foregroundStyle(.secondary)
            }

            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text(avg > 0 ? String(format: "%.1f", avg) : "–")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.indigo)
                    Text("Ø Stunden").font(.caption).foregroundStyle(.secondary)
                    if avg > 0 {
                        Text(avg >= 7 ? "Gut" : avg >= 6 ? "Okay" : "Zu wenig")
                            .font(.caption2.bold())
                            .foregroundStyle(avg >= 7 ? .green : avg >= 6 ? .orange : .red)
                    }
                }
                .frame(width: 85)

                if !tagenMitSchlaf.isEmpty {
                    Chart(tagenMitSchlaf) { tag in
                        BarMark(
                            x: .value("Tag", tag.datum, unit: .day),
                            y: .value("Schlaf", tag.schlaf)
                        )
                        .foregroundStyle(tag.schlaf >= 7 ? Color.indigo : Color.indigo.opacity(0.4))
                        .cornerRadius(4)
                    }
                    .chartYScale(domain: 0...10)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: trendTage <= 7 ? .day : .weekOfYear)) {
                            AxisValueLabel(format: trendTage <= 7 ? .dateTime.weekday(.narrow) : .dateTime.day().month(.abbreviated))
                        }
                    }
                    .frame(height: 80)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Streak

    private var streakKarte: some View {
        let streak = berechneStreak()
        return VStack(spacing: 10) {
            HStack {
                Label("Wasser-Streak", systemImage: "flame.fill")
                    .font(.headline).foregroundStyle(.orange)
                Spacer()
            }
            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("\(streak)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(streak > 0 ? .orange : .secondary)
                    Text(streak == 1 ? "Tag in Folge" : "Tage in Folge")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 6) {
                    streakInfo(symbol: "drop.fill",            farbe: .teal,   text: "Getrunken: \(wasserMl) ml")
                    streakInfo(symbol: "checkmark.circle.fill", farbe: .green, text: "Ziel: \(wasserZielMl) ml")
                    if streak >= 7 {
                        streakInfo(symbol: "star.fill",  farbe: .yellow, text: "Wochenziel erreicht!")
                    } else if streak >= 3 {
                        streakInfo(symbol: "bolt.fill",  farbe: .orange, text: "Super, weiter so!")
                    } else {
                        streakInfo(symbol: "drop.circle", farbe: .teal,  text: "Trinke täglich genug")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func streakInfo(symbol: String, farbe: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).foregroundStyle(farbe).font(.caption)
            Text(text).font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private func ladeDaten() {
        wasserMl = UserDefaults.standard.integer(forKey: wasserKey())
        let ziel = UserDefaults.standard.integer(forKey: Self.wasserZielKey)
        wasserZielMl = ziel > 0 ? ziel : 2000
        koffeinTassen  = UserDefaults.standard.integer(forKey: koffeinKey)
        alkoholGlaeser = UserDefaults.standard.integer(forKey: alkoholKey)
        fruehstueck = UserDefaults.standard.bool(forKey: fruehstueckKey)
        mittag      = UserDefaults.standard.bool(forKey: mittagKey)
        abend       = UserDefaults.standard.bool(forKey: abendKey)
    }

    private func trinken(ml: Int) {
        wasserMl += ml
        UserDefaults.standard.set(wasserMl, forKey: wasserKey())
    }

    private func berechneStreak() -> Int {
        let ziel = UserDefaults.standard.integer(forKey: Self.wasserZielKey)
        let zielMl = ziel > 0 ? ziel : 2000
        var streak = 0
        for offset in 0...29 {
            let ml = UserDefaults.standard.integer(forKey: wasserKey(-offset))
            if ml >= zielMl { streak += 1 } else if offset > 0 { break }
        }
        return streak
    }
}
