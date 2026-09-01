import SwiftUI

struct TaskCardView: View {
    let task: GTask
    @Environment(AppStore.self) var store

    @State private var offset: CGFloat = 0
    @State private var isOpen = false
    private let openWidth: CGFloat = 204

    private var C: GColors { store.C }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Action buttons behind card
            HStack(spacing: 0) {
                actionBtn(label: "Done", icon: "checkmark", bg: C.green) {
                    close(); store.completeTask(task.id)
                }
                actionBtn(label: "Waiting", emoji: "⏳", bg: C.purple) {
                    close()
                    store.selectedTaskId = task.id
                    store.showWaitingSheet = true
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
                .gesture(dragGesture)
                .onTapGesture {
                    if isOpen { close() } else { store.openTask(task.id) }
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.07), radius: 5, x: 0, y: 2)
        .onChange(of: store.swipedTaskId) { _, newId in
            if newId != task.id && isOpen { close() }
        }
    }

    var cardFace: some View {
        HStack(spacing: 0) {
            // Priority bar
            Rectangle()
                .fill(C.priorityColor(task.priority))
                .frame(width: 4)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 4))

            // Content
            VStack(alignment: .leading, spacing: 5) {
                Text(task.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(C.text)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let s = task.startTime, let e = task.endTime, let p = task.period {
                        Text("\(s)–\(e) \(p)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(C.primary)
                    }
                    if task.age > 0 {
                        Text("\(task.age)d")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(C.med)
                    }
                    if let dl = task.deadline, daysUntilDeadline(dl) <= 3 {
                        Text("Due \(formattedDeadline(dl))")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(C.high)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(C.highLight)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
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
            .padding(.horizontal, 13)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Overflow button
            Button {
                if isOpen { close() } else { open() }
            } label: {
                Text("⋯")
                    .font(.system(size: 20))
                    .foregroundColor(C.muted)
                    .padding(.horizontal, 14)
                    .frame(maxHeight: .infinity)
            }
            .buttonStyle(.plain)
        }
        .background(C.card)
    }

    @ViewBuilder
    func actionBtn(label: String, icon: String? = nil, emoji: String? = nil, bg: Color, cornerRight: CGFloat = 0, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                if let icon { Image(systemName: icon).font(.system(size: 16, weight: .medium)) }
                else if let emoji { Text(emoji).font(.system(size: 16)) }
                Text(label).font(.system(size: 9, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(width: 68)
            .frame(maxHeight: .infinity)
            .background(bg)
            .clipShape(UnevenRoundedRectangle(bottomTrailingRadius: cornerRight, topTrailingRadius: cornerRight))
        }
        .buttonStyle(.plain)
    }

    var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { v in
                guard abs(v.translation.height) < 40 else { return }
                let base: CGFloat = isOpen ? -openWidth : 0
                offset = max(-openWidth, min(0, base + v.translation.width))
            }
            .onEnded { v in
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

    func formattedDeadline(_ dl: String) -> String {
        if dl.contains("-") {
            let f = ISO8601DateFormatter(); f.formatOptions = [.withFullDate]
            if let d = f.date(from: dl) {
                let days = daysUntilDeadline(dl)
                if days == 0 { return "today" }
                if days == 1 { return "tomorrow" }
                let df = DateFormatter(); df.dateFormat = "EEE"
                return df.string(from: d)
            }
        }
        return dl
    }

    func daysUntilDeadline(_ dl: String) -> Int {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withFullDate]
        guard let d = f.date(from: dl) else { return Int.max }
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.startOfDay(for: d)
        return cal.dateComponents([.day], from: start, to: end).day ?? Int.max
    }
}
