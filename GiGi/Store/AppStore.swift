import Foundation
import Observation
import SwiftUI
import EventKit

// MARK: - Supporting Types

enum AppTab: String, Hashable {
    case tasks, calendar, history, settings
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
    var colorfulCards: Bool
    var calSync: Bool
    var defaultDuration: String
    var defaultPriority: Priority

    // MARK: Navigation
    var selectedTab: AppTab = .tasks
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

    // MARK: Lapsed
    var dismissedLapseIds: [Int] = []

    // MARK: Colors
    var C: GColors { darkMode ? .dark : .light }

    // MARK: Init
    init() {
        let ud = UserDefaults.standard
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
        colorfulCards = ud.object(forKey: "gigi.colorfulCards") as? Bool ?? true
        calSync = ud.object(forKey: "gigi.calSync") as? Bool ?? true
        defaultDuration = ud.string(forKey: "gigi.defaultDuration") ?? "30m"
        defaultPriority = Priority(rawValue: ud.string(forKey: "gigi.defaultPriority") ?? "") ?? .medium
        nextId = max(11, ud.integer(forKey: "gigi.nextId"))
        nextCatId = max(6, ud.integer(forKey: "gigi.nextCatId"))
        calSelDay = Calendar.current.component(.weekday, from: Date()) - 1
    }

    // MARK: Persistence
    func save() {
        let ud = UserDefaults.standard
        let encoder = JSONEncoder()
        if let d = try? encoder.encode(tasks) { ud.set(d, forKey: "gigi.tasks") }
        if let d = try? encoder.encode(categories) { ud.set(d, forKey: "gigi.categories") }
        ud.set(darkMode, forKey: "gigi.darkMode")
        ud.set(lapsedAlert, forKey: "gigi.lapsedAlert")
        ud.set(morningSummary, forKey: "gigi.morningSummary")
        ud.set(morningHour, forKey: "gigi.morningHour")
        ud.set(morningMinute, forKey: "gigi.morningMinute")
        ud.set(colorfulCards, forKey: "gigi.colorfulCards")
        ud.set(calSync, forKey: "gigi.calSync")
        ud.set(defaultDuration, forKey: "gigi.defaultDuration")
        ud.set(defaultPriority.rawValue, forKey: "gigi.defaultPriority")
        ud.set(nextId, forKey: "gigi.nextId")
        ud.set(nextCatId, forKey: "gigi.nextCatId")
        updateBadge()
    }

    func updateBadge() {
        notifSvc.setBadge(tasksAlertCount)
    }

