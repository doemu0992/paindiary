import SwiftUI
import SwiftData
import LocalAuthentication

struct ContentView: View {
    @AppStorage("onboardingAbgeschlossen") private var onboardingAbgeschlossen = false
    @AppStorage("akzentFarbe") private var akzentFarbe = "blau"
    @AppStorage("biometrischesLockAktiv") private var biometriAktivCache = false
    @AppStorage("whatsNewGezeigteVersion") private var whatsNewGezeigteVersion = ""
    @State private var ausgewaehlterTab = 0
    @State private var neuerEintragAnzeigen = false
    @State private var entsperrt = false
    @State private var zeigeWhatsNew = false
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
        .onAppear {
            pruefWhatsNew()
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
            AddEntryView()
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
