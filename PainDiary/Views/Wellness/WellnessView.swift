import SwiftUI
import SwiftData

struct WellnessView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WellnessEintrag.datum, order: .reverse) private var wellnessEintraege: [WellnessEintrag]

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

    // MARK: - Wohlbefinden (heute)
    @State private var stimmung: Int = 0
    @State private var stressLevel: Int = 0
    @State private var energielevel: Int = 0

    private let notif = NotificationManager.shared
    @State private var zeigeAnalyse = false

    // MARK: - HealthKit
    @State private var hkSchlaf: Double? = nil
    @State private var hkSchritte: Int? = nil

    // MARK: - Keys

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

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                tagesHeaderKarte
                stimmungKarte
                stressKarte
                energieKarte
                if HealthKitManager.shared.istVerfuegbar { healthKitKarte }
                wasserTrackerKarte
                ernaehrungKarte
                streakKarte
            }
            .padding()
            .padding(.bottom, 30)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Wohlbefinden")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            ladeDaten()
            Task {
                await HealthKitManager.shared.berechtigungAnfordern()
                hkSchlaf   = await HealthKitManager.shared.schlafStundenLetztteNacht()
                hkSchritte = await HealthKitManager.shared.schritteDiesemTag()
            }
        }
        .sheet(isPresented: $zeigeAnalyse) {
            WohlbefindenAnalyseView()
        }
    }

    // MARK: - Tages-Header

    private var tagesHeaderKarte: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Date(), style: .date)
                        .font(.headline)
                    Text("Erfasse dein tägliches Wohlbefinden")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "heart.text.square.fill")
                    .font(.title2).foregroundStyle(.mint)
            }

            Divider()

            Button { zeigeAnalyse = true } label: {
                Label("Wohlbefinden-Analyse öffnen", systemImage: "chart.bar.xaxis.ascending")
                    .font(.subheadline.bold()).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(Color.mint, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Stimmung

    private var stimmungKarte: some View {
        VStack(spacing: 14) {
            HStack {
                Label("Stimmung heute", systemImage: "heart.fill")
                    .font(.headline).foregroundStyle(.red)
                Spacer()
            }
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { stufe in
                    let aktiv = stimmung == stufe
                    let farbe = stimmungFarbe(stufe)
                    Button {
                        stimmung = stufe
                        speichernInEintrag()
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: "heart.fill")
                                .font(.title2)
                                .foregroundStyle(aktiv ? farbe : .secondary.opacity(0.3))
                            Text(stimmungLabel(stufe))
                                .font(.caption2)
                                .foregroundStyle(aktiv ? .primary : .secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            aktiv ? farbe.opacity(0.12) : Color.secondary.opacity(0.06),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                        .animation(.easeInOut(duration: 0.15), value: aktiv)
                    }
                    .buttonStyle(.plain)
                }
            }
            if stimmung > 0 {
                Text(stimmungLabel(stimmung))
                    .font(.caption).foregroundStyle(stimmungFarbe(stimmung))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: stimmung)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Stress

    private var stressKarte: some View {
        VStack(spacing: 14) {
            HStack {
                Label("Stress heute", systemImage: "brain.head.profile")
                    .font(.headline).foregroundStyle(.orange)
                Spacer()
            }
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { stufe in
                    let aktiv = stressLevel == stufe
                    let farbe = stressFarbe(stufe)
                    Button {
                        stressLevel = stufe
                        speichernInEintrag()
                    } label: {
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(aktiv ? farbe : farbe.opacity(0.2))
                                .frame(width: 6, height: CGFloat(stufe) * 5 + 8)
                            Text(stressLabel(stufe))
                                .font(.caption2)
                                .foregroundStyle(aktiv ? .primary : .secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            aktiv ? farbe.opacity(0.12) : Color.secondary.opacity(0.06),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                        .animation(.easeInOut(duration: 0.15), value: aktiv)
                    }
                    .buttonStyle(.plain)
                }
            }
            if stressLevel > 0 {
                Text(stressLabel(stressLevel))
                    .font(.caption).foregroundStyle(stressFarbe(stressLevel))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: stressLevel)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Energie

    private var energieKarte: some View {
        VStack(spacing: 14) {
            HStack {
                Label("Energie & Vitalität", systemImage: "bolt.heart.fill")
                    .font(.headline).foregroundStyle(.mint)
                Spacer()
            }
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { stufe in
                    let aktiv = energielevel == stufe
                    Button {
                        energielevel = stufe
                        speichernInEintrag()
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: energieSymbol(stufe))
                                .font(.title2)
                                .foregroundStyle(aktiv ? energieFarbe(stufe) : .secondary.opacity(0.35))
                            Text(energieLabel(stufe))
                                .font(.caption2)
                                .foregroundStyle(aktiv ? .primary : .secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            aktiv ? energieFarbe(stufe).opacity(0.12) : Color.secondary.opacity(0.06),
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                        .animation(.easeInOut(duration: 0.15), value: aktiv)
                    }
                    .buttonStyle(.plain)
                }
            }
            if energielevel > 0 {
                Text(energieLabel(energielevel))
                    .font(.caption).foregroundStyle(energieFarbe(energielevel))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: energielevel)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
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
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
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
                    speichernInEintrag()
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
                        speichernInEintrag()
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
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
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
                         speichern: { UserDefaults.standard.set($0, forKey: koffeinKey); speichernInEintrag() })
            Divider()
            zaehlerZeile(symbol: "wineglass.fill", farbe: .purple,
                         label: "Alkohol", einheit: "Gläser", wert: $alkoholGlaeser,
                         speichern: { UserDefaults.standard.set($0, forKey: alkoholKey); speichernInEintrag() })
            Divider()

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "sun.horizon.fill").foregroundStyle(.orange)
                    Text("Mahlzeiten").font(.subheadline)
                }
                HStack(spacing: 10) {
                    mahlzeitChip("Frühstück",  icon: "sunrise.fill",    aktiv: $fruehstueck, key: fruehstueckKey)
                    mahlzeitChip("Mittag",     icon: "sun.max.fill",    aktiv: $mittag,      key: mittagKey)
                    mahlzeitChip("Abendessen", icon: "moon.stars.fill", aktiv: $abend,       key: abendKey)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
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
            speichernInEintrag()
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
                    streakInfo(symbol: "drop.fill",             farbe: .teal,   text: "Getrunken: \(wasserMl) ml")
                    streakInfo(symbol: "checkmark.circle.fill", farbe: .green,  text: "Ziel: \(wasserZielMl) ml")
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
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func streakInfo(symbol: String, farbe: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).foregroundStyle(farbe).font(.caption)
            Text(text).font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    @discardableResult
    private func heutesEintragHolen() -> WellnessEintrag {
        let heute = Calendar.current.startOfDay(for: Date())
        if let existing = wellnessEintraege.first(where: {
            Calendar.current.isDate($0.datum, inSameDayAs: heute)
        }) {
            return existing
        }
        let neu = WellnessEintrag(datum: heute)
        let ml = UserDefaults.standard.integer(forKey: wasserKey())
        if ml > 0 { neu.wasserMl = ml }
        let ziel = UserDefaults.standard.integer(forKey: Self.wasserZielKey)
        if ziel > 0 { neu.wasserZielMl = ziel }
        neu.koffeinTassen  = UserDefaults.standard.integer(forKey: koffeinKey)
        neu.alkoholGlaeser = UserDefaults.standard.integer(forKey: alkoholKey)
        neu.fruehstueck    = UserDefaults.standard.bool(forKey: fruehstueckKey)
        neu.mittag         = UserDefaults.standard.bool(forKey: mittagKey)
        neu.abend          = UserDefaults.standard.bool(forKey: abendKey)
        modelContext.insert(neu)
        return neu
    }

    private func speichernInEintrag() {
        let entry = heutesEintragHolen()
        entry.wasserMl       = wasserMl
        entry.wasserZielMl   = wasserZielMl
        entry.koffeinTassen  = koffeinTassen
        entry.alkoholGlaeser = alkoholGlaeser
        entry.fruehstueck    = fruehstueck
        entry.mittag         = mittag
        entry.abend          = abend
        entry.stimmung       = stimmung
        entry.stressLevel    = stressLevel
        entry.energielevel   = energielevel
    }

    private func ladeDaten() {
        let heute = Calendar.current.startOfDay(for: Date())
        if let entry = wellnessEintraege.first(where: { Calendar.current.isDate($0.datum, inSameDayAs: heute) }) {
            wasserMl       = entry.wasserMl
            wasserZielMl   = entry.wasserZielMl > 0 ? entry.wasserZielMl : 2000
            koffeinTassen  = entry.koffeinTassen
            alkoholGlaeser = entry.alkoholGlaeser
            fruehstueck    = entry.fruehstueck
            mittag         = entry.mittag
            abend          = entry.abend
            stimmung       = entry.stimmung
            stressLevel    = entry.stressLevel
            energielevel   = entry.energielevel
        } else {
            wasserMl       = UserDefaults.standard.integer(forKey: wasserKey())
            let ziel       = UserDefaults.standard.integer(forKey: Self.wasserZielKey)
            wasserZielMl   = ziel > 0 ? ziel : 2000
            koffeinTassen  = UserDefaults.standard.integer(forKey: koffeinKey)
            alkoholGlaeser = UserDefaults.standard.integer(forKey: alkoholKey)
            fruehstueck    = UserDefaults.standard.bool(forKey: fruehstueckKey)
            mittag         = UserDefaults.standard.bool(forKey: mittagKey)
            abend          = UserDefaults.standard.bool(forKey: abendKey)
        }
    }

    private func trinken(ml: Int) {
        wasserMl += ml
        UserDefaults.standard.set(wasserMl, forKey: wasserKey())
        speichernInEintrag()
    }

    private func berechneStreak() -> Int {
        let zielMl = wasserZielMl > 0 ? wasserZielMl : 2000
        var streak = 0
        for offset in 0...29 {
            guard let tag = Calendar.current.date(byAdding: .day, value: -offset,
                                                  to: Calendar.current.startOfDay(for: Date())) else { break }
            if let entry = wellnessEintraege.first(where: { Calendar.current.isDate($0.datum, inSameDayAs: tag) }) {
                if entry.wasserMl >= zielMl { streak += 1 } else if offset > 0 { break }
            } else {
                let ml = UserDefaults.standard.integer(forKey: wasserKey(-offset))
                if ml >= zielMl { streak += 1 } else if offset > 0 { break }
            }
        }
        return streak
    }

    // MARK: - Stimmung Helpers (CLAUDE.md: [.red, .orange, .yellow, .green, .teal])

    private func stimmungFarbe(_ stufe: Int) -> Color {
        [.red, .orange, .yellow, .green, .teal][max(0, min(stufe - 1, 4))]
    }

    private func stimmungLabel(_ stufe: Int) -> String {
        switch stufe {
        case 1: return "Schlecht"
        case 2: return "Mäßig"
        case 3: return "Okay"
        case 4: return "Gut"
        default: return "Sehr gut"
        }
    }

    // MARK: - Stress Helpers (CLAUDE.md: [.green, .mint, .yellow, .orange, .red])

    private func stressFarbe(_ stufe: Int) -> Color {
        [.green, .mint, .yellow, .orange, .red][max(0, min(stufe - 1, 4))]
    }

    private func stressLabel(_ stufe: Int) -> String {
        switch stufe {
        case 1: return "Entspannt"
        case 2: return "Ruhig"
        case 3: return "Mittel"
        case 4: return "Gestresst"
        default: return "Sehr hoch"
        }
    }

    // MARK: - Energie Helpers

    private func energieSymbol(_ stufe: Int) -> String {
        switch stufe {
        case 1: return "battery.0"
        case 2: return "battery.25"
        case 3: return "battery.50"
        case 4: return "battery.75"
        default: return "battery.100"
        }
    }

    private func energieLabel(_ stufe: Int) -> String {
        switch stufe {
        case 1: return "Erschöpft"
        case 2: return "Müde"
        case 3: return "Okay"
        case 4: return "Gut"
        default: return "Top"
        }
    }

    private func energieFarbe(_ stufe: Int) -> Color {
        switch stufe {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .mint
        default: return .green
        }
    }
}
