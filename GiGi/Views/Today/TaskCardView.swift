import SwiftUI

struct TaskCardView: View {
    let task: GTask
    var showStateBadge: Bool = false
    @Environment(AppStore.self) var store
    @Environment(SubscriptionStore.self) var subStore

    @State private var offset: CGFloat = 0
    @State private var isOpen = false
    @State private var dragIsHorizontal: Bool? = nil
    private let openWidth: CGFloat = 204

    private var C: GColors { store.C }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Action buttons behind card
            HStack(spacing: 0) {
                actionBtn(label: "Done", icon: "checkmark", bg: C.green) {
                    close(); store.completeTask(task.id)
                }
                actionBtn(label: "Waiting", icon: "hourglass", bg: C.purple) {
                    close()
                    if subStore.isPro {
                        store.selectedTaskId = task.id
                        store.showWaitingSheet = true
                    } else {
                        subStore.showPaywall = true
                    }
                }
                actionBtn(label: "Delete", icon: "trash", bg: C.high, cornerRight: 16) {
                    close(); store.deleteTask(task.id)
                }
            }
            .frame(width: openWidth)

            // Card face
            cardFace
                .offset(x: offset)
                .animation(.interpolatingSpring(stiffness: 300, damping: 30), value: offset)
                .simultaneousGesture(dragGesture)
                .onTapGesture {
                    if isOpen { close() } else { store.openTask(task.id) }
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            if task.autoRolled == true {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                    .foregroundColor(C.med.opacity(0.6))
            }
        }
        .shadow(color: Color.black.opacity(0.07), radius: 5, x: 0, y: 2)
        .onChange(of: store.swipedTaskId) { _, newId in
            if newId != task.id && isOpen { close() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(cardAccessibilityLabel)
        .accessibilityHint("Double tap to open")
        .accessibilityAction(named: "Mark Complete") {
            store.completeTask(task.id)
        }
        .accessibilityAction(named: "Mark as Waiting") {
            if subStore.isPro {
                store.selectedTaskId = task.id
                store.showWaitingSheet = true
            } else {
                subStore.showPaywall = true
            }
        }
        .accessibilityAction(named: "Delete") {
            store.deleteTask(task.id)
        }
    }

    var cardFace: some View {
        HStack(spacing: 11) {
            // Checkbox
            Circle()
                .strokeBorder(
                    task.priority == .high ? C.high : C.border,
                    lineWidth: 1.5
                )
                .frame(width: 20, height: 20)

            // Content
            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(C.text)
                    .lineLimit(1)

                // Meta row
                HStack(spacing: 5) {
                    if let s = task.startTime, let e = task.endTime, let p = task.period {
                        let dateLabel = task.bookedDate.map { scheduledDateLabel($0) } ?? ""
                        let timeLabel = dateLabel.isEmpty ? "\(s)–\(e) \(p)" : "\(dateLabel) · \(s)–\(e) \(p)"
                        Text(timeLabel)
                            .foregroundColor(store.isLapsed(task) ? C.high : C.primary)
                            .fontWeight(.semibold)
                    }
                    if task.age > 0 {
                        Text("·").foregroundColor(C.border)
                        Text("\(task.age)d").foregroundColor(C.med).bold()
                    }
                    if task.autoRolled == true {
                        Text("↻").foregroundColor(C.med)
                    }
                    if let dl = task.deadline, daysUntilDeadline(dl) <= 3 {
                        Text("·").foregroundColor(C.border)
                        Text("Due \(formattedDeadline(dl))").foregroundColor(C.high).bold()
                    }
                    if !task.category.isEmpty {
                        Text("·").foregroundColor(C.border)
                        Text(task.category).foregroundColor(C.muted)
                    }
                }
                .font(.caption2)

                if showStateBadge {
                    stateBadgeView.padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Priority badge (always visible)
            priorityBadgeCompact
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(cardBackground)
        .overlay(alignment: .leading) {
            if task.priority == .high {
                Rectangle()
                    .fill(C.high)
                    .frame(width: 3)
            }
        }
    }

    private var cardBackground: Color {
        guard showStateBadge else { return C.card }
        if store.isLapsed(task) { return C.highLight }
        if task.autoRolled == true { return C.medLight }
        if task.state == .waiting && store.isFollowUpDue(task) { return C.medLight }
        return C.card
    }

    @ViewBuilder
    private var priorityPill: some View {
        let (label, fg, bg): (String, Color, Color) = {
            switch task.priority {
            case .high: return ("High", C.high, C.highLight)
            case .medium: return ("Med", C.med, C.medLight)
            case .low: return ("Low", C.green, C.greenLight)
            }
        }()
        Text(label)
            .font(.caption2.bold())
            .foregroundColor(fg)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var priorityBadgeCompact: some View {
        let (label, fg, bg): (String, Color, Color) = {
            switch task.priority {
            case .high:   return ("High", C.high, C.highLight)
            case .medium: return ("Med", C.primary, C.primaryLight)
            case .low:    return ("Low", C.muted, C.border)
            }
        }()
        Text(label)
            .font(.caption2.bold())
            .foregroundColor(fg)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private var stateBadgeView: some View {
        let lapsed = store.isLapsed(task)
        let carried = task.autoRolled == true && !lapsed
        let followUpOverdue = task.state == .waiting && store.isFollowUpDue(task)
        let (label, fg, bg): (String, Color, Color) = {
            if lapsed { return ("Lapsed", C.high, C.highLight) }
            if carried { return ("Missed", C.med, C.medLight) }
            if followUpOverdue { return ("Follow up", C.med, C.medLight) }
            switch task.state {
            case .booked: return ("Booked", C.green, C.greenLight)
            case .unscheduled: return ("Unscheduled", C.primary, C.primaryLight)
            case .waiting: return ("Waiting", C.purple, C.purpleLight)
            default: return ("", C.muted, C.card)
            }
        }()
        if !label.isEmpty {
            Text(label)
                .font(.caption2.bold())
                .foregroundColor(fg)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(bg)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    func actionBtn(label: String, icon: String? = nil, emoji: String? = nil, bg: Color, cornerRight: CGFloat = 0, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                if let icon { Image(systemName: icon).font(.callout.weight(.medium)) }
                else if let emoji { Text(emoji).font(.callout) }
                Text(label).font(.caption.bold())
            }
            .foregroundColor(.white)
            .frame(width: 68)
            .frame(maxHeight: .infinity)
            .background(bg)
            .clipShape(UnevenRoundedRectangle(bottomTrailingRadius: cornerRight, topTrailingRadius: cornerRight))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var cardAccessibilityLabel: String {
        var parts = [task.title, "\(task.priority.label) priority"]
        if let s = task.startTime, let e = task.endTime, let p = task.period {
            parts.append("Scheduled \(s) to \(e) \(p)")
        }
        if task.age > 0 { parts.append("Carried \(task.age) days") }
        if store.isLapsed(task) { parts.append("Lapsed") }
        if !task.category.isEmpty { parts.append(task.category) }
        return parts.joined(separator: ", ")
    }

    var dragGesture: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .local)
            .onChanged { v in
                if dragIsHorizontal == nil {
                    dragIsHorizontal = abs(v.translation.width) > abs(v.translation.height)
                }
                guard dragIsHorizontal == true else { return }
                let base: CGFloat = isOpen ? -openWidth : 0
                offset = max(-openWidth, min(0, base + v.translation.width))
            }
            .onEnded { v in
                defer { dragIsHorizontal = nil }
                guard dragIsHorizontal == true else {
                    withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                        offset = isOpen ? -openWidth : 0
                    }
                    return
                }
                if v.translation.width < -30 { open() } else { close() }
            }
    }

    func open() {
        store.swipedTaskId = task.id
        withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
            offset = -openWidth; isOpen = true
        }
    }

    func close() {
        store.swipedTaskId = nil
        withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
            offset = 0; isOpen = false
        }
    }

    private static let isoFmt: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        f.timeZone = .current
        return f
    }()
    private static let dayOfWeekFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "EEE"; return f }()
    private static let scheduleLabelFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "EEE MMM d"; return f }()
    private static let sameYearFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "MMM d"; return f }()
    private static let fullYearFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"; return f }()

    func formattedDeadline(_ dl: String) -> String {
        guard dl.contains("-"), let d = Self.isoFmt.date(from: dl) else { return dl }
        let days = daysUntilDeadline(dl)
        if days == 0 { return "today" }
        if days == 1 { return "tomorrow" }
        return Self.dayOfWeekFmt.string(from: d)
    }

    func shortCreatedDate(_ iso: String) -> String {
        guard let d = Self.isoFmt.date(from: iso) else { return "" }
        let cal = Calendar.current
        if cal.isDateInToday(d) { return "Added today" }
        if cal.isDateInYesterday(d) { return "Added yesterday" }
        let fmt = cal.component(.year, from: d) == cal.component(.year, from: Date()) ? Self.sameYearFmt : Self.fullYearFmt
        return "Added \(fmt.string(from: d))"
    }

    func scheduledDateLabel(_ iso: String) -> String {
        guard let d = Self.isoFmt.date(from: iso) else { return "" }
        let cal = Calendar.current
        if cal.isDateInToday(d) { return "Today" }
        if cal.isDateInTomorrow(d) { return "Tomorrow" }
        if cal.isDateInYesterday(d) { return "Yesterday" }
        return Self.scheduleLabelFmt.string(from: d)
    }

    func daysUntilDeadline(_ dl: String) -> Int {
        guard let d = Self.isoFmt.date(from: dl) else { return Int.max }
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.startOfDay(for: d)
        return cal.dateComponents([.day], from: start, to: end).day ?? Int.max
    }
}
