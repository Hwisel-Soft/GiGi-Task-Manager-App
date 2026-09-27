import UserNotifications
import Foundation

final class NotificationService {
    static let morningId = "gigi.morning.summary"
    static func sessionEndId(_ taskId: Int) -> String { "gigi.session.\(taskId)" }

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func setBadge(_ count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count) { _ in }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func scheduleMorningSummary(hour: Int, minute: Int, body: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.morningId])

        let content = UNMutableNotificationContent()
        content.title = "Good morning from GiGi"
        content.body = body
        content.sound = .default

        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: Self.morningId, content: content, trigger: trigger)
        center.add(request)
    }

    func cancelMorningSummary() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.morningId])
    }

    func scheduleSessionEnd(taskId: Int, title: String, endDate: Date, badgeCount: Int) {
        guard endDate > Date() else { return }
        let center = UNUserNotificationCenter.current()
        let id = Self.sessionEndId(taskId)
        center.removePendingNotificationRequests(withIdentifiers: [id])
        let content = UNMutableNotificationContent()
        content.title = "Session ended — \(title)"
        content.body = "Did you finish it? Open GiGi to log your progress."
        content.sound = .default
        content.badge = NSNumber(value: badgeCount)
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: endDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    func cancelSessionEnd(taskId: Int) {
        let id = Self.sessionEndId(taskId)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    static func followUpId(_ taskId: Int) -> String { "gigi.followup.\(taskId)" }

    func scheduleFollowUp(taskId: Int, title: String, waitingOn: String, date: Date) {
        let fireDate = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
        guard fireDate > Date() else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.followUpId(taskId)])
        let content = UNMutableNotificationContent()
        content.title = "Follow up: \(title)"
        content.body = "Time to check in with \(waitingOn)."
        content.sound = .default
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(identifier: Self.followUpId(taskId), content: content, trigger: trigger))
    }

    func cancelFollowUp(taskId: Int) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.followUpId(taskId)])
    }

    // MARK: Weekly Stats

    static let weeklyId = "gigi.weekly.stats"

    func scheduleWeeklySummary(weekday: Int, hour: Int, minute: Int, body: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.weeklyId])

        let content = UNMutableNotificationContent()
        content.title = "Your week in GiGi"
        content.body = body
        content.sound = .default

        var comps = DateComponents()
        comps.weekday = weekday   // 1 = Sunday … 7 = Saturday
        comps.hour = hour
        comps.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: Self.weeklyId, content: content, trigger: trigger)
        center.add(request)
    }

    func cancelWeeklySummary() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.weeklyId])
    }
}
