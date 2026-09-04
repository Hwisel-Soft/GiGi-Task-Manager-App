import SwiftUI

struct HistoryView: View {
    @Environment(AppStore.self) var store
    private var C: GColors { store.C }

    var body: some View {
        @Bindable var store = store
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 12) {
                Text("History")
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundColor(C.text)
                    .tracking(-1)

                // Sub-tab picker
                HStack(spacing: 0) {
                    ForEach(HistorySubTab.allCases, id: \.self) { tab in
                        Button { store.historySubTab = tab } label: {
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(store.historySubTab == tab ? C.primary : C.muted)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(store.historySubTab == tab ? C.primaryLight : Color.clear)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .background(C.bg)
                .clipShape(Capsule())
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 16)
            .background(C.card)

            // Content
            switch store.historySubTab {
            case .completed: completedList
            case .deleted: deletedList
            case .insights: InsightsView()
            }
        }
        .background(C.bg)
        .navigationBarHidden(true)
    }

    var completedList: some View {
        ScrollView {
            if store.completedTasks.isEmpty {
                emptyState(emoji: "✅", title: "Nothing completed yet.", sub: "Mark a task done to see it here.")
            } else {
                VStack(spacing: 10) {
                    ForEach(store.completedTasks) { task in
                        historyCard(task, isCompleted: true)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
    }

    var deletedList: some View {
        ScrollView {
            if store.deletedTasks.isEmpty {
                emptyState(emoji: "🗑", title: "Nothing deleted.", sub: "Deleted tasks appear here.")
            } else {
                VStack(spacing: 10) {
                    ForEach(store.deletedTasks) { task in
                        historyCard(task, isCompleted: false)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
    }

    @ViewBuilder
    func historyCard(_ task: GTask, isCompleted: Bool) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(C.muted)
                    .strikethrough(isCompleted, color: C.muted)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if isCompleted, let t = task.completedTime, let d = task.completedDateLabel {
                        Text("\(d) · \(t)")
                            .font(.system(size: 12))
                            .foregroundColor(C.muted)
                    } else if let d = task.deletedDateLabel {
                        Text(d)
                            .font(.system(size: 12))
                            .foregroundColor(C.muted)
                    }
                    if !task.category.isEmpty {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(store.categoryColor(task.category))
                                .frame(width: 6, height: 6)
                            Text(task.category)
                                .font(.system(size: 11))
                                .foregroundColor(C.muted)
                        }
                    }
                }
            }
            Spacer()
            Button { store.restoreTask(task.id) } label: {
                Image(systemName: "arrowshape.turn.up.backward")
                    .font(.system(size: 14))
                    .foregroundColor(C.primary)
                    .frame(width: 36, height: 36)
                    .background(C.primaryLight)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(C.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture { store.openTask(task.id) }
    }

    @ViewBuilder
    func emptyState(emoji: String, title: String, sub: String) -> some View {
        VStack(spacing: 12) {
            Text(emoji).font(.system(size: 48))
            Text(title).font(.system(size: 17, weight: .bold)).foregroundColor(C.text)
            Text(sub).font(.system(size: 14)).foregroundColor(C.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

// MARK: - Insights View

struct InsightsView: View {
    @Environment(AppStore.self) var store
    private var C: GColors { store.C }

    private var allTasks: [GTask] {
        let all = store.tasks
        switch store.insightsPeriod {
        case .thisWeek:
            return all  // simplified: show all
        case .thisMonth, .lastMonth, .allTime:
            return all
        }
    }

    private var completed: Int { allTasks.filter { $0.state == .completed }.count }
    private var waiting: Int { allTasks.filter { $0.state == .waiting }.count }
    private var deleted: Int { allTasks.filter { $0.state == .deleted }.count }
    private var total: Int { completed + waiting + deleted + allTasks.filter { $0.state == .unscheduled || $0.state == .booked }.count }
    private var rate: Int { total > 0 ? Int(Double(completed) / Double(total) * 100) : 0 }
    private var avgDays: Int { allTasks.filter { $0.state == .completed }.reduce(0) { $0 + $1.age } / max(1, completed) }

    var body: some View {
        @Bindable var store = store
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Period picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(InsightsPeriod.allCases, id: \.self) { p in
                            Button { store.insightsPeriod = p } label: {
                                Text(p.rawValue)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(store.insightsPeriod == p ? C.primary : C.muted)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(store.insightsPeriod == p ? C.primaryLight : Color.clear)
                                    .overlay(Capsule().stroke(store.insightsPeriod == p ? C.primary : C.border, lineWidth: 1.5))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                }

                // KPI Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    kpiTile(label: "Completed", value: completed, color: C.green, bg: C.greenLight)
                    kpiTile(label: "Avg. Days", value: avgDays, color: C.primary, bg: C.primaryLight)
                    kpiTile(label: "Waiting", value: waiting, color: C.purple, bg: C.purpleLight)
                    kpiTile(label: "Deleted", value: deleted, color: C.high, bg: C.highLight)
                }
                .padding(.horizontal, 24)

                // Completion ring
                VStack(alignment: .leading, spacing: 12) {
                    Text("COMPLETION RATE")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(C.muted)
                        .tracking(0.8)

                    HStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .stroke(C.border, lineWidth: 10)
                                .frame(width: 84, height: 84)
                            Circle()
                                .trim(from: 0, to: CGFloat(rate) / 100)
                                .stroke(C.green, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                                .frame(width: 84, height: 84)
                                .rotationEffect(.degrees(-90))
                            Text("\(rate)%")
                                .font(.system(size: 16, weight: .heavy))
                                .foregroundColor(C.text)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(completed) of \(total) tasks completed")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(C.text)
                            Text("across selected period")
                                .font(.system(size: 12))
                                .foregroundColor(C.muted)
                        }
                    }
                }
                .padding(16)
                .background(C.card)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                .padding(.horizontal, 24)

                // Priority follow-through
                VStack(alignment: .leading, spacing: 12) {
                    Text("PRIORITY FOLLOW-THROUGH")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(C.muted)
                        .tracking(0.8)

                    ForEach(Priority.allCases, id: \.self) { p in
                        let pt = allTasks.filter { $0.priority == p }
                        let pc = pt.filter { $0.state == .completed }.count
                        let pd = pt.filter { $0.state == .deleted }.count
                        let pw = pt.filter { $0.state == .waiting }.count
                        let pa = pt.filter { $0.state == .unscheduled || $0.state == .booked }.count
                        let total = pt.count
                        priorityBar(p: p, completed: pc, deleted: pd, waiting: pw, active: pa, total: total)
                    }
                }
                .padding(16)
                .background(C.card)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                .padding(.horizontal, 24)
            }
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .background(C.bg)
    }

    @ViewBuilder
    func kpiTile(label: String, value: Int, color: Color, bg: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(color)
                .tracking(0.5)
            Text("\(value)")
                .font(.system(size: 28, weight: .heavy))
                .foregroundColor(C.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    func priorityBar(p: Priority, completed: Int, deleted: Int, waiting: Int, active: Int, total: Int) -> some View {
        let t = max(1, total)
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(p.label)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(C.priorityColor(p))
                Spacer()
                Text("\(completed)/\(total) done")
                    .font(.system(size: 11))
                    .foregroundColor(C.muted)
            }
            GeometryReader { geo in
                HStack(spacing: 2) {
                    segment(frac: Double(completed)/Double(t), width: geo.size.width, color: C.green)
                    segment(frac: Double(deleted)/Double(t), width: geo.size.width, color: C.high)
                    segment(frac: Double(waiting)/Double(t), width: geo.size.width, color: C.purple)
                    segment(frac: Double(active)/Double(t), width: geo.size.width, color: C.border)
                }
            }
            .frame(height: 10)
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
    }

    @ViewBuilder
    func segment(frac: Double, width: CGFloat, color: Color) -> some View {
        if frac > 0 {
            Rectangle()
                .fill(color)
                .frame(width: width * frac)
        }
    }
}
