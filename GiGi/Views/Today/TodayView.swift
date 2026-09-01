import SwiftUI

struct TodayView: View {
    @Environment(AppStore.self) var store
    private var C: GColors { store.C }

    private var dateString: String {
        let f = DateFormatter(); f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date())
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 0) {
                    // Header card
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dateString)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(C.muted)
                            Text("Today")
                                .font(.system(size: 30, weight: .heavy))
                                .foregroundColor(C.text)
                                .tracking(-1)
                        }
                        Spacer()
                        HStack(spacing: 8) {
                            if store.unscheduledTasks.count > 0 {
                                Text("\(store.unscheduledTasks.count) unscheduled")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(C.primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(C.primaryLight)
                                    .clipShape(Capsule())
                            }
                            // Avatar
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(
                                        colors: [C.primary, C.pink],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                    .frame(width: 36, height: 36)
                                Text("G")
                                    .font(.system(size: 15, weight: .heavy))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 18)
                    .padding(.bottom, 20)
                    .background(C.card)

                    // Scheduled section
                    if !store.scheduledTasks.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("SCHEDULED")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(C.muted)
                                .tracking(1)
                            ForEach(store.scheduledTasks) { task in
                                TaskCardView(task: task)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                    }

                    // Unscheduled section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("UNSCHEDULED")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(C.muted)
                            .tracking(1)

                        if store.unscheduledTasks.isEmpty {
                            VStack(spacing: 4) {
                                Text("Nothing unscheduled.")
                                    .font(.system(size: 14))
                                    .foregroundColor(C.muted)
                                Text("You're on top of it. 🎉")
                                    .font(.system(size: 14))
                                    .foregroundColor(C.muted)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 36)
                        } else {
                            ForEach(store.unscheduledTasks) { task in
                                TaskCardView(task: task)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 100)

                    // Empty state
                    if store.scheduledTasks.isEmpty && store.unscheduledTasks.isEmpty {
                        VStack(spacing: 12) {
                            Text("✨").font(.system(size: 48))
                            Text("All clear!").font(.system(size: 17, weight: .bold)).foregroundColor(C.text)
                            Text("Tap + to add your first task").font(.system(size: 14)).foregroundColor(C.muted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    }
                }
            }
            .background(C.bg)
            .navigationBarHidden(true)

            // FAB
            Button {
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
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(.white)
                }
            }
            .padding(.bottom, 16)
            .padding(.trailing, 20)
        }
    }
}
