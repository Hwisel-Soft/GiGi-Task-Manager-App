import SwiftUI

struct BookTimeSheet: View {
    @Environment(AppStore.self) var store
    private var C: GColors { store.C }
    private let durations = ["15m", "30m", "45m", "1h", "2h"]

    private var taskTitle: String {
        store.selectedTask()?.title ?? "Task"
    }

    private var conflict: GTask? {
        store.conflictingTask(
            hour: store.bookForm.hour,
            minute: store.bookForm.minute,
            period: store.bookForm.period,
            duration: store.bookForm.duration,
            excludeId: store.selectedTaskId
        )
    }

    private var dayLabels: [String] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let f = DateFormatter(); f.dateFormat = "E d"
        return (0..<14).map { i in
            let d = cal.date(byAdding: .day, value: i, to: today)!
            if i == 0 { return "Today" }
            if i == 1 { return "Tomorrow" }
            return f.string(from: d)
        }
    }

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Task name chip
                    HStack {
                        Text(taskTitle)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(C.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(C.primaryLight)
                            .clipShape(Capsule())
                        Spacer()
                    }

                    // Date row
                    sectionLabel("Date")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(dayLabels.enumerated()), id: \.offset) { i, label in
                                Button { store.bookForm.dateOffset = i } label: {
                                    Text(label)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(store.bookForm.dateOffset == i ? C.primary : C.text)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(store.bookForm.dateOffset == i ? C.primaryLight : C.card)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(store.bookForm.dateOffset == i ? C.primary : C.border, lineWidth: 1.5)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Time picker
                    sectionLabel("Time")
                    HStack(spacing: 8) {
                        // Hour picker
                        Picker("Hour", selection: $store.bookForm.hour) {
                            ForEach(1...12, id: \.self) { h in
                                Text("\(h)").tag(h)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 70, height: 100)
                        .clipped()
                        .background(C.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        Text(":")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(C.text)

                        // Minute picker
                        Picker("Minute", selection: $store.bookForm.minute) {
                            ForEach([0, 15, 30, 45], id: \.self) { m in
                                Text(String(format: "%02d", m)).tag(m)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 70, height: 100)
                        .clipped()
                        .background(C.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        Spacer()

                        // AM/PM
                        VStack(spacing: 6) {
                            ForEach(["AM", "PM"], id: \.self) { p in
                                Button { store.bookForm.period = p } label: {
                                    Text(p)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(store.bookForm.period == p ? .white : C.muted)
                                        .frame(width: 52, height: 40)
                                        .background(store.bookForm.period == p ? C.primary : C.card)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Duration
                    sectionLabel("Duration")
                    HStack(spacing: 8) {
                        ForEach(durations, id: \.self) { d in
                            Button { store.bookForm.duration = d } label: {
                                Text(d)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(store.bookForm.duration == d ? C.primary : C.text)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(store.bookForm.duration == d ? C.primaryLight : C.card)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(store.bookForm.duration == d ? C.primary : C.border, lineWidth: 1.5)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Conflict warning
                    if let c = conflict {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(C.med)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Conflicts with: \(c.title)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(C.text)
                                if let s = c.startTime, let e = c.endTime, let p = c.period {
                                    Text("\(s) – \(e) \(p)  ·  You can still proceed.")
                                        .font(.system(size: 11))
                                        .foregroundColor(C.muted)
                                }
                            }
                        }
                        .padding(14)
                        .background(C.medLight)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Book button
                    Button {
                        if let id = store.selectedTaskId { store.bookTask(id) }
                        else { store.showBookTime = false }
                    } label: {
                        Text(conflict != nil ? "Book It Anyway" : "Book It")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(colors: [C.primary, C.primaryDark], startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .shadow(color: C.primary.opacity(0.35), radius: 10, x: 0, y: 6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(24)
            }
            .background(C.bg)
            .navigationTitle("Book Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { store.showBookTime = false }
                        .foregroundColor(C.primary)
                }
            }
        }
        .presentationDetents([.fraction(0.88)])
        .presentationDragIndicator(.visible)
        .presentationBackground(C.bg)
    }

    @ViewBuilder func sectionLabel(_ s: String) -> some View {
        Text(s.uppercased())
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(C.muted)
            .tracking(0.8)
    }
}
