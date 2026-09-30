import Foundation
import Observation
import SwiftUI
import EventKit

private let appGroupId = "group.com.johnnassar.GiGi"
var sharedDefaults: UserDefaults { UserDefaults(suiteName: appGroupId) ?? .standard }

// MARK: - Supporting Types

enum AppTab: String, Hashable, CaseIterable {
    case today, tasks, calendar, history, settings

    var title: String {
        switch self {
        case .today:    "Today"
        case .tasks:    "Tasks"
        case .calendar: "Calendar"
        case .history:  "History"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .today:    "sun.max"
        case .tasks:    "checklist"
        case .calendar: "calendar"
        case .history:  "clock.arrow.circlepath"
        case .settings: "gearshape"
        }
    }
}

enum HistorySubTab: String, CaseIterable {
    case completed = "Completed"
    case deleted = "Deleted"
    case insights = "Insights"
}

enum InsightsPeriod: String, CaseIterable {
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case lastMonth = "Last Month"
    case allTime = "All Time"
}

struct AddForm {
    var title: String = ""
    var priority: Priority = .medium
    var duration: String = "30m"
    var notes: String = ""
    var deadline: String = ""
    var category: String = ""
}

struct BookForm {
    var date: Date = Calendar.current.startOfDay(for: Date())
    var hour: Int = 2
    var minute: Int = 0
    var period: String = "PM"
    var duration: String = "1h"

    init(duration: String = "1h") {
        self.date = Calendar.current.startOfDay(for: Date())
        self.duration = duration
    }
}

struct WaitForm {
    var name: String = ""
    var note: String = ""
    var followUpDate: String = ""
}

struct CatForm {
    var name: String = ""
    var color: String = "#3D5AFE"
}

// MARK: - AppStore

enum TaskSort: String, CaseIterable {
    case priority = "Priority"
    case dueTime = "Due time"
    case scheduledDate = "Scheduled date"
    case dateAdded = "Date added"
}

@MainActor
@Observable
final class AppStore {

    // MARK: Data
    var tasks: [GTask]
    var categories: [GCategory]
    var darkMode: Bool
    var nextId: Int
    var nextCatId: Int

    // Settings
    var lapsedAlert: Bool
    var morningSummary: Bool
    var morningHour: Int    // 0-23
    var morningMinute: Int  // 0-59
    var weeklyStats: Bool
    var weeklyDay: Int      // 1=Sun … 7=Sat
    var weeklyHour: Int     // 0-23
    var weeklyMinute: Int   // 0-59
    var colorfulCards: Bool
    var calSync: Bool
    var defaultDuration: String
    var defaultPriority: Priority
    var defaultTaskSort: TaskSort
    var defaultCategory: String

    // MARK: Navigation
    var selectedTab: AppTab = .today
    var selectedTaskId: Int? = nil
    var showDetail: Bool = false

    // MARK: Sheets
    var showAddTask: Bool = false
    var showBookTime: Bool = false
    var showWaitingSheet: Bool = false
    var showNudgeSheet: Bool = false
    var showCategorySheet: Bool = false
    var showSiriInfo: Bool = false
    var showMicInfo: Bool = false

    // MARK: Forms
    var addForm: AddForm = AddForm()
    var bookForm: BookForm = BookForm()
    var waitForm: WaitForm = WaitForm()
    var catForm: CatForm = CatForm()
    var editingCategoryId: Int? = nil

    // MARK: Calendar
    var calendarAddMode: Bool = false
    var calSelDay: Int
    var calDrawerOpen: Bool = false

    // MARK: History
    var historySubTab: HistorySubTab = .completed
    var insightsPeriod: InsightsPeriod = .thisWeek

    // MARK: Services
    private let calendarSvc = CalendarSyncService()
    private let notifSvc = NotificationService()

    // MARK: Swipe
    var swipedTaskId: Int? = nil

    @ObservationIgnored private var saveSideEffectsTask: Task<Void, Never>?

    // MARK: Lapsed
    var dismissedLapseIds: [Int] = []

    // MARK: Colors
    var C: GColors { darkMode ? .dark : .light }

    // MARK: Init
    init() {
        AppStore.migrateToSharedDefaultsIfNeeded()
        AppStore.mergeKVStoreIntoDefaults()
        let ud = sharedDefaults
        let decoder = JSONDecoder()

        if let d = ud.data(forKey: "gigi.tasks"),
           let v = try? decoder.decode([GTask].self, from: d) {
            tasks = v
        } else {
            tasks = AppStore.sampleTasks
        }

        if let d = ud.data(forKey: "gigi.categories"),
           let v = try? decoder.decode([GCategory].self, from: d) {
            categories = v
        } else {
            categories = AppStore.sampleCategories
        }

        darkMode = ud.bool(forKey: "gigi.darkMode")
        lapsedAlert = ud.object(forKey: "gigi.lapsedAlert") as? Bool ?? true
        morningSummary = ud.object(forKey: "gigi.morningSummary") as? Bool ?? true
        morningHour = ud.object(forKey: "gigi.morningHour") as? Int ?? 8
        morningMinute = ud.object(forKey: "gigi.morningMinute") as? Int ?? 0
        weeklyStats = ud.object(forKey: "gigi.weeklyStats") as? Bool ?? true
        weeklyDay = ud.object(forKey: "gigi.weeklyDay") as? Int ?? 1
        weeklyHour = ud.object(forKey: "gigi.weeklyHour") as? Int ?? 18
        weeklyMinute = ud.object(forKey: "gigi.weeklyMinute") as? Int ?? 0
        colorfulCards = ud.object(forKey: "gigi.colorfulCards") as? Bool ?? true
        calSync = ud.object(forKey: "gigi.calSync") as? Bool ?? true
        defaultDuration = ud.string(forKey: "gigi.defaultDuration") ?? "30m"
        defaultPriority = Priority(rawValue: ud.string(forKey: "gigi.defaultPriority") ?? "") ?? .medium
        defaultTaskSort = TaskSort(rawValue: ud.string(forKey: "gigi.defaultTaskSort") ?? "") ?? .priority
        defaultCategory = ud.string(forKey: "gigi.defaultCategory") ?? ""
        nextId = max(11, ud.integer(forKey: "gigi.nextId"))
        nextCatId = max(6, ud.integer(forKey: "gigi.nextCatId"))
        calSelDay = Calendar.current.component(.weekday, from: Date()) - 1
        setupKVStoreSync()
    }

