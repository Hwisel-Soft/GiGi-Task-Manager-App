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

    private var minDate: Date { Calendar.current.startOfDay(for: Date()) }

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Task name chip
                    HStack {
                        Text(taskTitle)
                            .font(.footnote.bold())
                            .foregroundColor(C.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(C.primaryLight)
                            .clipShape(Capsule())
                        Spacer()
                    }

                    // Date picker
                    DatePicker("", selection: $store.bookForm.date,
                               in: minDate...,
                               displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(C.primary)
                        .labelsHidden()

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
                            .font(.title2.bold())
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
                                        .font(.callout.bold())
                                        .foregroundColor(store.bookForm.period == p ? .white : C.muted)
                                        .frame(width: 52, height: 40)
                                        .background(store.bookForm.period == p ? C.primary : C.card)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(store.bookForm.period == p ? "\(p), selected" : p)
                            }
                        }
                    }

                    // Duration
                    sectionLabel("Duration")
                    HStack(spacing: 8) {
                        ForEach(durations, id: \.self) { d in
                            Button { store.bookForm.duration = d } label: {
                                Text(d)
                                    .font(.footnote.weight(.semibold))
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
                                    .font(.footnote.weight(.semibold))
                                    .foregroundColor(C.text)
                                if let s = c.startTime, let e = c.endTime, let p = c.period {
                                    Text("\(s) – \(e) \(p)  ·  You can still proceed.")
                                        .font(.caption2)
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
                            .font(.callout.weight(.heavy))
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
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(C.bg)
    }

    @ViewBuilder func sectionLabel(_ s: String) -> some View {
        Text(s.uppercased())
            .font(.caption2.bold())
            .foregroundColor(C.muted)
            .tracking(0.8)
    }
}
