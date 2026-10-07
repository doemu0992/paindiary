import SwiftUI
import SwiftData
import os

@main
struct PainDiaryApp: App {
    @UIApplicationDelegateAdaptor(PartnerAppDelegate.self) private var partnerDelegate
    @State private var ergebnis: PersistenceResult? = nil
    @State private var zeigeDatenbankHilfe = false
    // Initialize early so UNUserNotificationCenter.delegate is set before iOS delivers
    // the pending notification response on cold launch.
    private let _notif = NotificationManager.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if let ergebnis {
                    if let container = ergebnis.container {
                        ContentView()
                            .modelContainer(container)
                            .overlay(alignment: .top) {
                                StoreStatusBanner(status: ergebnis.status) { zeigeDatenbankHilfe = true }
                            }
                    } else {
                        DatenbankFehlerView(status: ergebnis.status) { neustart() }
                    }
                } else {
                    Color.clear
                }
            }
            .sheet(isPresented: $zeigeDatenbankHilfe) {
                if let status = ergebnis?.status {
                    DatenbankHilfeSheet(status: status) { neustart() }
                }
            }
            .task { await starten(erneut: false) }
        }
    }

    /// Öffnet den Store, führt die Datenpflege aus und plant Erinnerungen.
    @MainActor
    private func neustart() {
        Task { await starten(erneut: true) }
    }

    @MainActor
    private func starten(erneut: Bool) async {
        guard erneut || ergebnis == nil else { return }
        let r = PersistenceController.oeffne()
        ergebnis = r
        guard let c = r.container else { return }
        if !r.status.istNotfall {
            DatenPflege.run(context: ModelContext(c))
        }
        await berechtigungenAnfordern()
        if !r.status.istNotfall {
            await planeAlleErinnerungen(container: c)
            if await NotificationManager.shared.budgetKnapp() {
                PersistenceController.logger.warning("Benachrichtigungs-Budget fast erschöpft (Limit 64)")
            }
        }
    }

    private func berechtigungenAnfordern() async {
        _ = await NotificationManager.shared.berechtigungAnfordern()
    }

    // Re-schedules all notifications after install/update/relaunch
    @MainActor
    private func planeAlleErinnerungen(container: ModelContainer) async {
        let notif = NotificationManager.shared
        guard notif.status == .authorized else { return }

        // Medikament-Erinnerungen
        let context = ModelContext(container)
        let medikamente = (try? context.fetch(FetchDescriptor<Dauermedikation>())) ?? []
        for med in medikamente {
            notif.planeErinnerungen(fuer: med)
            notif.planeAblaufWarnung(fuer: med)
        }

        // Tages-Erinnerung
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "tagesErinnerungAktiv") {
            let sek = defaults.double(forKey: "tagesErinnerungZeit")
            let zeit = Date(timeIntervalSinceReferenceDate: sek > 0 ? sek : 28800)
            let dc = Calendar.current.dateComponents([.hour, .minute], from: zeit)
            notif.planeTagesErinnerung(stunde: dc.hour ?? 8, minute: dc.minute ?? 0)
        }

        // Wasser-Erinnerung
        if defaults.bool(forKey: "wasserErinnerungAktiv") {
            let sek = defaults.double(forKey: "wasserErinnerungZeit")
            let zeit = Date(timeIntervalSinceReferenceDate: sek > 0 ? sek : 54000)
            let dc = Calendar.current.dateComponents([.hour, .minute], from: zeit)
            notif.planeWasserErinnerung(stunde: dc.hour ?? 15, minute: dc.minute ?? 0)
        }
    }
}