    // One-time migration from UserDefaults.standard to shared App Group container.
    // Runs silently on first launch after updating.
    private static func migrateToSharedDefaultsIfNeeded() {
        let migrationKey = "gigi.migratedToAppGroup"
        guard !sharedDefaults.bool(forKey: migrationKey) else { return }
        let std = UserDefaults.standard
        let keys = ["gigi.tasks", "gigi.categories", "gigi.darkMode", "gigi.lapsedAlert",
                    "gigi.morningSummary", "gigi.morningHour", "gigi.morningMinute",
                    "gigi.colorfulCards", "gigi.calSync", "gigi.defaultDuration",
                    "gigi.defaultPriority", "gigi.nextId", "gigi.nextCatId"]
        for key in keys {
            if let val = std.object(forKey: key) {
                sharedDefaults.set(val, forKey: key)
            }
        }
        sharedDefaults.set(true, forKey: migrationKey)
    }

    // MARK: Persistence
    func save() {
        let ud = sharedDefaults
        let encoder = JSONEncoder()

        // Absorb any tasks written to sharedDefaults by an AppIntent (Siri/Shortcuts)
        // while this process was running. AppIntents run in-process and write directly
        // to sharedDefaults without going through AppStore, so a plain save() would
        // overwrite their work. Merging first ensures they survive.
        if let d = ud.data(forKey: "gigi.tasks"),
           let stored = try? JSONDecoder().decode([GTask].self, from: d) {
            let inMemoryIds = Set(tasks.map { $0.id })
            let external = stored.filter { !inMemoryIds.contains($0.id) && $0.id >= 11 }
            if !external.isEmpty {
                tasks.append(contentsOf: external)
                nextId = max(nextId, (stored.map { $0.id }.max() ?? 0) + 1)
            }
        }

        if let d = try? encoder.encode(tasks) { ud.set(d, forKey: "gigi.tasks") }
        if let d = try? encoder.encode(categories) { ud.set(d, forKey: "gigi.categories") }
        ud.set(darkMode, forKey: "gigi.darkMode")
        ud.set(lapsedAlert, forKey: "gigi.lapsedAlert")
        ud.set(morningSummary, forKey: "gigi.morningSummary")
        ud.set(morningHour, forKey: "gigi.morningHour")
        ud.set(morningMinute, forKey: "gigi.morningMinute")
        ud.set(weeklyStats, forKey: "gigi.weeklyStats")
        ud.set(weeklyDay, forKey: "gigi.weeklyDay")
        ud.set(weeklyHour, forKey: "gigi.weeklyHour")
        ud.set(weeklyMinute, forKey: "gigi.weeklyMinute")
        ud.set(colorfulCards, forKey: "gigi.colorfulCards")
        ud.set(calSync, forKey: "gigi.calSync")
        ud.set(defaultDuration, forKey: "gigi.defaultDuration")
        ud.set(defaultPriority.rawValue, forKey: "gigi.defaultPriority")
        ud.set(defaultTaskSort.rawValue, forKey: "gigi.defaultTaskSort")
        ud.set(defaultCategory, forKey: "gigi.defaultCategory")
        ud.set(nextId, forKey: "gigi.nextId")
        ud.set(nextCatId, forKey: "gigi.nextCatId")
        // Debounce badge update, notification scheduling, and iCloud push —
        // these are expensive and don't need to block each user interaction.
        saveSideEffectsTask?.cancel()
        saveSideEffectsTask = Task {
            do { try await Task.sleep(for: .seconds(1.5)) } catch { return }
            updateBadge()
            scheduleMorningNotification()
            scheduleWeeklyStatsNotification()
            pushToKVStore()
        }
    }

    func updateBadge() {
        notifSvc.setBadge(tasksAlertCount)
    }

    func reloadTasksFromUserDefaults() {
        let ud = sharedDefaults
        guard let d = ud.data(forKey: "gigi.tasks"),
              let decoded = try? JSONDecoder().decode([GTask].self, from: d) else { return }
        tasks = decoded
        nextId = max(nextId, ud.integer(forKey: "gigi.nextId"))
    }

    // MARK: iCloud Key-Value Sync

    private static let kvSyncKeys = [
        "gigi.tasks", "gigi.categories", "gigi.darkMode",
        "gigi.lapsedAlert", "gigi.morningSummary", "gigi.morningHour",
        "gigi.morningMinute", "gigi.weeklyStats", "gigi.weeklyDay",
        "gigi.weeklyHour", "gigi.weeklyMinute", "gigi.colorfulCards", "gigi.calSync",
        "gigi.defaultDuration", "gigi.defaultPriority", "gigi.defaultTaskSort",
        "gigi.defaultCategory", "gigi.nextId", "gigi.nextCatId"
    ]

