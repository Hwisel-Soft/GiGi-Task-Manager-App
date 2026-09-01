import EventKit
import Foundation

final class CalendarSyncService {

    private let ekStore = EKEventStore()

    // MARK: - Access

    var isAuthorized: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    func requestAccess() async -> Bool {
        do {
            return try await ekStore.requestFullAccessToEvents()
        } catch {
            return false
        }
    }

    // MARK: - Write

    func createEvent(title: String, notes: String, startDate: Date, durationMins: Int) -> String? {
        guard isAuthorized else { return nil }
        let event = EKEvent(eventStore: ekStore)
        event.title = title
        event.notes = notes.isEmpty ? nil : notes
        event.startDate = startDate
        event.endDate = startDate.addingTimeInterval(Double(durationMins) * 60)
        event.calendar = ekStore.defaultCalendarForNewEvents
        do {
            try ekStore.save(event, span: .thisEvent, commit: true)
            return event.eventIdentifier
        } catch {
            return nil
        }
    }

    func deleteEvent(id: String) {
        guard isAuthorized, let event = ekStore.event(withIdentifier: id) else { return }
        try? ekStore.remove(event, span: .thisEvent, commit: true)
    }
}
