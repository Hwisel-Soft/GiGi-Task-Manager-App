import SwiftUI

struct CalendarView: View {
    @Environment(AppStore.self) var store
    private var C: GColors { store.C }

    private var weekDays: [(abbr: String, date: Int)] {
        let cal = Calendar.current
        let today = Date()
        let weekday = cal.component(.weekday, from: today) - 1
        let startOfWeek = cal.date(byAdding: .day, value: -weekday, to: today)!
        return (0..<7).map { offset in
            let d = cal.date(byAdding: .day, value: offset, to: startOfWeek)!
            let dayNum = cal.component(.day, from: d)
            let abbr = DateFormatter().shortWeekdaySymbols[offset]
            return (abbr, dayNum)
        }
    }

    private var monthLabel: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        return f.string(from: Date())
    }

    private var weekRangeLabel: String {
        let cal = Calendar.current
        let today = Date()
        let weekday = cal.component(.weekday, from: today) - 1
        let sun = cal.date(byAdding: .day, value: -weekday, to: today)!
        let sat = cal.date(byAdding: .day, value: 6 - weekday, to: today)!
        let f = DateFormatter(); f.dateFormat = "MMM d"
        return "\(f.string(from: sun)) – \(f.string(from: sat))"
    }

    private var selectedDayISO: String {
        let cal = Calendar.current
        let today = Date()
        let weekday = cal.component(.weekday, from: today) - 1
        let startOfWeek = cal.date(byAdding: .day, value: -weekday, to: cal.startOfDay(for: today))!
        let d = cal.date(byAdding: .day, value: store.calSelDay, to: startOfWeek)!
        let f = ISO8601DateFormatter(); f.formatOptions = [.withFullDate]
        return f.string(from: d)
    }

    private var tasksForSelectedDay: [GTask] {
        let dateStr = selectedDayISO
        return store.scheduledTasks.filter { t in
            if let bd = t.bookedDate { return bd == dateStr }
            let isoFmt = ISO8601DateFormatter(); isoFmt.formatOptions = [.withFullDate]
            return dateStr == isoFmt.string(from: Date())
        }
    }

    private var totalPlannedForSelectedDay: Int {
        let dateStr = selectedDayISO
        let booked = tasksForSelectedDay.count
        let completed = store.completedTasks.filter { $0.bookedDate == dateStr }.count
        return booked + completed
    }

    private var colorfulBgs: [Color] {
        [C.card, C.primaryLight, C.pinkLight, C.greenLight, C.medLight, C.purpleLight]
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(monthLabel)
                        .font(.footnote)
                        .foregroundColor(C.muted)
                    HStack {
                        Text(weekRangeLabel)
                            .font(.title.weight(.heavy))
                            .foregroundColor(C.text)
                            .tracking(-0.5)
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(C.pinkLight)
                                .frame(width: 40, height: 40)
                            Image(systemName: "calendar")
                                .font(.callout)
                                .foregroundColor(C.pink)
                        }
                    }

                    // Week strip
                    HStack(spacing: 0) {
                        ForEach(Array(weekDays.enumerated()), id: \.offset) { i, day in
                            Button { store.calSelDay = i } label: {
                                VStack(spacing: 4) {
                                    Text(String(day.abbr.prefix(1)).uppercased())
                                        .font(.caption2.weight(.semibold))
                                        .foregroundColor(.white.opacity(0.7))
                                    ZStack {
                                        if store.calSelDay == i {
                                            Circle().fill(Color.white).frame(width: 32, height: 32)
                                        }
                                        Text("\(day.date)")
                                            .font(.callout.bold())
                                            .foregroundColor(store.calSelDay == i ? C.primary : .white)
                                    }
                                    .frame(width: 32, height: 32)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                    .background(
                        LinearGradient(colors: [C.primary, Color(hex: "#5B73FF")],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.top, 8)
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 16)
                .background(C.card)

                // Motivational line
                Text(motivationalText)
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(C.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(C.bg)

                // Task list for selected day
                ScrollView {
                    if tasksForSelectedDay.isEmpty {
                        VStack(spacing: 12) {
                            Text(dayEmoji).font(.system(size: 48))
                            Text(dayEmptyTitle)
                                .font(.headline.bold())
                                .foregroundColor(C.text)
                            Text("Tap + to schedule something.")
                                .font(.callout)
                                .foregroundColor(C.muted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(Array(tasksForSelectedDay.enumerated()), id: \.element.id) { idx, task in
                                calTaskCard(task, bgIndex: idx % colorfulBgs.count)
                                    .onTapGesture { store.openTask(task.id) }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                    }
                }
                .padding(.bottom, store.calDrawerOpen ? 340 : 80)
            }
            .background(C.bg)
            .navigationBarHidden(true)
            .onAppear {
                store.calSelDay = Calendar.current.component(.weekday, from: Date()) - 1
            }

            // Unscheduled Drawer
            UnscheduledDrawer()

            // FAB
            Button {
                store.calendarAddMode = true
                store.showAddTask = true
            } label: {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [C.primary, C.primaryDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 58, height: 58)
                        .shadow(color: C.primary.opacity(0.4), radius: 12, x: 0, y: 6)
                    Text("+")
                        .font(.title.weight(.light))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.bottom, store.calDrawerOpen ? 356 : 96)
            .padding(.trailing, 20)
        }
    }

    @ViewBuilder
    func calTaskCard(_ task: GTask, bgIndex: Int) -> some View {
        let bg = store.colorfulCards ? colorfulBgs[bgIndex] : C.card
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(C.priorityColor(task.priority).opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: "clock")
                    .font(.body)
                    .foregroundColor(C.priorityColor(task.priority))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.subheadline.bold())
                    .foregroundColor(C.text)
                    .lineLimit(1)
                if let s = task.startTime, let e = task.endTime, let p = task.period {
                    Text("\(s) – \(e) \(p)")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(C.muted)
                }
            }
            Spacer()
        }
        .padding(14)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    var motivationalText: String {
        let count = totalPlannedForSelectedDay
        let day = store.calSelDay // 0=Sun … 6=Sat
        let bucket = min(count, 3) // 0, 1, 2, 3+
        let table: [[String]] = [
            // Sun
            ["Rest up — the week starts fresh tomorrow.",
             "One task on Sunday? Respect.",
             "Getting ahead of the week.",
             "Productive Sunday incoming."],
            // Mon
            ["Clean slate to start the week.",
             "Kicking off Monday strong.",
             "Two tasks — solid Monday.",
             "Big Monday energy."],
            // Tue
            ["Tuesday: momentum day.",
             "One thing done is one thing won.",
             "Tuesday is underrated. Own it.",
             "Full Tuesday. Let's go."],
            // Wed
            ["Midweek check-in. You've got this.",
             "Halfway through. One task to show for it.",
             "Midweek and moving.",
             "Hump day, heavy load. You can do it."],
            // Thu
            ["Almost to the finish line.",
             "One more push before Friday.",
             "Strong finish to the week.",
             "Thursday sprint. Make it count."],
            // Fri
            ["Wrap it up and head into the weekend.",
             "One task to close out the week.",
             "Friday mode: focused.",
             "Crush Friday. Weekend earned."],
            // Sat
            ["Weekend — no pressure.",
             "Saturday task? You're dedicated.",
             "Weekend warrior.",
             "Full Saturday. Take breaks."],
        ]
        return table[day][bucket]
    }

    var dayEmoji: String {
        ["☀️", "🌙", "⚡", "🎯", "🌈", "🔥", "✨"][store.calSelDay % 7]
    }

    var dayEmptyTitle: String {
        ["Clean slate!", "Wide open.", "Free as a bird.", "Nothing yet.", "All yours.", "Empty canvas.", "Open schedule."][store.calSelDay % 7]
    }
}

// MARK: - Unscheduled Drawer

struct UnscheduledDrawer: View {
    @Environment(AppStore.self) var store
    private var C: GColors { store.C }

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            HStack {
                Capsule()
                    .fill(C.border)
                    .frame(width: 36, height: 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(.spring()) { store.calDrawerOpen.toggle() } }

            if store.calDrawerOpen {
                // Header
                HStack {
                    Text("Unscheduled")
                        .font(.callout.weight(.heavy))
                        .foregroundColor(C.text)
                    ZStack {
                        Circle().fill(C.primary).frame(width: 22, height: 22)
                        Text("\(store.unscheduledTasks.count)")
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Button { withAnimation(.spring()) { store.calDrawerOpen = false } } label: {
                        Image(systemName: "chevron.down")
                            .font(.callout.weight(.semibold))
                            .foregroundColor(C.muted)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

                // Task rows
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(store.unscheduledTasks) { task in
                            HStack {
                                Circle()
                                    .fill(C.priorityColor(task.priority))
                                    .frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(task.title)
                                        .font(.callout.weight(.semibold))
                                        .foregroundColor(C.text)
                                        .lineLimit(1)
                                    HStack(spacing: 6) {
                                        Text(task.priority.label)
                                            .font(.caption2)
                                            .foregroundColor(C.priorityColor(task.priority))
                                        if task.age > 0 {
                                            Text("\(task.age)d")
                                                .font(.caption2)
                                                .foregroundColor(C.muted)
                                        }
                                    }
                                }
                                Spacer()
                                Button {
                                    store.calendarAddMode = false
                                    store.openBookTime(for: task.id)
                                } label: {
                                    Text("Schedule")
                                        .font(.caption.weight(.heavy))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(C.primary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 6)
                        }
                    }
                }
                .frame(maxHeight: 240)
            } else {
                // Collapsed strip
                HStack(spacing: 8) {
                    ZStack {
                        Circle().fill(C.primary).frame(width: 22, height: 22)
                        Text("\(store.unscheduledTasks.count)")
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                    }
                    Text("Unscheduled · tap to schedule")
                        .font(.footnote.weight(.medium))
                        .foregroundColor(C.text)
                    Spacer()
                    Image(systemName: "chevron.up")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(C.muted)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 14)
                .contentShape(Rectangle())
                .onTapGesture { withAnimation(.spring()) { store.calDrawerOpen = true } }
            }
        }
        .background(C.card)
        .clipShape(RoundedRectangle(cornerRadius: store.calDrawerOpen ? 20 : 16, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: -8)
    }
}
