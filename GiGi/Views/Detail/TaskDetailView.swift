import SwiftUI

struct TaskDetailView: View {
    @Environment(AppStore.self) var store
    @Environment(\.dismiss) private var dismiss
    private var C: GColors { store.C }

    @State private var showDeleteConfirm = false

    private var task: GTask? { store.selectedTask() }

    var body: some View {
        Group {
            if let task {
                content(task)
            } else {
                Color.clear.onAppear { dismiss() }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .background(C.bg)
    }

    @ViewBuilder
    func content(_ task: GTask) -> some View {
        VStack(spacing: 0) {
            // Nav bar
            HStack {
                Button {
                    store.goBack()
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(C.primary)
                    .padding(.vertical, 10)
                    .padding(.trailing, 16)
                    .contentShape(Rectangle())
                }
                Spacer()
                stateBadge(task)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 14)
            .background(C.card)
            .overlay(Divider().foregroundColor(C.border), alignment: .bottom)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Title block
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(C.priorityColor(task.priority))
                            .frame(width: 4)
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Task title", text: Binding(
                                get: { task.title },
                                set: { store.updateTitle(task.id, $0) }
                            ))
                            .font(.system(size: 24, weight: .heavy))
                            .foregroundColor(C.text)
                            .tracking(-0.5)
                            .tint(C.primary)
                            HStack(spacing: 10) {
                                if let cd = task.createdDate {
                                    Text("Added \(formattedCreatedDate(cd))")
                                        .font(.system(size: 12))
                                        .foregroundColor(C.muted)
                                }
                                if task.age > 0 {
                                    Text("· Carried \(task.age)d")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(C.med)
                                }
                            }
                        }
                        .padding(.leading, 14)
                    }
                    .padding(.top, 22)

                    Divider().background(C.border).padding(.vertical, 18)

                    // Priority
                    sectionLabel("Priority")
                    PriorityPickerView(
                        selected: Binding(
                            get: { task.priority },
                            set: { store.updatePriority(task.id, $0) }
                        ),
                        C: C
                    )
                    .padding(.bottom, 20)

