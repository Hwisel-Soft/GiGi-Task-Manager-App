import AppIntents
import Foundation

struct AddTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Task"
    static var description = IntentDescription("Add a new task to GiGi", categoryName: "Tasks")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Task Title", description: "What's the task?")
    var taskTitle: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let ud = sharedDefaults
        let defaultPriority = Priority(rawValue: ud.string(forKey: "gigi.defaultPriority") ?? "") ?? .medium
        let defaultDuration = ud.string(forKey: "gigi.defaultDuration") ?? "30m"

        var tasks: [GTask] = []
        if let data = ud.data(forKey: "gigi.tasks"),
           let decoded = try? JSONDecoder().decode([GTask].self, from: data) {
            tasks = decoded
        }

        // Derive next ID from the actual max in the stored list to avoid collisions
        // when gigi.nextId in sharedDefaults is stale (e.g. first Siri use after install).
        let storedNextId = ud.integer(forKey: "gigi.nextId")
        let maxExistingId = tasks.map { $0.id }.max() ?? 10
        let nextId = max(11, max(storedNextId, maxExistingId + 1))

        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withFullDate]
        let today = fmt.string(from: Date())

        let newTask = GTask(
            id: nextId,
            title: taskTitle,
            priority: defaultPriority,
            state: .unscheduled,
            age: 0,
            category: "",
            notes: "",
            deadline: nil,
            startTime: nil,
            endTime: nil,
            period: nil,
            waitingOn: nil,
            waitingNote: nil,
            followUpDate: nil,
            waitingDays: 0,
            completedTime: nil,
            completedDateLabel: nil,
            deletedDateLabel: nil,
            duration: defaultDuration,
            calendarEventId: nil,
            bookedDate: nil,
            createdDate: today
        )
        tasks.append(newTask)

        if let encoded = try? JSONEncoder().encode(tasks) {
            ud.set(encoded, forKey: "gigi.tasks")
            ud.set(nextId + 1, forKey: "gigi.nextId")
        }

        return .result(dialog: "Added \"\(taskTitle)\" to GiGi.")
    }
}

struct GiGiShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTaskIntent(),
            phrases: [
                "Add task in \(.applicationName)",
                "New task in \(.applicationName)",
                "Create task in \(.applicationName)"
            ],
            shortTitle: "Add Task",
            systemImageName: "checkmark.circle"
        )
    }
}
