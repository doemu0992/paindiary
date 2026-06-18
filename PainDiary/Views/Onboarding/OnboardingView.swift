import SwiftUI
import SwiftData

struct OnboardingView: View {
    @AppStorage("onboardingAbgeschlossen") private var onboardingAbgeschlossen = false
    @Environment(\.modelContext) private var modelContext
    @Query private var profile: [Benutzerprofil]

    @State private var schritt = 0
    @State private var vorname = ""
    @State private var ausgewaehlteSchmerztypen: Set<SchmerzTypOnboarding> = []
    @State private var datenschutzAkzeptiert = false
    @State private var datenschutzAnzeigen = false

    private let gesamtSchritte = 5

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $schritt) {
                WillkommensSchritt()
                    .tag(0)
                NameSchritt(vorname: $vorname)
                    .tag(1)
                SchmerzTypSchritt(auswahl: $ausgewaehlteSchmerztypen)
                    .tag(2)
                DashboardVorschauSchritt(auswahl: ausgewaehlteSchmerztypen)
                    .tag(3)
                DatenschutzSchritt(akzeptiert: $datenschutzAkzeptiert, volltext: $datenschutzAnzeigen)
                    .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: schritt)

            VStack(spacing: 0) {
                SchrittIndikator(aktuell: schritt, gesamt: gesamtSchritte)
                    .padding(.bottom, 16)

                VStack(spacing: 12) {
                    Button {
                        weiter()
                    } label: {
                        Text(schritt == gesamtSchritte - 1 ? "Los geht's!" : "Weiter")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(weiterFarbe)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(schritt == gesamtSchritte - 1 && !datenschutzAkzeptiert)

                    if schritt < gesamtSchritte - 1 {
                        Button("Überspringen") {
                            abschliessen()
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .background(
                LinearGradient(
                    colors: [Color(.systemGroupedBackground).opacity(0), Color(.systemGroupedBackground)],
                    startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.3)
                )
            )
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $datenschutzAnzeigen) {
            DatenschutzVollTextView()
        }
    }

    private var weiterFarbe: Color {
        switch schritt {
        case 0: return .red
        case 1: return vorname.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .orange
        case 2: return ausgewaehlteSchmerztypen.isEmpty ? .gray : .blue
        case 3: return .teal
        case 4: return datenschutzAkzeptiert ? .green : .gray
        default: return Color.accentColor
        }
    }

    private func weiter() {
        if schritt == 1 {
            let name = vorname.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return }
        }
        if schritt == 2, ausgewaehlteSchmerztypen.isEmpty { return }
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        if schritt < gesamtSchritte - 1 {
            withAnimation { schritt += 1 }
        } else {
            abschliessen()
        }
    }

    private func abschliessen() {
        let name = vorname.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty {
            if let profil = profile.first {
                profil.vorname = name
            } else {
                let neu = Benutzerprofil()
                neu.vorname = name
                modelContext.insert(neu)
            }
        }
        if !ausgewaehlteSchmerztypen.isEmpty {
            var konfig = KachelKonfiguration.standard
            let extraKacheln = SchmerzTypOnboarding.kachelVorschlag(fuer: ausgewaehlteSchmerztypen)
            for typ in extraKacheln where !konfig.contains(where: { $0.id == typ.rawValue }) {
                konfig.append(KachelKonfiguration(id: typ.rawValue, typ: typ))
            }
            konfig.speichern()
        }
        onboardingAbgeschlossen = true
    }
}

// MARK: - Schritt-Indikator

private struct SchrittIndikator: View {
    let aktuell: Int
    let gesamt: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<gesamt, id: \.self) { i in
                Capsule()
                    .fill(i <= aktuell ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(width: i == aktuell ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.3), value: aktuell)
            }
        }
    }
}

// MARK: - Schritt 0: Willkommen

