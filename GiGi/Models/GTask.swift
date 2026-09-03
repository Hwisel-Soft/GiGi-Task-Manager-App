import Foundation

enum Priority: String, Codable, CaseIterable {
    case high, medium, low
    var label: String {
        switch self { case .high: "High"; case .medium: "Medium"; case .low: "Low" }
    }
}

enum TaskState: String, Codable {
    case unscheduled, booked, waiting, completed, deleted
}

struct GTask: Identifiable, Codable {
    var id: Int
    var title: String
    var priority: Priority
    var state: TaskState
    var age: Int
    var category: String
    var notes: String
    var deadline: String?
    var startTime: String?
    var endTime: String?
    var period: String?
    var waitingOn: String?
    var waitingNote: String?
    var followUpDate: String?
    var waitingDays: Int
    var completedTime: String?
    var completedDateLabel: String?
    var deletedDateLabel: String?
    var duration: String?
    var calendarEventId: String?
    var bookedDate: String?   // ISO8601 date "2026-09-01" for EventKit reconstruction
    var createdDate: String?  // ISO8601 date task was first added
}
