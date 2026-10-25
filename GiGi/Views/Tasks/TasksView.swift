import SwiftUI

enum TaskFilter: String, CaseIterable {
    case all = "All"
    case lapsed = "Lapsed"
    case scheduled = "Scheduled"
    case unscheduled = "Unscheduled"
    case waiting = "Waiting"
}

struct TasksView: View {
    @Environment(AppStore.self) var store
    private var C: GColors { store.C }

    @State private var filter: TaskFilter = .all
    @State private var sort: TaskSort = .priority
    @State private var showSortSheet = false
    @State private var lapsedExpanded = true
    @State private var scheduledExpanded = true
    @State private var unscheduledExpanded = true
    @State private var waitingExpanded = true

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                HStack {
                    Text("Tasks")
                        .font(.title.weight(.heavy))
                        .foregroundColor(C.text)
                        .tracking(-1)
                    Spacer()
                    Button { showSortSheet = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.caption.weight(.semibold))
                            Text(sort.rawValue)
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundColor(C.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(C.primaryLight)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 12)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(TaskFilter.allCases, id: \.self) { f in
                            filterChip(f)
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 12)

                Divider().background(C.border)

                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        lapsedSection
                        needsAttentionSection
                        if filter == .all {
                            allSections
                        } else {
                            let rows = filteredSortedTasks
                            ForEach(rows) { task in
                                TaskCardView(task: task, showStateBadge: true)
                            }
                            if rows.isEmpty { emptyState }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 120)
                }
                .scrollIndicators(.visible)
            }
            .background(C.bg)
            .hideNavigationBar()
            .onAppear { sort = store.defaultTaskSort }

            Button { store.openAddTask() } label: {
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
            .padding(.bottom, 16)
            .padding(.trailing, 20)
        }
        .sheet(isPresented: $showSortSheet) { sortSheet }
    }

    @ViewBuilder
    var allSections: some View {
        let scheduled = applySorting(store.scheduledTasks)
        let unscheduled = applySorting(store.unscheduledTasks)
        let waiting = applySorting(store.waitingTasks.filter { !store.isFollowUpDue($0) })
        if !scheduled.isEmpty {
            sectionHeader("SCHEDULED", count: scheduled.count, expanded: $scheduledExpanded)
            if scheduledExpanded {
                ForEach(scheduled) { TaskCardView(task: $0, showStateBadge: true) }
            }
        }
        if !waiting.isEmpty {
            sectionHeader("WAITING", count: waiting.count, expanded: $waitingExpanded)
            if waitingExpanded {
                ForEach(waiting) { TaskCardView(task: $0, showStateBadge: true) }
            }
        }
        if !unscheduled.isEmpty {
            sectionHeader("UNSCHEDULED", count: unscheduled.count, expanded: $unscheduledExpanded)
            if unscheduledExpanded {
                ForEach(unscheduled) { TaskCardView(task: $0, showStateBadge: true) }
            }
        }
        if scheduled.isEmpty && unscheduled.isEmpty && store.waitingTasks.isEmpty { emptyState }
    }

    @ViewBuilder
    var lapsedSection: some View {
        let lapsed = store.lapsedTasks
        if !lapsed.isEmpty {
            lapsedSectionHeader(count: lapsed.count, expanded: $lapsedExpanded)
            if lapsedExpanded {
                ForEach(lapsed) { TaskCardView(task: $0, showStateBadge: true) }
            }
            Divider().background(C.border).padding(.top, 4)
        }
    }

    var filteredSortedTasks: [GTask] {
        let base: [GTask]
        switch filter {
        case .all:
            base = store.tasks.filter { $0.state == .booked || $0.state == .unscheduled || $0.state == .waiting }
        case .lapsed: base = store.lapsedTasks
        case .scheduled: base = store.scheduledTasks
        case .unscheduled: base = store.unscheduledTasks
        case .waiting: base = store.waitingTasks
        }
        return applySorting(base)
    }

    func applySorting(_ tasks: [GTask]) -> [GTask] {
        let pOrd: [Priority: Int] = [.high: 0, .medium: 1, .low: 2]
        return tasks.sorted { a, b in
            switch sort {
            case .priority:
                return (pOrd[a.priority] ?? 1) < (pOrd[b.priority] ?? 1)
            case .dueTime:
                let aHas = a.startTime != nil, bHas = b.startTime != nil
                if aHas != bHas { return aHas }
                if aHas { return store.timeToMinutes(a.startTime, a.period) < store.timeToMinutes(b.startTime, b.period) }
                return (pOrd[a.priority] ?? 1) < (pOrd[b.priority] ?? 1)
            case .scheduledDate:
                let aHas = a.bookedDate != nil, bHas = b.bookedDate != nil
                if aHas != bHas { return aHas }
                if aHas { return (a.bookedDate ?? "") < (b.bookedDate ?? "") }
                return (pOrd[a.priority] ?? 1) < (pOrd[b.priority] ?? 1)
            case .dateAdded:
                return (a.createdDate ?? "9999-99-99") < (b.createdDate ?? "9999-99-99")
            }
        }
    }

    @ViewBuilder
    func filterChip(_ f: TaskFilter) -> some View {
        Button { filter = f } label: {
            Text(f.rawValue)
                .font(.footnote.weight(.semibold))
                .foregroundColor(filter == f ? .white : C.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(filter == f ? C.primary : C.card)
                .overlay(Capsule().stroke(filter == f ? C.primary : C.border, lineWidth: 1.5))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    func sectionHeader(_ title: String, count: Int, expanded: Binding<Bool>) -> some View {
        let isExpanded = expanded.wrappedValue
        Button {
            withAnimation(.spring(duration: 0.25)) { expanded.wrappedValue.toggle() }
        } label: {
            HStack(spacing: 4) {
                Text("\(title) (\(count))")
                    .font(.caption2.bold())
                    .foregroundColor(isExpanded ? C.muted : C.sub)
                    .tracking(0.8)
                Spacer()
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(isExpanded ? C.muted : C.sub)
            }
            .frame(minHeight: 44)
            .padding(.vertical, isExpanded ? 4 : 12)
            .padding(.horizontal, isExpanded ? 0 : 14)
            .background {
                if !isExpanded {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(C.card)
                        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    var emptyState: some View {
        VStack(spacing: 12) {
            Text("✨").font(.system(size: 48))
            Text("All clear!")
                .font(.headline.bold())
                .foregroundColor(C.text)
            Text("Tap + to add your first task")
                .font(.callout)
                .foregroundColor(C.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    @ViewBuilder
    var needsAttentionSection: some View {
        let alertTasks = store.tasks.filter {
            $0.state == .waiting && store.isFollowUpDue($0)
        }
        if !alertTasks.isEmpty {
            HStack(spacing: 5) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(C.high)
                Text("FOLLOW UP DUE")
                    .font(.caption2.bold())
                    .foregroundColor(C.high)
                    .tracking(0.8)
                Spacer()
                Text("\(alertTasks.count)")
                    .font(.caption2.bold())
                    .foregroundColor(C.high)
            }
            .padding(.top, 4)
            ForEach(alertTasks) { TaskCardView(task: $0, showStateBadge: true) }
            Divider().background(C.border).padding(.top, 4)
        }
    }

    @ViewBuilder
    func lapsedSectionHeader(count: Int, expanded: Binding<Bool>) -> some View {
        let isExpanded = expanded.wrappedValue
        Button {
            withAnimation(.spring(duration: 0.25)) { expanded.wrappedValue.toggle() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundColor(.white)
                Text("LAPSED (\(count))")
                    .font(.caption2.bold())
                    .foregroundColor(.white)
                    .tracking(0.8)
                Spacer()
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(C.high)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    var sortSheet: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(C.border)
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)
            Text("SORT BY")
                .font(.caption2.bold())
                .foregroundColor(C.muted)
                .tracking(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            ForEach(TaskSort.allCases, id: \.self) { s in
                Button {
                    sort = s
                    showSortSheet = false
                } label: {
                    HStack {
                        Text(s.rawValue)
                            .font(.callout)
                            .foregroundColor(C.text)
                        Spacer()
                        if sort == s {
                            Image(systemName: "checkmark")
                                .font(.callout.weight(.semibold))
                                .foregroundColor(C.primary)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                }
                .buttonStyle(.plain)
                Divider().background(C.border).padding(.horizontal, 24)
            }
            Spacer()
        }
        .background(C.card)
        .presentationDetents([.fraction(0.35)])
        .presentationDragIndicator(.hidden)
        .presentationBackground(C.card)
    }
}
