import EventKit
import Foundation

final class CalendarSyncService {

    private let ekStore = EKEventStore()
    private let gigiTitle = "GiGi Tasks"

    // MARK: - Access

    var isAuthorized: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    var gigiCalendarName: String { gigiTitle }

    func requestAccess() async -> Bool {
        do {
            return try await ekStore.requestFullAccessToEvents()
        } catch {
            return false
        }
    }

    // MARK: - GiGi Calendar

    private var gigiCalendar: EKCalendar? {
        if let cal = ekStore.calendars(for: .event).first(where: { $0.title == gigiTitle }) {
            return cal
        }
        guard isAuthorized else { return nil }
        let source = ekStore.defaultCalendarForNewEvents?.source
                  ?? ekStore.sources.first(where: { $0.sourceType == .local })
        guard let source else { return nil }
        let cal = EKCalendar(for: .event, eventStore: ekStore)
        cal.title = gigiTitle
        cal.source = source
        do {
            try ekStore.saveCalendar(cal, commit: true)
            return cal
        } catch {
            return nil
        }
    }

    // MARK: - Write

    func createEvent(title: String, notes: String, startDate: Date, durationMins: Int) -> String? {
        guard isAuthorized, let calendar = gigiCalendar else { return nil }
        let event = EKEvent(eventStore: ekStore)
        event.title = title
        event.notes = notes.isEmpty ? nil : notes
        event.startDate = startDate
        event.endDate = startDate.addingTimeInterval(Double(durationMins) * 60)
        event.calendar = calendar
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

    // MARK: - Conflict Detection

    func externalEventsConflicting(start: Date, end: Date) -> [EKEvent] {
        guard isAuthorized else { return [] }
        let external = ekStore.calendars(for: .event).filter { $0.title != gigiTitle }
        guard !external.isEmpty else { return [] }
        let pred = ekStore.predicateForEvents(withStart: start, end: end, calendars: external)
        return ekStore.events(matching: pred).filter { !$0.isAllDay }
    }
}