private struct WillkommensSchritt: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            ZStack {
                Circle().fill(Color.red.opacity(0.12)).frame(width: 160, height: 160)
                Image(systemName: "waveform.path.ecg.rectangle.fill")
                    .font(.system(size: 68))
                    .foregroundStyle(.red)
            }
            VStack(spacing: 16) {
                Text("Willkommen bei\nPainDiary")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text("Dein persönliches Schmerztagebuch. Erfasse, verstehe und teile deine Schmerzmuster — einfach, schnell und sicher.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Schritt 1: Name

private struct NameSchritt: View {
    @Binding var vorname: String
    @FocusState private var fokus: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                ZStack {
                    Circle().fill(Color.orange.opacity(0.12)).frame(width: 160, height: 160)
                    Image(systemName: "person.fill")
                        .font(.system(size: 68))
                        .foregroundStyle(.orange)
                }
                .padding(.top, 24)

                VStack(spacing: 16) {
                    Text("Wie heisst du?")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                    Text("Damit dein Dashboard persönlich begrüsst dich — guten Morgen, \(vorname.isEmpty ? "Name" : vorname)!")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .animation(.easeInOut, value: vorname)

                    TextField("Dein Vorname", text: $vorname)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                        .focused($fokus)
                        .submitLabel(.done)
                        .onSubmit { fokus = false }
                        .padding(.horizontal, 8)
                        .padding(.top, 8)
                }

                Spacer(minLength: 160)
            }
            .padding(.horizontal, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { fokus = true }
        }
    }
}

// MARK: - Schritt 2: Schmerztypen

enum SchmerzTypOnboarding: String, CaseIterable, Identifiable {
    case migraene    = "migraene"
    case ruecken     = "ruecken"
    case chronisch   = "chronisch"
    case haut        = "haut"
    case gelenk      = "gelenk"
    case andere      = "andere"

    var id: String { rawValue }

    var titel: String {
        switch self {
        case .migraene:  return "Migräne / Kopfschmerz"
        case .ruecken:   return "Rücken / Nacken"
        case .chronisch: return "Chronischer Schmerz"
        case .haut:      return "Hauterkrankung"
        case .gelenk:    return "Gelenk / Rheuma"
        case .andere:    return "Anderes"
        }
    }

    var symbol: String {
        switch self {
        case .migraene:  return "brain.head.profile"
        case .ruecken:   return "figure.stand"
        case .chronisch: return "waveform.path.ecg"
        case .haut:      return "allergens"
        case .gelenk:    return "figure.wave"
        case .andere:    return "ellipsis.circle"
        }
    }

    var farbe: Color {
        switch self {
        case .migraene:  return .purple
        case .ruecken:   return .blue
        case .chronisch: return .red
        case .haut:      return .orange
        case .gelenk:    return .teal
        case .andere:    return .secondary
        }
    }

    static func kachelVorschlag(fuer typen: Set<SchmerzTypOnboarding>) -> [KachelTyp] {
        var kacheln: [KachelTyp] = []
        var gesehen = Set<KachelTyp>()
        func add(_ k: KachelTyp) { if gesehen.insert(k).inserted { kacheln.append(k) } }
        if typen.contains(.migraene)  { [KachelTyp.midasKachel, .tageszeitVerteilung, .wetterSchmerz].forEach(add) }
        if typen.contains(.ruecken)   { [KachelTyp.koerperstellen, .wetterSchmerz, .schlafSchmerz].forEach(add) }
        if typen.contains(.chronisch) { [KachelTyp.stimmungsTrend, .stressSchmerz, .schlafSchmerz].forEach(add) }
        if typen.contains(.haut)      { [KachelTyp.koerperstellen, .schmerzarten].forEach(add) }
        if typen.contains(.gelenk)    { [KachelTyp.wetterSchmerz, .koerperstellen, .stimmungsTrend].forEach(add) }
        if typen.contains(.andere)    { [KachelTyp.stressSchmerz, .stimmungsTrend].forEach(add) }
        return kacheln
    }
}