    static func mergeKVStoreIntoDefaults() {
        let kvs = NSUbiquitousKeyValueStore.default
        kvs.synchronize()
        let ud = sharedDefaults
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()

        let kvTasksExist = kvs.object(forKey: "gigi.tasks") != nil
        let kvNextId = Int(kvs.longLong(forKey: "gigi.nextId"))
        let localNextId = ud.integer(forKey: "gigi.nextId")

        // Tasks: iCloud wins for shared task IDs; preserve local-only real tasks (ID >= 11).
        // IDs 1-10 are sample tasks and are never merged from local into iCloud data.
        // This lets completions/edits sync while keeping tasks added via Siri offline.
        if kvs.object(forKey: "gigi.tasks") != nil {
            let icloudTasks = kvs.data(forKey: "gigi.tasks")
                .flatMap { try? decoder.decode([GTask].self, from: $0) } ?? []
            let localTasks = ud.data(forKey: "gigi.tasks")
                .flatMap { try? decoder.decode([GTask].self, from: $0) } ?? []
            let icloudIds = Set(icloudTasks.map { $0.id })
            var merged = icloudTasks
            for task in localTasks where !icloudIds.contains(task.id) && task.id >= 11 {
                merged.append(task)
            }
            if let d = try? encoder.encode(merged) { ud.set(d, forKey: "gigi.tasks") }
            ud.set(max(ud.integer(forKey: "gigi.nextId"), kvNextId), forKey: "gigi.nextId")
        }

        // Categories: iCloud always wins
        if let d = kvs.data(forKey: "gigi.categories") { ud.set(d, forKey: "gigi.categories") }
        let kvNextCatId = Int(kvs.longLong(forKey: "gigi.nextCatId"))
        if kvNextCatId > 0 {
            ud.set(max(ud.integer(forKey: "gigi.nextCatId"), kvNextCatId), forKey: "gigi.nextCatId")
        }

        // Settings: iCloud always wins if present
        let stringKeys: Set<String> = ["gigi.defaultDuration", "gigi.defaultPriority", "gigi.defaultTaskSort", "gigi.defaultCategory"]
        let boolKeys: Set<String> = ["gigi.darkMode", "gigi.lapsedAlert", "gigi.morningSummary",
                                     "gigi.weeklyStats", "gigi.colorfulCards", "gigi.calSync"]
        let intKeys: Set<String> = ["gigi.morningHour", "gigi.morningMinute",
                                    "gigi.weeklyDay", "gigi.weeklyHour", "gigi.weeklyMinute"]
        for key in kvSyncKeys {
            guard kvs.object(forKey: key) != nil else { continue }
            if stringKeys.contains(key) {
                if let s = kvs.string(forKey: key) { ud.set(s, forKey: key) }
            } else if boolKeys.contains(key) {
                ud.set(kvs.bool(forKey: key), forKey: key)
            } else if intKeys.contains(key) {
                ud.set(Int(kvs.longLong(forKey: key)), forKey: key)
            }
        }
    }

    private func pushToKVStore() {
        // nextId > 11 means at least one real task exists or was created here.
        // If nextId == 11 we only have sample data — don't overwrite iCloud.
        guard nextId > 11 else { return }
        let kvs = NSUbiquitousKeyValueStore.default
        let ud = sharedDefaults
        if let d = ud.data(forKey: "gigi.tasks") { kvs.set(d, forKey: "gigi.tasks") }
        if let d = ud.data(forKey: "gigi.categories") { kvs.set(d, forKey: "gigi.categories") }
        kvs.set(ud.bool(forKey: "gigi.darkMode"), forKey: "gigi.darkMode")
        kvs.set(ud.bool(forKey: "gigi.lapsedAlert"), forKey: "gigi.lapsedAlert")
        kvs.set(ud.bool(forKey: "gigi.morningSummary"), forKey: "gigi.morningSummary")
        kvs.set(Int64(ud.integer(forKey: "gigi.morningHour")), forKey: "gigi.morningHour")
        kvs.set(Int64(ud.integer(forKey: "gigi.morningMinute")), forKey: "gigi.morningMinute")
        kvs.set(ud.bool(forKey: "gigi.weeklyStats"), forKey: "gigi.weeklyStats")
        kvs.set(Int64(ud.integer(forKey: "gigi.weeklyDay")), forKey: "gigi.weeklyDay")
        kvs.set(Int64(ud.integer(forKey: "gigi.weeklyHour")), forKey: "gigi.weeklyHour")
        kvs.set(Int64(ud.integer(forKey: "gigi.weeklyMinute")), forKey: "gigi.weeklyMinute")
        kvs.set(ud.bool(forKey: "gigi.colorfulCards"), forKey: "gigi.colorfulCards")
        kvs.set(ud.bool(forKey: "gigi.calSync"), forKey: "gigi.calSync")
        if let s = ud.string(forKey: "gigi.defaultDuration") { kvs.set(s, forKey: "gigi.defaultDuration") }
        if let s = ud.string(forKey: "gigi.defaultPriority") { kvs.set(s, forKey: "gigi.defaultPriority") }
        if let s = ud.string(forKey: "gigi.defaultTaskSort") { kvs.set(s, forKey: "gigi.defaultTaskSort") }
        kvs.set(ud.string(forKey: "gigi.defaultCategory") ?? "", forKey: "gigi.defaultCategory")
        kvs.set(Int64(ud.integer(forKey: "gigi.nextId")), forKey: "gigi.nextId")
        kvs.set(Int64(ud.integer(forKey: "gigi.nextCatId")), forKey: "gigi.nextCatId")
        kvs.synchronize()
    }

