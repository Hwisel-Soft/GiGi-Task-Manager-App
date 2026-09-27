import SwiftUI

struct TodayView: View {
    @Environment(AppStore.self) var store
    private var C: GColors { store.C }

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEEE, MMMM d"; return f
    }()
    private static let isoFmt: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withFullDate]; f.timeZone = .current; return f
    }()

    private var dateString: String { Self.dateFmt.string(from: Date()) }
    private var todayStr: String { Self.isoFmt.string(from: Date()) }

    private var completedTodayCount: Int {
        store.tasks.filter { $0.state == .completed && $0.completedDateLabel == todayStr }.count
    }
    private var totalTaskCount: Int {
        store.todaysScheduledTasks.count + store.unscheduledTasks.count + completedTodayCount
    }
    private var progressFraction: Double {
        totalTaskCount > 0 ? Double(completedTodayCount) / Double(totalTaskCount) : 0
    }
    private var remainingLabel: String {
        let r = store.todaysScheduledTasks.count + store.unscheduledTasks.count
        return r == 1 ? "1 task remaining" : "\(r) tasks remaining"
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 0) {
                    headerZone
                    taskBody
                }
            }
            .background(C.bg)
            .hideNavigationBar()

            // FAB
            Button { store.openAddTask() } label: {
                ZStack {
                    Circle()
                        .fill(C.primary)
                        .frame(width: 56, height: 56)
                        .shadow(color: C.primary.opacity(0.35), radius: 10, x: 0, y: 5)
                    Image(systemName: "plus")
                        .font(.title2.weight(.medium))
                        .foregroundColor(.white)
                }
            }
            .padding(.bottom, 16)
            .padding(.trailing, 20)
        }
    }

    // MARK: — Header zone (cobalt blue)

    private var headerZone: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Today")
                .font(.system(size: 32, weight: .heavy))
                .foregroundColor(.white)
                .tracking(-0.5)
            Text(dateString)
                .font(.footnote.weight(.medium))
                .foregroundColor(.white.opacity(0.55))

            if totalTaskCount > 0 {
                HStack(spacing: 10) {
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.18))
                            .frame(height: 2)
                        GeometryReader { g in
                            Capsule()
                                .fill(Color.white.opacity(0.75))
                                .frame(width: g.size.width * progressFraction, height: 2)
                        }
                        .frame(height: 2)
                    }
                    Text("\(completedTodayCount) / \(totalTaskCount)")
                        .font(.caption2.bold())
                        .foregroundColor(.white.opacity(0.6))
                        .monospacedDigit()
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 22)
        .background(C.primary)
    }

    // MARK: — Task body (light background)

    private var taskBody: some View {
        VStack(spacing: 0) {
            if !store.todaysScheduledTasks.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("Scheduled", count: store.todaysScheduledTasks.count)
                    ForEach(store.todaysScheduledTasks) { task in
                        TaskCardView(task: task)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
            }

            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("Unscheduled", count: store.unscheduledTasks.count)

                if store.unscheduledTasks.isEmpty {
                    VStack(spacing: 4) {
                        Text("Nothing unscheduled.")
                            .font(.callout)
                            .foregroundColor(C.muted)
                        Text("You're on top of it.")
                            .font(.callout)
                            .foregroundColor(C.muted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                } else {
                    ForEach(store.unscheduledTasks) { task in
                        TaskCardView(task: task)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 100)

            if store.todaysScheduledTasks.isEmpty && store.unscheduledTasks.isEmpty {
                VStack(spacing: 10) {
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
        }
        .background(C.bg)
    }

    @ViewBuilder
    private func sectionLabel(_ title: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Text(title.uppercased())
                .font(.caption2.bold())
                .foregroundColor(C.primary)
                .tracking(1.5)
            if count > 0 {
                Text("\(count)")
                    .font(.caption2.weight(.medium))
                    .foregroundColor(C.muted)
            }
        }
    }
}
