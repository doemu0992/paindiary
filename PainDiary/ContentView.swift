import SwiftUI
import SwiftData
import LocalAuthentication

struct ContentView: View {
    @AppStorage("onboardingAbgeschlossen") private var onboardingAbgeschlossen = false
    @AppStorage("akzentFarbe") private var akzentFarbe = "blau"
    @AppStorage("biometrischesLockAktiv") private var biometriAktivCache = false
    @AppStorage("whatsNewGezeigteVersion") private var whatsNewGezeigteVersion = ""
    @AppStorage("migraeneModulAktiv") private var migraeneModulAktiv = false
    @AppStorage("rheumaModulAktiv")   private var rheumaModulAktiv   = false
    @AppStorage("diabetesModulAktiv") private var diabetesModulAktiv = false
    @State private var ausgewaehlterTab = 0
    @State private var neuerEintragAnzeigen = false
    @State private var entsperrt = false
    @State private var zeigeWhatsNew = false
    @State private var deepLinkMedikamentName: String? = nil
    @State private var zeigeEinnahmeVerlauf = false
    @State private var zeigeMedikamente = false
    @State private var zeigeZyklus = false
    @Query(sort: \Dauermedikation.name) private var medikamente: [Dauermedikation]
    @Environment(\.scenePhase) private var scenePhase

    private var biometriAktiv: Bool { biometriAktivCache }
    private var aktuelleBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
    }

#if os(macOS)
    var body: some View {
        NavigationSplitView {
            PainEntryListView()
        } detail: {
            Text("Eintrag auswählen").foregroundStyle(.secondary)
        }
    }
#else
    var body: some View {
        Group {
            if biometriAktiv && !entsperrt {
                sperrBildschirm
            } else {
                hauptApp
            }
        }
        .task {
            // Cold launch: give the window time to fully initialize before requesting biometrics
            guard biometriAktiv && !entsperrt else { return }
            try? await Task.sleep(for: .milliseconds(200))
            if biometriAktiv && !entsperrt { authentifizieren() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background && biometriAktiv {
                entsperrt = false
            } else if phase == .active && biometriAktiv && !entsperrt {
                authentifizieren()
            }
            // Pfad 2: Background → Foreground (App war im Hintergrund)
            if phase == .active {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { verarbeiteDeepLink() }
            }
        }
        .tint(akzentFarbe.alsAkzentFarbe)
        .fullScreenCover(isPresented: .constant(!onboardingAbgeschlossen)) {
            OnboardingView()
        }
        .sheet(isPresented: $zeigeWhatsNew) {
            WhatsNewView {
                whatsNewGezeigteVersion = aktuelleBuild
                zeigeWhatsNew = false
            }
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: Binding(
            get: { deepLinkMedikamentName != nil },
            set: { if !$0 { deepLinkMedikamentName = nil } }
        )) {
            if let name = deepLinkMedikamentName,
               let med = medikamente.first(where: { $0.name == name }) {
                EinnahmeLogSheet(med: med)
            }
        }
        .sheet(isPresented: $zeigeEinnahmeVerlauf) {
            NavigationStack { EinnahmeLogView() }
        }
        .sheet(isPresented: $zeigeMedikamente) {
            NavigationStack { MedikamenteView() }
        }
        .sheet(isPresented: $zeigeZyklus) {
            NavigationStack { ZyklusView() }
        }
        // Pfad 1: App aktiv im Vordergrund — sofort reagieren
        .onChange(of: NotificationManager.shared.pendingDeepLink) { _, _ in
            verarbeiteDeepLink()
        }
        .onAppear {
            pruefWhatsNew()
            // Pfad 3: Cold Launch — pendingDeepLink wurde gesetzt bevor ContentView erschien
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { verarbeiteDeepLink() }
        }
    }

    private func verarbeiteDeepLink() {
        guard let link = NotificationManager.shared.pendingDeepLink else { return }
        NotificationManager.shared.pendingDeepLink = nil
        switch link {
        case .neuerSchmerzEintrag:
            neuerEintragAnzeigen = true
        case .medikamentErfassen(let name, _):
            deepLinkMedikamentName = name
        case .einnahmeVerlauf:
            ausgewaehlterTab = 4
            zeigeEinnahmeVerlauf = true
        case .medikamenteAnzeigen:
            zeigeMedikamente = true
        case .wellnessAnzeigen:
            ausgewaehlterTab = 3
        case .zyklusAnzeigen:
            zeigeZyklus = true
        }
    }

    private func pruefWhatsNew() {
        guard onboardingAbgeschlossen,
              whatsNewFuerAktuelleVersion() != nil,
              aktuelleBuild != whatsNewGezeigteVersion else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            zeigeWhatsNew = true
        }
    }

    private var hauptApp: some View {
        TabView(selection: $ausgewaehlterTab) {
            NavigationStack { DashboardView() }
                .tabItem { Label("Übersicht", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(0)

            NavigationStack { PainEntryListView() }
                .tabItem { Label("Tagebuch", systemImage: "book.pages") }
                .tag(1)

            Color.clear
                .tabItem { Label(" ", systemImage: "plus") }
                .tag(2)

            NavigationStack { WellnessView() }
                .tabItem { Label("Wohlbefinden", systemImage: "heart.text.square.fill") }
                .tag(3)

            NavigationStack { ProfilView() }
                .tabItem { Label("Profil", systemImage: "person.circle") }
                .tag(4)
        }
        .overlay(alignment: .bottom) {
            Button { neuerEintragAnzeigen = true } label: {
                ZStack {
                    Circle()
                        .fill(akzentFarbe.alsAkzentFarbe)
                        .frame(width: 54, height: 54)
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.bottom, 4)
        }
        .onChange(of: ausgewaehlterTab) { _, neu in
            if neu == 2 {
                neuerEintragAnzeigen = true
                ausgewaehlterTab = 1
            }
        }
        .sheet(isPresented: $neuerEintragAnzeigen) {
            if migraeneModulAktiv || rheumaModulAktiv || diabetesModulAktiv {
                EintragAuswahlView()
            } else {
                AddEntryView()
            }
        }
    }

    private var sperrBildschirm: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("PainDiary")
                .font(.largeTitle.bold())
            Text("Entsperre die App um fortzufahren.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                authentifizieren()
            } label: {
                Label("Entsperren", systemImage: "faceid")
                    .font(.headline)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func authentifizieren() {
        let context = LAContext()
        var fehler: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &fehler) else {
            entsperrt = true
            return
        }
        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "PainDiary entsperren"
        ) { erfolg, _ in
            DispatchQueue.main.async { entsperrt = erfolg }
        }
    }
#endif
}