private struct SchmerzTypSchritt: View {
    @Binding var auswahl: Set<SchmerzTypOnboarding>

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 12) {
                Text("Was möchtest du tracken?")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text("Wähle alle zutreffenden Kategorien — PainDiary passt dein Dashboard an.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(SchmerzTypOnboarding.allCases) { typ in
                    let aktiv = auswahl.contains(typ)
                    Button {
                        withAnimation(.spring(response: 0.25)) {
                            if aktiv { auswahl.remove(typ) } else { auswahl.insert(typ) }
                        }
                    } label: {
                        VStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(aktiv ? typ.farbe : typ.farbe.opacity(0.12))
                                    .frame(width: 52, height: 52)
                                Image(systemName: typ.symbol)
                                    .font(.title2)
                                    .foregroundStyle(aktiv ? .white : typ.farbe)
                            }
                            Text(typ.titel)
                                .font(.caption)
                                .fontWeight(.medium)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(aktiv ? typ.farbe : .primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(aktiv ? typ.farbe.opacity(0.1) : Color(.secondarySystemGroupedBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(aktiv ? typ.farbe : Color.clear, lineWidth: 2)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Schritt 3: Dashboard-Vorschau

private struct DashboardVorschauSchritt: View {
    let auswahl: Set<SchmerzTypOnboarding>

    private var vorschlagKacheln: [(symbol: String, titel: String, farbe: Color)] {
        var kacheln: [(String, String, Color)] = [
            ("waveform.path.ecg", "Schmerzübersicht", .red),
            ("chart.line.uptrend.xyaxis", "Schmerzverlauf", .blue),
            ("heart.text.square.fill", "Stimmung & Stress", .pink),
        ]
        let extras = SchmerzTypOnboarding.kachelVorschlag(fuer: auswahl.isEmpty ? [.chronisch] : auswahl)
        for typ in extras.prefix(4) {
            kacheln.append((typ.symbol, typ.titel, kachelFarbe(typ)))
        }
        return kacheln.prefix(6).map { (symbol: $0.0, titel: $0.1, farbe: $0.2) }
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.teal.opacity(0.12)).frame(width: 120, height: 120)
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.teal)
                }
                Text("Dein Dashboard")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text(auswahl.isEmpty
                    ? "Das Standard-Dashboard ist bereits für dich bereit."
                    : "Basierend auf deiner Auswahl schlagen wir diese Kacheln vor:")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(vorschlagKacheln.indices, id: \.self) { i in
                    let k = vorschlagKacheln[i]
                    HStack(spacing: 10) {
                        Image(systemName: k.symbol)
                            .foregroundStyle(k.farbe)
                            .frame(width: 28)
                        Text(k.titel)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(2)
                        Spacer()
                    }
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 24)

            Text("Du kannst das Dashboard jederzeit unter «Anpassen» ändern.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
    }

    private func kachelFarbe(_ typ: KachelTyp) -> Color {
        switch typ {
        case .wetterSchmerz: return .cyan
        case .stressSchmerz: return .yellow
        case .schlafSchmerz: return .purple
        case .tageszeitVerteilung: return .orange
        case .koerperstellen: return .teal
        case .schmerzarten: return .blue
        case .stimmungsTrend: return .pink
        case .midasKachel: return .purple
        default: return Color.accentColor
        }
    }
}

// MARK: - Schritt 4: Datenschutz

private struct DatenschutzSchritt: View {
    @Binding var akzeptiert: Bool
    @Binding var volltext: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ZStack {
                    Circle().fill(Color.green.opacity(0.12)).frame(width: 120, height: 120)
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.green)
                }
                VStack(spacing: 12) {
                    Text("Deine Daten gehören dir")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                    Text("PainDiary speichert alle Daten lokal auf deinem Gerät und optional in iCloud. Es werden keine Daten an Dritte verkauft oder für Werbung genutzt.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 12) {
                    DatenschutzPunkt(symbol: "iphone",         farbe: .blue,   text: "Lokale Speicherung auf deinem Gerät")
                    DatenschutzPunkt(symbol: "icloud.fill",    farbe: .cyan,   text: "Optionale iCloud-Synchronisation")
                    DatenschutzPunkt(symbol: "eye.slash.fill", farbe: .indigo, text: "Keine Weitergabe an Dritte")
                    DatenschutzPunkt(symbol: "faceid",         farbe: .green,  text: "Face ID / Touch ID Schutz möglich")
                    DatenschutzPunkt(symbol: "square.and.arrow.up", farbe: .orange, text: "Datenexport jederzeit möglich")
                }
                .padding(.horizontal, 32)

                Button {
                    volltext = true
                } label: {
                    Text("Vollständige Datenschutzerklärung lesen")
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)
                        .underline()
                }

                Button {
                    withAnimation { akzeptiert.toggle() }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: akzeptiert ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundStyle(akzeptiert ? .green : .secondary)
                        Text("Ich habe die Datenschutzerklärung gelesen und akzeptiere sie.")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
            }
            .padding(.top, 32)
            .padding(.bottom, 140)
        }
    }
}

private struct DatenschutzPunkt: View {
    let symbol: String
    let farbe: Color
    let text: String
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).foregroundStyle(farbe).frame(width: 24)
            Text(text).font(.subheadline).foregroundStyle(.primary)
        }
    }
}

// MARK: - Datenschutz Volltext Sheet

struct DatenschutzVollTextView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            DatenschutzView()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Schliessen") { dismiss() }
                    }
                }
        }
    }
}