    func reloadTasksFromUserDefaults() {
        let ud = UserDefaults.standard
        guard let d = ud.data(forKey: "gigi.tasks"),
              let decoded = try? JSONDecoder().decode([GTask].self, from: d) else { return }
        tasks = decoded
        nextId = max(nextId, ud.integer(forKey: "gigi.nextId"))
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
                  let end = t.endTime, let p = t.period else { return false }
            if let bd = t.bookedDate, bd != todayStr { return false }
            return nowMins > timeToMinutes(end, p)
        }
    }

    var waitingTasks: [GTask] { tasks.filter { $0.state == .waiting } }
    var hasOverdueWaiting: Bool { waitingTasks.contains { isFollowUpDue($0) } }
    var scheduledTasks: [GTask] {
        tasks.filter { $0.state == .booked }
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
        let f = ISO8601DateFormatter(); f.formatOptions = [.withFullDate]
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
        guard let end = task.endTime, let p = task.period else { return false }
        return nowMins > timeToMinutes(end, p)
    }

    var tasksAlertCount: Int {
        let lapsed = tasks.filter { isLapsed($0) }.count
        let overdueWaiting = waitingTasks.filter { isFollowUpDue($0) }.count
        return lapsed + overdueWaiting
    }

    func timeToMinutes(_ time: String?, _ period: String?) -> Int {
        guard let t = time else { return 0 }
        let p = t.split(separator: ":").compactMap { Int($0) }
        var h = p.first ?? 0; let m = p.dropFirst().first ?? 0
        if period == "PM" && h != 12 { h += 12 }
        if period == "AM" && h == 12 { h = 0 }
        return h * 60 + m
    }

    func categoryColor(_ name: String) -> Color {
        Color(hex: categories.first(where: { $0.name == name })?.color ?? "#9494AA")
    }

    func selectedTask() -> GTask? {
        guard let id = selectedTaskId else { return nil }
        return tasks.first(where: { $0.id == id })
    }

    func bookedTasksOnDay(_ offset: Int) -> [GTask] {
        scheduledTasks
    }

    // MARK: Mutation Helper
    private func update(_ id: Int, _ fn: (inout GTask) -> Void) {
        guard let i = tasks.firstIndex(where: { $0.id == id }) else { return }
        fn(&tasks[i])
        save()
    }

    // MARK: Navigation
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
        let fmt = DateFormatter(); fmt.timeStyle = .short
        let now = fmt.string(from: Date())
        if let task = tasks.first(where: { $0.id == id }) { removeCalendarEvent(for: task) }
        update(id) { t in
            t.state = .completed
            t.completedTime = now
            t.completedDateLabel = "Today"
            t.calendarEventId = nil
        }
        if showDetail && selectedTaskId == id { goBack() }
        swipedTaskId = nil
        dismissedLapseIds.append(id)
    }

    func deleteTask(_ id: Int) {
        if let task = tasks.first(where: { $0.id == id }) { removeCalendarEvent(for: task) }
        update(id) { t in
            t.state = .deleted
            t.deletedDateLabel = "Today"
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
        update(id) { t in
            t.state = .unscheduled
            t.waitingOn = nil
            t.waitingNote = nil
            t.followUpDate = nil
        }
        goBack()
    }

    func carryForward(_ id: Int) {
        if let task = tasks.first(where: { $0.id == id }) { removeCalendarEvent(for: task) }
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
        if calendarAddMode {
            calendarAddMode = false
            openBookTime(for: t.id)
        }
        save()
    }

    func moveToWaiting(_ id: Int) {
        update(id) { t in
            t.state = .waiting
            t.waitingOn = waitForm.name.isEmpty ? "Someone" : waitForm.name
            t.waitingNote = waitForm.note.isEmpty ? nil : waitForm.note
            t.followUpDate = waitForm.followUpDate.isEmpty ? nil : waitForm.followUpDate
            t.waitingDays = 0
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
            let isoFmt = ISO8601DateFormatter(); isoFmt.formatOptions = [.withFullDate]
            if let d = isoFmt.date(from: bd) {
                form.date = Calendar.current.startOfDay(for: d)
            }
        }
        bookForm = form
        showBookTime = true
    }

    func bookTask(_ id: Int) {
        let mins = ["15m": 15, "30m": 30, "45m": 45, "1h": 60, "2h": 120][bookForm.duration] ?? 60
        let h = bookForm.hour, m = bookForm.minute
        var eh = h + mins / 60, em = m + mins % 60
        if em >= 60 { eh += 1; em -= 60 }
        let start = "\(h):\(String(format: "%02d", m))"
        let end = "\(eh):\(String(format: "%02d", em))"

        // Remove old calendar event if rescheduling
        if let existing = tasks.first(where: { $0.id == id }) {
            removeCalendarEvent(for: existing)
        }

        var h24 = bookForm.hour
        if bookForm.period == "PM" && h24 != 12 { h24 += 12 }
        if bookForm.period == "AM" && h24 == 12 { h24 = 0 }
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
        }
        showCategorySheet = false
        catForm = CatForm()
        editingCategoryId = nil
        save()
    }

    // MARK: Calendar Sync Helpers

    var defaultCalendarName: String { calendarSvc.defaultCalendarName }

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
        let sched = todaysScheduledTasks.count
        let unsched = unscheduledTasks.count
        let followUp = waitingTasks.filter { isFollowUpDue($0) }.count
        var parts: [String] = []
        if sched > 0 { parts.append("\(sched) scheduled") }
        if unsched > 0 { parts.append("\(unsched) unscheduled") }
        if followUp > 0 { parts.append("\(followUp) follow-up\(followUp == 1 ? "" : "s")") }
        let body = parts.isEmpty ? "All clear for today!" : parts.joined(separator: " · ")
        notifSvc.scheduleMorningSummary(hour: morningHour, minute: morningMinute, body: body)
    }

    func cancelMorningNotification() {
        notifSvc.cancelMorningSummary()
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
            if let bd = t.bookedDate, bd != targetDate { return false }
            let es = timeToMinutes(t.startTime, t.period)
            let ee = timeToMinutes(t.endTime, t.period)
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
