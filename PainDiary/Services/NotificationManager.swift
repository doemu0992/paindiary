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

    func planeErinnerungen(fuer med: Dauermedikation) {
        loescheErinnerungen(fuer: med)
        guard med.aktiv else { return }

        let zeiten = zeigenFuerFrequenz(med.frequenz)
        for (i, stunde) in zeiten.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "💊 \(med.name)"
            content.body = med.dosierung.isEmpty
                ? "Zeit für deine Medikation"
                : "\(med.dosierung) einnehmen"
            content.sound = .default
            if #available(iOS 15.0, *) {
                content.interruptionLevel = .timeSensitive
            }

            var dc = DateComponents()
            dc.hour = stunde
            dc.minute = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
            let request = UNNotificationRequest(
                identifier: "\(med.notifID)-\(i)",
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    func loescheErinnerungen(fuer med: Dauermedikation) {
        let ids = (0..<5).map { "\(med.notifID)-\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    func anzahlAktiveFuerMed(_ med: Dauermedikation) -> Int {
        zeigenFuerFrequenz(med.frequenz).count
    }

    private func zeigenFuerFrequenz(_ frequenz: String) -> [Int] {
        switch frequenz {
        case "1× täglich", "Morgens":  return [8]
        case "Abends":                  return [21]
        case "Morgens & Abends":        return [8, 21]
        case "2× täglich":              return [8, 20]
        case "3× täglich":              return [8, 14, 20]
        case "Bei Bedarf":              return []
        case "Wöchentlich":             return [8]
        default:                        return [8]
        }
    }
}