                    // Booked block
                    if task.state == .booked, let s = task.startTime, let e = task.endTime, let p = task.period {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("BOOKED")
                                    .font(.system(size: 10, weight: .heavy))
                                    .foregroundColor(C.green)
                                    .tracking(0.8)
                                if let bd = task.bookedDate {
                                    Text(bookedDateFull(bd))
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(C.sub)
                                }
                                Text("\(s) – \(e) \(p)")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(C.text)
                            }
                            Spacer()
                            HStack(spacing: 5) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 12))
                                Text("Synced")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(C.green)
                        }
                        .padding(16)
                        .background(C.greenLight)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.bottom, 18)
                    }

                    // Waiting block
                    if task.state == .waiting {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("WAITING ON")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundColor(C.purple)
                                .tracking(0.8)
                            Text(task.waitingOn ?? "Someone")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(C.text)
                            if let note = task.waitingNote {
                                Text(note)
                                    .font(.system(size: 13))
                                    .foregroundColor(C.sub)
                                    .lineSpacing(4)
                                    .padding(.top, 2)
                            }
                            HStack(spacing: 8) {
                                Button { store.showNudgeSheet = true } label: {
                                    Label("Nudge", systemImage: "envelope")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(C.purple)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(C.purple, lineWidth: 1.5))
                                }
                                .buttonStyle(.plain)
                                .accessibilityHint("Send a follow-up message")
                                Button { store.unblockTask(task.id) } label: {
                                    Label("Got It", systemImage: "checkmark")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(C.purple)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                                .accessibilityHint("Mark as unblocked, move back to unscheduled")
                            }
                            .padding(.top, 14)
                        }
                        .padding(16)
                        .background(C.purpleLight)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.bottom, 18)
                    }

                    // Notes
                    sectionLabel("Notes")
                    TextField("Add notes…", text: Binding(
                        get: { task.notes },
                        set: { store.updateNotes(task.id, $0) }
                    ), axis: .vertical)
                        .font(.system(size: 14))
                        .foregroundColor(C.text)
                        .tint(C.primary)
                        .lineSpacing(4)
                        .lineLimit(3...)
                        .padding(12)
                        .frame(minHeight: 60, alignment: .topLeading)
                        .background(C.card)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(C.border, lineWidth: 1.5))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.bottom, 18)

                    // Category
                    if !task.category.isEmpty {
                        sectionLabel("Category")
                        Text(task.category)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(C.primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(C.primaryLight)
                            .clipShape(Capsule())
                            .padding(.bottom, 24)
                    }

                    // Action buttons
                    VStack(spacing: 10) {
                        if task.state == .completed || task.state == .deleted {
                            Button { store.restoreTask(task.id) } label: {
                                Label("Restore Task", systemImage: "arrow.uturn.left")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(C.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 18))
                                    .shadow(color: C.primary.opacity(0.3), radius: 10, x: 0, y: 6)
                            }
                            .buttonStyle(.plain)
                        }
                        if task.state != .completed && task.state != .deleted {
                            Button { store.completeTask(task.id) } label: {
                                Label("Mark Complete", systemImage: "checkmark")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(C.green)
                                    .clipShape(RoundedRectangle(cornerRadius: 18))
                                    .shadow(color: C.green.opacity(0.3), radius: 10, x: 0, y: 6)
                            }
                            .buttonStyle(.plain)
                        }
                        if task.state == .unscheduled {
                            Button { if let id = store.selectedTaskId { store.openBookTime(for: id) } } label: {
                                Label("Schedule", systemImage: "calendar")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundColor(C.primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 15)
                                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(C.primary, lineWidth: 2))
                            }
                            .buttonStyle(.plain)
                        }
                        if task.state == .booked {
                            Button { if let id = store.selectedTaskId { store.openBookTime(for: id) } } label: {
                                Label("Reschedule", systemImage: "calendar.badge.clock")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundColor(C.primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 15)
                                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(C.primary, lineWidth: 2))
                            }
                            .buttonStyle(.plain)
                        }
                        if task.state != .waiting && task.state != .completed && task.state != .deleted {
                            Button { store.showWaitingSheet = true } label: {
                                Label("Mark as Waiting", systemImage: "hourglass")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(C.purple)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 15)
                                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(C.purple, lineWidth: 2))
                            }
                            .buttonStyle(.plain)
                        }
                        if task.state != .deleted {
                            Button { showDeleteConfirm = true } label: {
                                Text("Delete Task")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundColor(C.high)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                            }
                            .buttonStyle(.plain)
                            .confirmationDialog("Delete this task?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                                Button("Delete", role: .destructive) { store.deleteTask(task.id) }
                                Button("Cancel", role: .cancel) {}
                            } message: {
                                Text("The task will be moved to Deleted and can be restored from History.")
                            }
                        }
                    }
                    .padding(.bottom, 40)
                }
                .padding(.horizontal, 24)
            }
        }
        .background(C.bg)
    }

    func bookedDateFull(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        f.timeZone = .current
        guard let d = f.date(from: iso) else { return iso }
        let cal = Calendar.current
        if cal.isDateInToday(d) { return "Today" }
        if cal.isDateInTomorrow(d) { return "Tomorrow" }
        if cal.isDateInYesterday(d) { return "Yesterday" }
        let df = DateFormatter(); df.dateStyle = .full; df.timeStyle = .none
        return df.string(from: d)
    }

    func formattedCreatedDate(_ iso: String) -> String {
        let isoFmt = ISO8601DateFormatter()
        isoFmt.formatOptions = [.withFullDate]
        isoFmt.timeZone = .current
        guard let d = isoFmt.date(from: iso) else { return iso }
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none
        return f.string(from: d)
    }

    @ViewBuilder func stateBadge(_ task: GTask) -> some View {
        let (label, color): (String, Color) = {
            switch task.state {
            case .unscheduled: return ("Unscheduled", C.primary)
            case .booked: return ("Booked", C.green)
            case .waiting: return ("Waiting", C.purple)
            case .completed: return ("Completed", C.muted)
            case .deleted: return ("Deleted", C.high)
            }
        }()
        Text(label)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    @ViewBuilder func sectionLabel(_ s: String) -> some View {
        Text(s.uppercased())
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(C.muted)
            .tracking(0.8)
            .padding(.bottom, 8)
    }
}
