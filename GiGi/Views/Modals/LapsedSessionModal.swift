import SwiftUI

struct LapsedSessionModal: View {
    let task: GTask
    @Environment(AppStore.self) var store
    private var C: GColors { store.C }

    @State private var showWhyPrompt = false
    @State private var whyText = ""

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
                            .font(.caption2.bold())
                            .foregroundColor(C.high)
                            .tracking(0.8)
                    }
                    .padding(.bottom, 6)

                    Text(task.title)
                        .font(.title3.weight(.heavy))
                        .foregroundColor(C.text)
                        .tracking(-0.4)
                        .padding(.bottom, 4)

                    Text("Your work session just ended. Did you finish it?")
                        .font(.footnote)
                        .foregroundColor(C.muted)
                        .padding(.bottom, 24)

                    VStack(spacing: 10) {
                        Button {
                            store.completeTask(task.id)
                        } label: {
                            Text("✓ Mark Complete")
                                .font(.subheadline.weight(.heavy))
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
                                .font(.subheadline.bold())
                                .foregroundColor(C.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(C.primary, lineWidth: 2))
                        }
                        .buttonStyle(.plain)

                        Button {
                            if task.motivation == nil && !showWhyPrompt {
                                withAnimation(.spring(response: 0.3)) { showWhyPrompt = true }
                            } else {
                                if !whyText.isEmpty { store.updateMotivation(task.id, whyText) }
                                store.carryForward(task.id)
                            }
                        } label: {
                            Text(showWhyPrompt ? "Save & Carry Forward" : "Later — carry forward")
                                .font(.callout.weight(.semibold))
                                .foregroundColor(showWhyPrompt ? C.primary : C.muted)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)

                        if showWhyPrompt {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "lightbulb")
                                        .font(.caption)
                                        .foregroundColor(C.primary)
                                    Text("Why does this task matter?")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(C.primary)
                                }
                                TextField("Adding a reason boosts follow-through…", text: $whyText, axis: .vertical)
                                    .font(.callout)
                                    .foregroundColor(C.text)
                                    .tint(C.primary)
                                    .lineLimit(2...3)
                                    .padding(12)
                                    .background(C.bg)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(C.primary.opacity(0.4), lineWidth: 1.5))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                Button {
                                    store.carryForward(task.id)
                                } label: {
                                    Text("Skip — carry forward anyway")
                                        .font(.caption)
                                        .foregroundColor(C.muted)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.top, 4)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
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