    private func setupKVStoreSync() {
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            let reason = notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int ?? -1
            let reasonLabel: String
            switch reason {
            case NSUbiquitousKeyValueStoreServerChange: reasonLabel = "serverChange"
            case NSUbiquitousKeyValueStoreInitialSyncChange: reasonLabel = "initialSync"
            case NSUbiquitousKeyValueStoreQuotaViolationChange: reasonLabel = "quotaViolation"
            case NSUbiquitousKeyValueStoreAccountChange: reasonLabel = "accountChange"
            default: reasonLabel = "unknown(\(reason))"
            }
            if reason == NSUbiquitousKeyValueStoreQuotaViolationChange { return }
            MainActor.assumeIsolated {
                AppStore.mergeKVStoreIntoDefaults()
                self.reloadFromKVStore()
            }
        }
    }

    private func reloadFromKVStore() {
        let ud = sharedDefaults
        let decoder = JSONDecoder()
        if let d = ud.data(forKey: "gigi.tasks"),
           let v = try? decoder.decode([GTask].self, from: d) {
            tasks = v
        }
        if let d = ud.data(forKey: "gigi.categories"),
           let v = try? decoder.decode([GCategory].self, from: d) {
            categories = v
        }
        darkMode = ud.bool(forKey: "gigi.darkMode")
        lapsedAlert = ud.object(forKey: "gigi.lapsedAlert") as? Bool ?? true
        morningSummary = ud.object(forKey: "gigi.morningSummary") as? Bool ?? true
        morningHour = ud.object(forKey: "gigi.morningHour") as? Int ?? 8
        morningMinute = ud.object(forKey: "gigi.morningMinute") as? Int ?? 0
        weeklyStats = ud.object(forKey: "gigi.weeklyStats") as? Bool ?? true
        weeklyDay = ud.object(forKey: "gigi.weeklyDay") as? Int ?? 1
        weeklyHour = ud.object(forKey: "gigi.weeklyHour") as? Int ?? 18
        weeklyMinute = ud.object(forKey: "gigi.weeklyMinute") as? Int ?? 0
        colorfulCards = ud.object(forKey: "gigi.colorfulCards") as? Bool ?? true
        calSync = ud.object(forKey: "gigi.calSync") as? Bool ?? true
        defaultDuration = ud.string(forKey: "gigi.defaultDuration") ?? "30m"
        defaultPriority = Priority(rawValue: ud.string(forKey: "gigi.defaultPriority") ?? "") ?? .medium
        defaultTaskSort = TaskSort(rawValue: ud.string(forKey: "gigi.defaultTaskSort") ?? "") ?? .priority
        defaultCategory = ud.string(forKey: "gigi.defaultCategory") ?? ""
        nextId = max(nextId, ud.integer(forKey: "gigi.nextId"))
        nextCatId = max(nextCatId, ud.integer(forKey: "gigi.nextCatId"))
    }

    func autoUpdateAges() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let isoFmt = ISO8601DateFormatter()
        isoFmt.formatOptions = [.withFullDate]
        isoFmt.timeZone = .current
        var changed = false
        for i in tasks.indices {
            if let created = tasks[i].createdDate, let d = isoFmt.date(from: created) {
                let days = cal.dateComponents([.day], from: cal.startOfDay(for: d), to: today).day ?? 0
                if tasks[i].age != days { tasks[i].age = max(0, days); changed = true }
            }
            if tasks[i].state == .waiting, let since = tasks[i].waitingSince, let d = isoFmt.date(from: since) {
                let days = cal.dateComponents([.day], from: cal.startOfDay(for: d), to: today).day ?? 0
                if tasks[i].waitingDays != days { tasks[i].waitingDays = max(0, days); changed = true }
            }
            // Roll past-date booked tasks forward to tomorrow at the same time
            if tasks[i].state == .booked,
               let bd = tasks[i].bookedDate,
               let bookedDay = isoFmt.date(from: bd),
               cal.startOfDay(for: bookedDay) < today {
                tasks[i].bookedDate = isoFmt.string(from: today)
                tasks[i].age += 1
                tasks[i].autoRolled = true
                notifSvc.cancelSessionEnd(taskId: tasks[i].id)
                changed = true
            }
        }
        if changed {
            save()
            for task in tasks where task.state == .booked {
                scheduleSessionEndNotification(for: task)
            }
        }
    }

    // MARK: Computed
    var lapsedTask: GTask? {
        guard lapsedAlert else { return nil }
        let now = Date()
        let nowMins = Calendar.current.component(.hour, from: now) * 60
                    + Calendar.current.component(.minute, from: now)
        let isoFmt = ISO8601DateFormatter(); isoFmt.formatOptions = [.withFullDate]
        let todayStr = isoFmt.string(from: now)
        return tasks.first { t in
            guard t.state == .booked, !dismissedLapseIds.contains(t.id),
                  t.endTime != nil, t.period != nil else { return false }
            if let bd = t.bookedDate, bd != todayStr { return false }
            return nowMins > endTimeMinutes(t)
        }
    }

    var waitingTasks: [GTask] { tasks.filter { $0.state == .waiting } }
    var hasOverdueWaiting: Bool { waitingTasks.contains { isFollowUpDue($0) } }
    var lapsedTasks: [GTask] {
        let now = Date()
        let isoFmt = ISO8601DateFormatter(); isoFmt.formatOptions = [.withFullDate]
        let todayStr = isoFmt.string(from: now)
        let nowMins = Calendar.current.component(.hour, from: now) * 60
                    + Calendar.current.component(.minute, from: now)
        return tasks.filter { t in
            guard t.state == .booked else { return false }
            // Carried-forward tasks always need attention regardless of time
            if t.autoRolled == true { return true }
            // Time-based: end time passed today
            guard let bd = t.bookedDate, bd == todayStr,
                  t.endTime != nil, t.period != nil else { return false }
            return nowMins > endTimeMinutes(t)
        }
        .sorted { timeToMinutes($0.startTime, $0.period) < timeToMinutes($1.startTime, $1.period) }
    }
    var scheduledTasks: [GTask] {
        let now = Date()
        let isoFmt = ISO8601DateFormatter(); isoFmt.formatOptions = [.withFullDate]
        let todayStr = isoFmt.string(from: now)
        let nowMins = Calendar.current.component(.hour, from: now) * 60
                    + Calendar.current.component(.minute, from: now)
        return tasks.filter { t in
            guard t.state == .booked else { return false }
            // Carried-forward tasks belong in Lapsed, not Scheduled
            if t.autoRolled == true { return false }
            if let bd = t.bookedDate, bd == todayStr,
               t.endTime != nil, t.period != nil,
               nowMins > endTimeMinutes(t) { return false }
            return true
        }
        .sorted { timeToMinutes($0.startTime, $0.period) < timeToMinutes($1.startTime, $1.period) }
    }
    var todaysScheduledTasks: [GTask] {
        let isoFmt = ISO8601DateFormatter(); isoFmt.formatOptions = [.withFullDate]
        let todayStr = isoFmt.string(from: Date())
        return tasks.filter { t in
            guard t.state == .booked else { return false }
            if let bd = t.bookedDate { return bd == todayStr }
            return true
        }
        .sorted { timeToMinutes($0.startTime, $0.period) < timeToMinutes($1.startTime, $1.period) }
    }
    var unscheduledTasks: [GTask] {
        let order: [Priority: Int] = [.high: 0, .medium: 1, .low: 2]
        return tasks.filter { $0.state == .unscheduled }
            .sorted { a, b in
                let pa = order[a.priority] ?? 1, pb = order[b.priority] ?? 1
                return pa != pb ? pa < pb : a.age > b.age
            }
    }
    var completedTasks: [GTask] { tasks.filter { $0.state == .completed } }
    var deletedTasks: [GTask] { tasks.filter { $0.state == .deleted } }

    func isFollowUpDue(_ task: GTask) -> Bool {
        guard let s = task.followUpDate else { return false }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        f.timeZone = .current
        guard let d = f.date(from: s) else { return false }
        return d <= Calendar.current.startOfDay(for: Date())
    }

    func isLapsed(_ task: GTask) -> Bool {
        guard task.state == .booked else { return false }
        let now = Date()
        let isoFmt = ISO8601DateFormatter(); isoFmt.formatOptions = [.withFullDate]
        let todayStr = isoFmt.string(from: now)
        if let bd = task.bookedDate, bd != todayStr { return false }
        let nowMins = Calendar.current.component(.hour, from: now) * 60
                    + Calendar.current.component(.minute, from: now)
        guard task.endTime != nil, task.period != nil else { return false }
        return nowMins > endTimeMinutes(task)
    }

    var tasksAlertCount: Int {
        lapsedTasks.count + waitingTasks.filter { isFollowUpDue($0) }.count
    }

    func timeToMinutes(_ time: String?, _ period: String?) -> Int {
        guard let t = time else { return 0 }
        let p = t.split(separator: ":").compactMap { Int($0) }
        var h = p.first ?? 0; let m = p.dropFirst().first ?? 0
        if period == "PM" && h != 12 { h += 12 }
        if period == "AM" && h == 12 { h = 0 }
        return h * 60 + m
    }

    // End time uses the start period, which is wrong when the task crosses AM/PM noon boundary.
    // e.g. 11:30 AM + 1h stores endTime="12:30", period="AM" → timeToMinutes gives 30 (midnight).
    // Fix: if computed end < start, the end crossed a 12h boundary — add 12*60.
    func endTimeMinutes(_ task: GTask) -> Int {
        let start = timeToMinutes(task.startTime, task.period)
        let end = timeToMinutes(task.endTime, task.period)
        return end < start ? end + 12 * 60 : end
    }

    func categoryColor(_ name: String) -> Color {
        Color(hex: categories.first(where: { $0.name == name })?.color ?? "#9494AA")
    }

    func selectedTask() -> GTask? {
        guard let id = selectedTaskId else { return nil }
        return tasks.first(where: { $0.id == id })
    }

    // MARK: Mutation Helper
    private func update(_ id: Int, _ fn: (inout GTask) -> Void) {
        guard let i = tasks.firstIndex(where: { $0.id == id }) else { return }
        fn(&tasks[i])
        save()
    }

    // MARK: Navigation
    func openAddTask() {
        addForm = AddForm()
        addForm.category = defaultCategory
        addForm.priority = defaultPriority
        addForm.duration = defaultDuration
        showAddTask = true
    }

    func openTask(_ id: Int) {
        swipedTaskId = nil
        selectedTaskId = id
        showDetail = true
    }

    func goBack() {
        showDetail = false
        selectedTaskId = nil
        showBookTime = false
        showWaitingSheet = false
        showNudgeSheet = false
    }

    func switchTab(_ tab: AppTab) {
        selectedTab = tab
        showDetail = false
        selectedTaskId = nil
        showAddTask = false
        showBookTime = false
        showWaitingSheet = false
        showNudgeSheet = false
        swipedTaskId = nil
        calDrawerOpen = false
    }

    // MARK: Task Actions
    func completeTask(_ id: Int) {
        let timeFmt = DateFormatter(); timeFmt.timeStyle = .short
        let isoFmt = ISO8601DateFormatter(); isoFmt.formatOptions = [.withFullDate]
        if let task = tasks.first(where: { $0.id == id }) { removeCalendarEvent(for: task) }
        notifSvc.cancelSessionEnd(taskId: id)
        update(id) { t in
            t.state = .completed
            t.completedTime = timeFmt.string(from: Date())
            t.completedDateLabel = isoFmt.string(from: Date())
            t.calendarEventId = nil
        }
        if showDetail && selectedTaskId == id { goBack() }
        swipedTaskId = nil
        dismissedLapseIds.append(id)
    }

    func deleteTask(_ id: Int) {
        let isoFmt = ISO8601DateFormatter(); isoFmt.formatOptions = [.withFullDate]
        if let task = tasks.first(where: { $0.id == id }) { removeCalendarEvent(for: task) }
        notifSvc.cancelSessionEnd(taskId: id)
        update(id) { t in
            t.state = .deleted
            t.deletedDateLabel = isoFmt.string(from: Date())
            t.calendarEventId = nil
        }
        if showDetail && selectedTaskId == id { goBack() }
        swipedTaskId = nil
    }

    func restoreTask(_ id: Int) {
        update(id) { t in
            t.state = .unscheduled
            t.completedTime = nil
            t.completedDateLabel = nil
            t.deletedDateLabel = nil
        }
    }

    func unblockTask(_ id: Int) {
        notifSvc.cancelSessionEnd(taskId: id)
        notifSvc.cancelFollowUp(taskId: id)
        let isoFmt = ISO8601DateFormatter(); isoFmt.formatOptions = [.withFullDate]
        let today = Calendar.current.startOfDay(for: Date())
        update(id) { t in
            let restoreBooked: Bool = {
                guard let bd = t.bookedDate, let d = isoFmt.date(from: bd) else { return false }
                return Calendar.current.startOfDay(for: d) >= today
            }()
            if restoreBooked {
                t.state = .booked
            } else {
                t.state = .unscheduled
                t.startTime = nil
                t.endTime = nil
                t.period = nil
                t.bookedDate = nil
                t.calendarEventId = nil
            }
            t.waitingOn = nil
            t.waitingNote = nil
            t.followUpDate = nil
            t.waitingSince = nil
        }
        goBack()
    }

    func carryForward(_ id: Int) {
        if let task = tasks.first(where: { $0.id == id }) { removeCalendarEvent(for: task) }
        notifSvc.cancelSessionEnd(taskId: id)
        update(id) { t in
            t.state = .unscheduled
            t.age += 1
            t.startTime = nil
            t.endTime = nil
            t.period = nil
            t.calendarEventId = nil
            t.bookedDate = nil
        }
        dismissedLapseIds.append(id)
    }

    func dismissLapse(_ id: Int) {
        dismissedLapseIds.append(id)
    }

    func updatePriority(_ id: Int, _ p: Priority) {
        update(id) { $0.priority = p }
    }

    func updateNotes(_ id: Int, _ notes: String) {
        update(id) { $0.notes = notes }
    }

    func updateTitle(_ id: Int, _ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        update(id) { $0.title = trimmed }
    }

    func addTask() {
        let title = addForm.title.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        let isoToday = { let f = ISO8601DateFormatter(); f.formatOptions = [.withFullDate]; return f.string(from: Date()) }()
        let t = GTask(
            id: nextId,
            title: title,
            priority: addForm.priority,
            state: .unscheduled,
            age: 0,
            category: addForm.category,
            notes: addForm.notes,
            deadline: addForm.deadline.isEmpty ? nil : addForm.deadline,
            startTime: nil, endTime: nil, period: nil,
            waitingOn: nil, waitingNote: nil, followUpDate: nil,
            waitingDays: 0, completedTime: nil, completedDateLabel: nil, deletedDateLabel: nil,
            duration: addForm.duration,
            createdDate: isoToday
        )
        tasks.append(t)
        nextId += 1
        showAddTask = false
        addForm = AddForm()
        addForm.category = defaultCategory
        addForm.priority = defaultPriority
        addForm.duration = defaultDuration
        if calendarAddMode {
            calendarAddMode = false
            openBookTime(for: t.id)
        }
        save()
    }

    func moveToWaiting(_ id: Int) {
        let isoFmt = ISO8601DateFormatter(); isoFmt.formatOptions = [.withFullDate]
        let waitingOn = waitForm.name.isEmpty ? "Someone" : waitForm.name
        let followUpDateStr = waitForm.followUpDate.isEmpty ? nil : waitForm.followUpDate
        update(id) { t in
            t.state = .waiting
            t.waitingOn = waitingOn
            t.waitingNote = waitForm.note.isEmpty ? nil : waitForm.note
            t.followUpDate = followUpDateStr
            t.waitingDays = 0
            t.waitingSince = isoFmt.string(from: Date())
        }
        if let dateStr = followUpDateStr,
           let fireDate = isoFmt.date(from: dateStr),
           let task = tasks.first(where: { $0.id == id }) {
            notifSvc.scheduleFollowUp(taskId: id, title: task.title, waitingOn: waitingOn, date: fireDate)
        }
        showWaitingSheet = false
        waitForm = WaitForm()
        if showDetail && selectedTaskId == id { goBack() }
    }

    func openBookTime(for id: Int) {
        selectedTaskId = id
        let task = tasks.first(where: { $0.id == id })
        var form = BookForm(duration: task?.duration ?? defaultDuration)
        if let bd = task?.bookedDate {
            let isoFmt = ISO8601DateFormatter()
            isoFmt.formatOptions = [.withFullDate]
            isoFmt.timeZone = .current
            if let d = isoFmt.date(from: bd) {
                let today = Calendar.current.startOfDay(for: Date())
                let booked = Calendar.current.startOfDay(for: d)
                form.date = booked < today ? today : booked
            }
        }
        // Pre-fill time: existing booked time when rescheduling, else current time rounded to 15 min
        if let s = task?.startTime, let p = task?.period {
            let parts = s.split(separator: ":").compactMap { Int($0) }
            if let h = parts.first, let m = parts.dropFirst().first {
                form.period = p; form.hour = h; form.minute = m
            }
        } else {
            let cal = Calendar.current; let now = Date()
            var h = cal.component(.hour, from: now)
            var m = cal.component(.minute, from: now)
            let rem = m % 15; if rem > 0 { m += (15 - rem) }
            if m >= 60 { h += 1; m = 0 }; h = min(h, 23)
            form.period = h >= 12 ? "PM" : "AM"
            form.hour = h % 12 == 0 ? 12 : h % 12
            form.minute = m
        }
        bookForm = form
        showBookTime = true
    }

    func bookTask(_ id: Int) {
        let mins = ["15m": 15, "30m": 30, "45m": 45, "1h": 60, "2h": 120][bookForm.duration] ?? 60
        var h24 = bookForm.hour
        if bookForm.period == "PM" && h24 != 12 { h24 += 12 }
        if bookForm.period == "AM" && h24 == 12 { h24 = 0 }
        let startTotal = h24 * 60 + bookForm.minute
        let endTotal = startTotal + mins
        let eh24 = (endTotal / 60) % 24
        let em = endTotal % 60
        let endH12 = eh24 == 0 ? 12 : (eh24 > 12 ? eh24 - 12 : eh24)
        let start = "\(bookForm.hour):\(String(format: "%02d", bookForm.minute))"
        let end = "\(endH12):\(String(format: "%02d", em))"

        // Remove old calendar event if rescheduling
        if let existing = tasks.first(where: { $0.id == id }) {
            removeCalendarEvent(for: existing)
        }
        let cal = Calendar.current
        let startDate = cal.date(bySettingHour: h24, minute: bookForm.minute, second: 0,
                                 of: bookForm.date) ?? bookForm.date
        let isoFmt = ISO8601DateFormatter(); isoFmt.formatOptions = [.withFullDate]
        let isoDate = isoFmt.string(from: bookForm.date)

        update(id) { t in
            t.state = .booked
            t.startTime = start
            t.endTime = end
            t.period = bookForm.period
            t.duration = bookForm.duration
            t.bookedDate = isoDate
            t.calendarEventId = nil
            t.autoRolled = nil
        }

        if calSync, let task = tasks.first(where: { $0.id == id }) {
            let eventId = calendarSvc.createEvent(
                title: task.title,
                notes: task.notes,
                startDate: startDate,
                durationMins: mins
            )
            if let eventId {
                update(id) { $0.calendarEventId = eventId }
            }
        }

        showBookTime = false
        if let booked = tasks.first(where: { $0.id == id }) {
            scheduleSessionEndNotification(for: booked)
        }
        goBack()
    }

    // MARK: Category Actions
    func saveCategory() {
        let name = catForm.name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        if let editId = editingCategoryId {
            let oldName = categories.first(where: { $0.id == editId })?.name
            if let i = categories.firstIndex(where: { $0.id == editId }) {
                categories[i].name = name
                categories[i].color = catForm.color
            }
            if let old = oldName, old != name {
                for i in tasks.indices where tasks[i].category == old {
                    tasks[i].category = name
                }
                if defaultCategory == old { defaultCategory = name }
            }
        } else {
            categories.append(GCategory(id: nextCatId, name: name, color: catForm.color))
            nextCatId += 1
        }
        showCategorySheet = false
        catForm = CatForm()
        editingCategoryId = nil
        save()
    }

    func deleteCategory(_ id: Int) {
        let catName = categories.first(where: { $0.id == id })?.name
        categories.removeAll(where: { $0.id == id })
        if let n = catName {
            for i in tasks.indices where tasks[i].category == n { tasks[i].category = "" }
            if defaultCategory == n { defaultCategory = "" }
        }
        showCategorySheet = false
        catForm = CatForm()
        editingCategoryId = nil
        save()
    }

    // MARK: Calendar Sync Helpers

    var gigiCalendarName: String { calendarSvc.gigiCalendarName }

    var externalConflictingEvent: EKEvent? {
        guard calSync else { return nil }
        let mins = ["15m": 15, "30m": 30, "45m": 45, "1h": 60, "2h": 120][bookForm.duration] ?? 60
        var h = bookForm.hour
        if bookForm.period == "PM" && h != 12 { h += 12 }
        if bookForm.period == "AM" && h == 12 { h = 0 }
        guard let start = Calendar.current.date(
            bySettingHour: h, minute: bookForm.minute, second: 0, of: bookForm.date
        ) else { return nil }
        let end = start.addingTimeInterval(Double(mins) * 60)
        return calendarSvc.externalEventsConflicting(start: start, end: end).first
    }

    var morningTimeLabel: String {
        let h = morningHour % 12 == 0 ? 12 : morningHour % 12
        let m = String(format: "%02d", morningMinute)
        let period = morningHour < 12 ? "AM" : "PM"
        return "\(h):\(m) \(period)"
    }

    func requestBadgePermissionIfNeeded() async {
        let status = await notifSvc.authorizationStatus()
        if status == .notDetermined {
            _ = await notifSvc.requestPermission()
        }
        updateBadge()
    }

    func requestCalendarAccessIfNeeded() {
        guard calSync else { return }
        Task {
            let granted = await calendarSvc.requestAccess()
            if !granted { await MainActor.run { calSync = false; save() } }
        }
    }

    func requestMorningNotificationIfNeeded() {
        guard morningSummary else { return }
        Task {
            let granted = await notifSvc.requestPermission()
            if !granted {
                await MainActor.run { morningSummary = false; save() }
            } else {
                await MainActor.run { scheduleMorningNotification() }
            }
        }
    }

    func scheduleMorningNotification() {
        guard morningSummary else {
            notifSvc.cancelMorningSummary()
            return
        }
        let lapsed = lapsedTasks.count
        let unsched = unscheduledTasks.count
        let followUp = waitingTasks.filter { isFollowUpDue($0) }.count
        var parts: [String] = []
        if lapsed > 0 { parts.append("\(lapsed) lapsed") }
        if unsched > 0 { parts.append("\(unsched) unscheduled") }
        if followUp > 0 { parts.append("\(followUp) follow-up\(followUp == 1 ? "" : "s")") }
        let body = parts.isEmpty ? "All clear for today!" : parts.joined(separator: " · ")
        notifSvc.scheduleMorningSummary(hour: morningHour, minute: morningMinute, body: body)
    }

    // MARK: Session End Notifications

    func scheduleSessionEndNotification(for task: GTask) {
        guard lapsedAlert,
              let bd = task.bookedDate, task.endTime != nil, task.period != nil else { return }
        let isoFmt = ISO8601DateFormatter(); isoFmt.formatOptions = [.withFullDate]
        guard let dayDate = isoFmt.date(from: bd) else { return }
        let correctedEndMins = endTimeMinutes(task)
        guard correctedEndMins > 0 else { return }
        let eh24 = correctedEndMins / 60
        let em = correctedEndMins % 60
        let cal = Calendar.current
        guard let endDate = cal.date(bySettingHour: eh24, minute: em, second: 0, of: dayDate) else { return }
        notifSvc.scheduleSessionEnd(taskId: task.id, title: task.title, endDate: endDate, badgeCount: tasksAlertCount + 1)
    }

    func cancelMorningNotification() {
        notifSvc.cancelMorningSummary()
    }

    // MARK: Weekly Stats Notification

    var weeklyTimeLabel: String {
        let h = weeklyHour % 12 == 0 ? 12 : weeklyHour % 12
        let m = String(format: "%02d", weeklyMinute)
        let period = weeklyHour < 12 ? "AM" : "PM"
        return "\(h):\(m) \(period)"
    }

    static let weekdayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    private func weeklyStatsBody() -> String {
        let isoFmt = ISO8601DateFormatter()
        isoFmt.formatOptions = [.withFullDate]
        isoFmt.timeZone = .current
        let cal = Calendar.current
        let now = Date()
        let weekAgo = cal.date(byAdding: .day, value: -7, to: now) ?? now

        let completedThisWeek = tasks.filter { task in
            guard task.state == .completed,
                  let label = task.completedDateLabel,
                  let date = isoFmt.date(from: label) else { return false }
            return date >= cal.startOfDay(for: weekAgo)
        }

        let count = completedThisWeek.count
        let pending = tasks.filter {
            $0.state == .booked || $0.state == .unscheduled || $0.state == .waiting
        }.count

        guard count > 0 else {
            let p = pending > 0 ? " \(pending) task\(pending == 1 ? "" : "s") still pending." : ""
            return "No tasks completed this week.\(p)"
        }

        let rate = String(format: "%.1f", Double(count) / 7.0)
        var body = "\(count) task\(count == 1 ? "" : "s") completed — \(rate)/day avg."

        var catCounts: [String: Int] = [:]
        for task in completedThisWeek where !task.category.isEmpty {
            catCounts[task.category, default: 0] += 1
        }
        if let top = catCounts.max(by: { $0.value < $1.value }), catCounts.count > 1 {
            body += " Top: \(top.key)."
        }
        if pending > 0 {
            body += " \(pending) still pending."
        }
        return body
    }

    func scheduleWeeklyStatsNotification() {
        guard weeklyStats else {
            notifSvc.cancelWeeklySummary()
            return
        }
        notifSvc.scheduleWeeklySummary(weekday: weeklyDay, hour: weeklyHour, minute: weeklyMinute, body: weeklyStatsBody())
    }

    func requestWeeklyStatsNotificationIfNeeded() {
        guard weeklyStats else { return }
        Task {
            let granted = await notifSvc.requestPermission()
            if !granted {
                await MainActor.run { weeklyStats = false; save() }
            } else {
                await MainActor.run { scheduleWeeklyStatsNotification() }
            }
        }
    }

    func cancelWeeklyStatsNotification() {
        notifSvc.cancelWeeklySummary()
    }

    private func removeCalendarEvent(for task: GTask) {
        guard let eid = task.calendarEventId else { return }
        calendarSvc.deleteEvent(id: eid)
    }

    // MARK: Conflict Detection
    func conflictingTask(hour: Int, minute: Int, period: String, duration: String, excludeId: Int? = nil) -> GTask? {
        let mins = ["15m": 15, "30m": 30, "45m": 45, "1h": 60, "2h": 120][duration] ?? 60
        var h = hour
        if period == "PM" && h != 12 { h += 12 }
        if period == "AM" && h == 12 { h = 0 }
        let selStart = h * 60 + minute
        let selEnd = selStart + mins
        let isoFmt = ISO8601DateFormatter(); isoFmt.formatOptions = [.withFullDate]
        let targetDate = isoFmt.string(from: bookForm.date)
        return tasks.first { t in
            guard t.state == .booked, t.id != excludeId else { return false }
            let taskDate = t.bookedDate ?? isoFmt.string(from: Date())
            if taskDate != targetDate { return false }
            let es = timeToMinutes(t.startTime, t.period)
            let ee = endTimeMinutes(t)
            return selStart < ee && selEnd > es
        }
    }

    // MARK: Sample Data
    static let sampleTasks: [GTask] = [
        GTask(id:1,title:"Prepare Q3 Report",priority:.high,state:.unscheduled,age:3,category:"Work",notes:"",deadline:nil,startTime:nil,endTime:nil,period:nil,waitingOn:nil,waitingNote:nil,followUpDate:nil,waitingDays:0,completedTime:nil,completedDateLabel:nil,deletedDateLabel:nil,duration:"1h",createdDate:nil),
        GTask(id:2,title:"Team Standup Prep",priority:.medium,state:.booked,age:0,category:"Meetings",notes:"Review blockers and progress updates",deadline:nil,startTime:"9:00",endTime:"9:30",period:"AM",waitingOn:nil,waitingNote:nil,followUpDate:nil,waitingDays:0,completedTime:nil,completedDateLabel:nil,deletedDateLabel:nil,duration:"30m",createdDate:nil),
        GTask(id:3,title:"Review Design Mockups",priority:.medium,state:.unscheduled,age:1,category:"Design",notes:"",deadline:nil,startTime:nil,endTime:nil,period:nil,waitingOn:nil,waitingNote:nil,followUpDate:nil,waitingDays:0,completedTime:nil,completedDateLabel:nil,deletedDateLabel:nil,duration:"30m",createdDate:nil),
        GTask(id:4,title:"Update Client Proposal",priority:.high,state:.unscheduled,age:0,category:"Client",notes:"Focus on the pricing section",deadline:"2026-08-29",startTime:nil,endTime:nil,period:nil,waitingOn:nil,waitingNote:nil,followUpDate:nil,waitingDays:0,completedTime:nil,completedDateLabel:nil,deletedDateLabel:nil,duration:"1h",createdDate:nil),
        GTask(id:5,title:"Code Review PR #42",priority:.low,state:.booked,age:0,category:"Dev",notes:"",deadline:nil,startTime:"2:00",endTime:"3:00",period:"PM",waitingOn:nil,waitingNote:nil,followUpDate:nil,waitingDays:0,completedTime:nil,completedDateLabel:nil,deletedDateLabel:nil,duration:"1h",createdDate:nil),
        GTask(id:6,title:"Follow up with Sarah",priority:.high,state:.waiting,age:0,category:"Client",notes:"",deadline:nil,startTime:nil,endTime:nil,period:nil,waitingOn:"Sarah",waitingNote:"Contract approval",followUpDate:"2026-08-28",waitingDays:2,completedTime:nil,completedDateLabel:nil,deletedDateLabel:nil,duration:"30m",createdDate:nil),
        GTask(id:7,title:"Get vendor quote",priority:.medium,state:.waiting,age:0,category:"Work",notes:"",deadline:nil,startTime:nil,endTime:nil,period:nil,waitingOn:"Vendor Co.",waitingNote:"Q4 pricing sheet",followUpDate:nil,waitingDays:5,completedTime:nil,completedDateLabel:nil,deletedDateLabel:nil,duration:"15m",createdDate:nil),
        GTask(id:8,title:"Fix login bug",priority:.high,state:.completed,age:0,category:"Dev",notes:"",deadline:nil,startTime:nil,endTime:nil,period:nil,waitingOn:nil,waitingNote:nil,followUpDate:nil,waitingDays:0,completedTime:"10:30 AM",completedDateLabel:"Today",deletedDateLabel:nil,duration:"1h",createdDate:nil),
        GTask(id:9,title:"Update documentation",priority:.medium,state:.completed,age:1,category:"Dev",notes:"",deadline:nil,startTime:nil,endTime:nil,period:nil,waitingOn:nil,waitingNote:nil,followUpDate:nil,waitingDays:0,completedTime:"3:15 PM",completedDateLabel:"Yesterday",deletedDateLabel:nil,duration:"30m",createdDate:nil),
        GTask(id:10,title:"Write blog post draft",priority:.low,state:.deleted,age:2,category:"Marketing",notes:"",deadline:nil,startTime:nil,endTime:nil,period:nil,waitingOn:nil,waitingNote:nil,followUpDate:nil,waitingDays:0,completedTime:nil,completedDateLabel:nil,deletedDateLabel:"Yesterday",duration:"2h",createdDate:nil),
    ]

    static let sampleCategories: [GCategory] = [
        GCategory(id:1,name:"Work",color:"#3D5AFE"),
        GCategory(id:2,name:"Design",color:"#4CAF50"),
        GCategory(id:3,name:"Dev",color:"#FF9800"),
        GCategory(id:4,name:"Meetings",color:"#FF6B9D"),
        GCategory(id:5,name:"Client",color:"#9C27B0"),
    ]
}
