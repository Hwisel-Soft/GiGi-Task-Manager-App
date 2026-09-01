import SwiftUI

struct LapsedSessionModal: View {
    let task: GTask
    @Environment(AppStore.self) var store
    private var C: GColors { store.C }

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack {
                Spacer()
                VStack(alignment: .leading, spacing: 0) {
                    // Drag handle
                    HStack {
                        Capsule()
                            .fill(C.border)
                            .frame(width: 36, height: 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                    // Session Ended badge
                    HStack(spacing: 8) {
                        Circle().fill(C.high).frame(width: 10, height: 10)
                        Text("SESSION ENDED")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(C.high)
                            .tracking(0.8)
                    }
                    .padding(.bottom, 6)

                    Text(task.title)
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundColor(C.text)
                        .tracking(-0.4)
                        .padding(.bottom, 4)

                    Text("Your work session just ended. Did you finish it?")
                        .font(.system(size: 13))
                        .foregroundColor(C.muted)
                        .padding(.bottom, 24)

                    VStack(spacing: 10) {
                        Button {
                            store.completeTask(task.id)
                        } label: {
                            Text("✓ Mark Complete")
                                .font(.system(size: 15, weight: .heavy))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(C.green)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: C.green.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)

                        Button {
                            store.dismissLapse(task.id)
                            store.selectedTaskId = task.id
                            store.showBookTime = true
                        } label: {
                            Text("🔄 Reschedule")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(C.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(C.primary, lineWidth: 2))
                        }
                        .buttonStyle(.plain)

                        Button { store.carryForward(task.id) } label: {
                            Text("Later — carry forward")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(C.muted)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 44)
                .background(C.card)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: -10)
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }
}
