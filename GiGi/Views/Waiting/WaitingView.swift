import SwiftUI

struct WaitingView: View {
    @Environment(AppStore.self) var store
    private var C: GColors { store.C }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 3) {
                Text("Waiting")
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundColor(C.text)
                    .tracking(-1)
                Text("\(store.waitingTasks.count) task\(store.waitingTasks.count == 1 ? "" : "s") waiting")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(C.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 20)
            .background(C.card)

            if store.waitingTasks.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Text("🎉").font(.system(size: 48))
                    Text("No dependencies.")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(C.text)
                    Text("Nothing's blocking you.")
                        .font(.system(size: 14))
                        .foregroundColor(C.muted)
                }
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(store.waitingTasks) { task in
                            waitingCard(task)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .background(C.bg)
        .navigationBarHidden(true)
    }

    @ViewBuilder
    func waitingCard(_ task: GTask) -> some View {
        HStack(spacing: 0) {
            // Priority bar
            Rectangle()
                .fill(C.priorityColor(task.priority))
                .frame(width: 4)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 16))

            VStack(alignment: .leading, spacing: 4) {
                if store.isFollowUpDue(task) {
                    Text("⏰ FOLLOW UP TODAY")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(C.med)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .padding(.bottom, 2)
                }
                Text(task.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(C.text)
                    .lineLimit(1)
                Text("Waiting on \(task.waitingOn ?? "someone")")
                    .font(.system(size: 12))
                    .foregroundColor(C.muted)
                Text("\(task.waitingDays)d waiting")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(C.purple)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { store.openTask(task.id) }

            // Nudge button
            Button {
                store.selectedTaskId = task.id
                store.showNudgeSheet = true
            } label: {
                ZStack {
                    Circle()
                        .fill(C.purpleLight)
                        .frame(width: 36, height: 36)
                    Image(systemName: "envelope")
                        .font(.system(size: 14))
                        .foregroundColor(C.purple)
                }
            }
            .buttonStyle(.plain)
            .padding(.trailing, 14)
        }
        .background(C.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.07), radius: 5, x: 0, y: 2)
    }
}
