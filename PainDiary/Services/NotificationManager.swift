import Foundation
import UserNotifications
import Observation

@Observable
class NotificationManager {
    static let shared = NotificationManager()

    var status: UNAuthorizationStatus = .notDetermined

    init() {
        Task { await aktualisiereStatus() }
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
        await MainActor.run { status = settings.authorizationStatus }
    }

    // MARK: - Medikament-Erinnerungen

    func planeErinnerungen(fuer med: Dauermedikation) {
        loescheErinnerungen(fuer: med)
        guard med.aktiv && med.erinnerungAktiv else { return }

        let zeiten = gueltigeZeiten(fuer: med)
        for (i, zeit) in zeiten.enumerated() {
            scheduleNotification(
                id: "\(med.notifID)-\(i)",
                titel: "💊 \(med.name)",
                body: med.dosierung.isEmpty ? "Zeit für deine Medikation" : "\(med.dosierung) einnehmen",
                stunde: zeit.stunde,
                minute: zeit.minute
            )
        }
    }

    func loescheErinnerungen(fuer med: Dauermedikation) {
        let ids = (0..<5).map { "\(med.notifID)-\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    func gueltigeZeiten(fuer med: Dauermedikation) -> [ZeitPunkt] {
        if !med.erinnerungsZeiten.isEmpty {
            return parseZeitString(med.erinnerungsZeiten)
        }
        return standardZeiten(med.frequenz)
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
            minute: minute
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

    private func scheduleNotification(id: String, titel: String, body: String, stunde: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = titel
        content.body = body
        content.sound = .default
        if #available(iOS 15.0, *) { content.interruptionLevel = .timeSensitive }

        var dc = DateComponents()
        dc.hour = stunde
        dc.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
