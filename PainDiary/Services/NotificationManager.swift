import Foundation
import UserNotifications
import Observation

// MARK: - Deep Link

enum DeepLink: Equatable {
    case neuerSchmerzEintrag
    case medikamentErfassen(name: String, dosierung: String)
    case einnahmeVerlauf
    case medikamenteAnzeigen
    case wellnessAnzeigen
    case zyklusAnzeigen
}

@Observable
@MainActor
class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    var status: UNAuthorizationStatus = .notDetermined
    var timeSensitiveAktiv: Bool = false
    var pendingDeepLink: DeepLink? = nil

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        Task { await aktualisiereStatus() }
    }

    // Show notifications even when app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    // Deep link when user taps a notification
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo
        let id   = response.notification.request.identifier

        Task { @MainActor [weak self] in
            guard let self else { completionHandler(); return }
            if let type = info["type"] as? String {
                switch type {
                case "schmerz":
                    pendingDeepLink = .neuerSchmerzEintrag
                case "medikament":
                    let name = info["name"] as? String ?? ""
                    let dos  = info["dosierung"] as? String ?? ""
                    pendingDeepLink = .medikamentErfassen(name: name, dosierung: dos)
                case "wirkung":
                    pendingDeepLink = .medikamenteAnzeigen
                default: break
                }
            } else if id == "tages-erinnerung" {
                pendingDeepLink = .neuerSchmerzEintrag
            } else if id.hasPrefix("wirkung-") {
                pendingDeepLink = .medikamenteAnzeigen
            } else if id.hasPrefix("vorrat-") || id.hasPrefix("ablauf-") {
                pendingDeepLink = .medikamenteAnzeigen
            } else if id == "wasser-erinnerung" {
                pendingDeepLink = .wellnessAnzeigen
            } else if id.hasPrefix("zyklus-") {
                pendingDeepLink = .zyklusAnzeigen
            }
            completionHandler()
        }
    }

    func berechtigungAnfordern() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            await aktualisiereStatus()
            return granted
        } catch {
            return false
        }
    }

    private func aktualisiereStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        status = settings.authorizationStatus
        if #available(iOS 15.0, *) {
            timeSensitiveAktiv = settings.timeSensitiveSetting == .enabled
        } else {
            timeSensitiveAktiv = true
        }
    }

    // MARK: - Medikament-Erinnerungen

    func planeErinnerungen(fuer med: Dauermedikation) {
        loescheErinnerungen(fuer: med)
        guard med.aktiv && med.erinnerungAktiv else { return }

        if med.frequenz == "Monatlich" {
            let zeiten = gueltigeZeiten(fuer: med)
            guard let zeit = zeiten.first else { return }
            let tag = Calendar.current.component(.day, from: med.startDatum)
            let hinweis = med.einnahmeHinweis.isEmpty ? "" : " · \(med.einnahmeHinweis)"
            let content = UNMutableNotificationContent()
            content.title = "💊 \(med.name)"
            content.body = med.dosierung.isEmpty ? "Zeit für deine Medikation\(hinweis)" : "\(med.dosierung) einnehmen\(hinweis)"
            content.sound = .default
            content.userInfo = ["type": "medikament", "name": med.name, "dosierung": med.dosierung]
            if #available(iOS 15.0, *) { content.interruptionLevel = .timeSensitive }
            var dc = DateComponents()
            dc.day = tag
            dc.hour = zeit.stunde
            dc.minute = zeit.minute
            UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: "\(med.notifID)-0", content: content,
                                      trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)))
            return
        }

        let zeiten = gueltigeZeiten(fuer: med)
        for (i, zeit) in zeiten.enumerated() {
            let hinweis = med.einnahmeHinweis.isEmpty ? "" : " · \(med.einnahmeHinweis)"
            let body = med.dosierung.isEmpty
                ? "Zeit für deine Medikation\(hinweis)"
                : "\(med.dosierung) einnehmen\(hinweis)"
            scheduleNotification(
                id: "\(med.notifID)-\(i)",
                titel: "💊 \(med.name)",
                body: body,
                stunde: zeit.stunde,
                minute: zeit.minute,
                userInfo: ["type": "medikament", "name": med.name, "dosierung": med.dosierung]
            )
        }
    }

    func loescheErinnerungen(fuer med: Dauermedikation) {
        var ids = (0..<5).map { "\(med.notifID)-\($0)" }
        ids.append("vorrat-\(med.notifID)")
        ids.append("ablauf-\(med.notifID)")
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    func gueltigeZeiten(fuer med: Dauermedikation) -> [ZeitPunkt] {
        if !med.erinnerungsZeiten.isEmpty {
            return parseZeitString(med.erinnerungsZeiten)
        }
        return standardZeiten(med.frequenz)
    }

    func planeVorratWarnung(fuer med: Dauermedikation) {
        let id = "vorrat-\(med.notifID)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        guard status == .authorized, let vorrat = med.vorrat, vorrat <= med.vorratSchwelle, vorrat >= 0 else { return }
        let content = UNMutableNotificationContent()
        content.title = "💊 Vorrat wird knapp"
        content.body = "Noch \(vorrat) \(med.name) auf Vorrat. Bitte rechtzeitig nachbestellen."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    func planeAblaufWarnung(fuer med: Dauermedikation) {
        let id = "ablauf-\(med.notifID)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        guard status == .authorized, let ablauf = med.ablaufDatum else { return }
        let kal = Calendar.current
        guard let warnDatum = kal.date(byAdding: .day, value: -7, to: ablauf),
              warnDatum > Date() else { return }
        var dc = kal.dateComponents([.year, .month, .day], from: warnDatum)
        dc.hour = 9; dc.minute = 0
        scheduleEinmalig(
            id: id,
            titel: "⚠️ Medikament läuft ab",
            body: "\(med.name) läuft in 7 Tagen ab. Bitte rechtzeitig erneuern.",
            components: dc
        )
    }

    func sendeTestBenachrichtigung() {
        let content = UNMutableNotificationContent()
        content.title = "✅ PainDiary Benachrichtigungen"
        content.body = "Benachrichtigungen funktionieren korrekt – im Vordergrund und Hintergrund."
        content.sound = .default
        if #available(iOS 15.0, *) { content.interruptionLevel = .timeSensitive }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "test-benachrichtigung", content: content, trigger: trigger))
    }

    // MARK: - Wasser-Erinnerung

    func planeWasserErinnerung(stunde: Int, minute: Int) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["wasser-erinnerung"])
        scheduleNotification(
            id: "wasser-erinnerung",
            titel: "💧 Genug getrunken heute?",
            body: "Überprüfe dein Wasser-Tagesziel und bleib hydratisiert!",
            stunde: stunde,
            minute: minute
        )
    }

    func loescheWasserErinnerung() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["wasser-erinnerung"])
    }

    // MARK: - Tages-Erinnerung

    func planeTagesErinnerung(stunde: Int, minute: Int) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["tages-erinnerung"])
        scheduleNotification(
            id: "tages-erinnerung",
            titel: "📊 PainDiary",
            body: "Wie geht es dir heute? Erfasse deinen Schmerz.",
            stunde: stunde,
            minute: minute,
            userInfo: ["type": "schmerz"]
        )
    }

    func loescheTagesErinnerung() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["tages-erinnerung"])
    }

    // MARK: - Helpers

    struct ZeitPunkt {
        let stunde: Int
        let minute: Int
        var alsDate: Date {
            var dc = DateComponents()
            dc.hour = stunde
            dc.minute = minute
            return Calendar.current.date(from: dc) ?? Date()
        }
        var anzeigeText: String {
            String(format: "%02d:%02d", stunde, minute)
        }
    }

    func dateZuZeitPunkt(_ date: Date) -> ZeitPunkt {
        let dc = Calendar.current.dateComponents([.hour, .minute], from: date)
        return ZeitPunkt(stunde: dc.hour ?? 8, minute: dc.minute ?? 0)
    }

    func zeitenAlsString(_ zeiten: [ZeitPunkt]) -> String {
        zeiten.map { String(format: "%02d:%02d", $0.stunde, $0.minute) }.joined(separator: ",")
    }

    func parseZeitString(_ s: String) -> [ZeitPunkt] {
        s.components(separatedBy: ",").compactMap { teil in
            let teile = teil.trimmingCharacters(in: .whitespaces).components(separatedBy: ":")
            guard teile.count == 2, let h = Int(teile[0]), let m = Int(teile[1]) else { return nil }
            return ZeitPunkt(stunde: h, minute: m)
        }
    }

    func standardZeiten(_ frequenz: String) -> [ZeitPunkt] {
        switch frequenz {
        case "1× täglich", "Morgens":  return [ZeitPunkt(stunde: 8, minute: 0)]
        case "Abends":                  return [ZeitPunkt(stunde: 21, minute: 0)]
        case "Morgens & Abends":        return [ZeitPunkt(stunde: 8, minute: 0), ZeitPunkt(stunde: 21, minute: 0)]
        case "2× täglich":              return [ZeitPunkt(stunde: 8, minute: 0), ZeitPunkt(stunde: 20, minute: 0)]
        case "3× täglich":              return [ZeitPunkt(stunde: 8, minute: 0), ZeitPunkt(stunde: 14, minute: 0), ZeitPunkt(stunde: 20, minute: 0)]
        case "Bei Bedarf":              return []
        case "Wöchentlich":             return [ZeitPunkt(stunde: 8, minute: 0)]
        case "Monatlich":               return [ZeitPunkt(stunde: 8, minute: 0)]
        default:                        return [ZeitPunkt(stunde: 8, minute: 0)]
        }
    }

    func anzahlDosen(_ frequenz: String) -> Int {
        switch frequenz {
        case "3× täglich":              return 3
        case "2× täglich", "Morgens & Abends": return 2
        case "Bei Bedarf":              return 0
        default:                        return 1
        }
    }

    // MARK: - Zyklus-Erinnerungen

    func planeZyklusErinnerungen(analyse: ZyklusAnalyse) {
        loescheZyklusErinnerungen()
        guard status == .authorized, !analyse.zyklusStarts.isEmpty else { return }
        let kal = Calendar.current
        let heute = kal.startOfDay(for: Date())

        // Periode: 2 Tage vorher um 09:00
        if let naechste = analyse.naechstePeriodeStart,
           let zweiVorher = kal.date(byAdding: .day, value: -2, to: naechste),
           zweiVorher >= heute {
            var dc = kal.dateComponents([.year, .month, .day], from: zweiVorher)
            dc.hour = 9; dc.minute = 0
            scheduleEinmalig(
                id: "zyklus-periode",
                titel: "Periode erwartet",
                body: "Deine Periode könnte in 2 Tagen beginnen.",
                components: dc
            )
        }

        // Fruchtbares Fenster: erster zukünftiger fruchtbarer Tag um 08:00
        let naechsterFruchtbar = analyse.fruchtbareTageSet
            .filter { $0 >= heute }
            .sorted().first
        if let fTag = naechsterFruchtbar {
            var dc = kal.dateComponents([.year, .month, .day], from: fTag)
            dc.hour = 8; dc.minute = 0
            scheduleEinmalig(
                id: "zyklus-fruchtbar",
                titel: "Fruchtbare Tage beginnen",
                body: "Dein fruchtbares Fenster startet heute.",
                components: dc
            )
        }

        // Eisprung: vorhergesagter Tag um 08:30
        if let ov = analyse.vorhergesagteOvulation,
           kal.startOfDay(for: ov) >= heute {
            var dc = kal.dateComponents([.year, .month, .day], from: ov)
            dc.hour = 8; dc.minute = 30
            scheduleEinmalig(
                id: "zyklus-eisprung",
                titel: "Eisprung heute erwartet",
                body: "Dein vorhergesagter Eisprung ist heute.",
                components: dc
            )
        }
    }

    func planeWirkungsAbfrage(fuer log: EinnahmeLog, stunden: Int = 2) {
        guard status == .authorized else { return }
        let content = UNMutableNotificationContent()
        content.title = "💊 Hat \(log.medikamentName) gewirkt?"
        content.body = "Tippe um deine Einnahme zu bewerten."
        content.sound = .default
        content.userInfo = ["type": "wirkung", "name": log.medikamentName]
        if #available(iOS 15.0, *) { content.interruptionLevel = .passive }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Double(stunden) * 3600, repeats: false)
        let id = "wirkung-\(Int(log.datum.timeIntervalSince1970))"
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    func loescheZyklusErinnerungen() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["zyklus-periode", "zyklus-fruchtbar", "zyklus-eisprung"])
    }

    private func scheduleEinmalig(id: String, titel: String, body: String, components: DateComponents) {
        let content = UNMutableNotificationContent()
        content.title = titel
        content.body = body
        content.sound = .default
        if #available(iOS 15.0, *) { content.interruptionLevel = .timeSensitive }
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    private func scheduleNotification(id: String, titel: String, body: String, stunde: Int, minute: Int, userInfo: [AnyHashable: Any] = [:]) {
        let content = UNMutableNotificationContent()
        content.title = titel
        content.body = body
        content.sound = .default
        content.userInfo = userInfo
        if #available(iOS 15.0, *) { content.interruptionLevel = .timeSensitive }

        var dc = DateComponents()
        dc.hour = stunde
        dc.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
