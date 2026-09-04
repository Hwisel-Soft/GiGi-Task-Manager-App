import SwiftUI

struct AddTaskSheet: View {
    @Environment(AppStore.self) var store
    private var C: GColors { store.C }
    private let durations = ["15m", "30m", "45m", "1h", "2h"]

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title input
                    HStack(spacing: 10) {
                        TextField("Task title…", text: $store.addForm.title)
                            .font(.system(size: 15))
                            .foregroundColor(C.text)
                            .tint(C.primary)

                        Button { store.showMicInfo = true } label: {
                            ZStack {
                                Circle()
                                    .fill(C.primaryLight)
                                    .frame(width: 34, height: 34)
                                Image(systemName: "mic")
                                    .font(.system(size: 14))
                                    .foregroundColor(C.primary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 14)
                    .background(C.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(store.addForm.title.isEmpty ? C.border : C.primary, lineWidth: 2)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    // Priority
                    label("Priority")
                    PriorityPickerView(selected: $store.addForm.priority, C: C)

                    // Duration
                    label("Duration")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(durations, id: \.self) { d in
                                Button { store.addForm.duration = d } label: {
                                    Text(d)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(store.addForm.duration == d ? C.primary : C.text)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(store.addForm.duration == d ? C.primaryLight : C.card)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(store.addForm.duration == d ? C.primary : C.border, lineWidth: 1.5)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Category
                    label("Category")
                    categoryPicker

                    // Deadline
                    label("Deadline (optional)")
                    if store.addForm.deadline.isEmpty {
                        Button {
                            let f = ISO8601DateFormatter(); f.formatOptions = [.withFullDate]
                            store.addForm.deadline = f.string(from: Date())
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle").foregroundColor(C.primary)
                                Text("Add deadline")
                                    .font(.system(size: 14))
                                    .foregroundColor(C.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(C.card)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(C.border, lineWidth: 1.5))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    } else {
                        HStack {
                            DatePicker("", selection: deadlineBinding, in: Date()..., displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .tint(C.primary)
                            Spacer()
                            Button { store.addForm.deadline = "" } label: {
                                Image(systemName: "xmark.circle.fill").foregroundColor(C.muted)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(C.card)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(C.primary, lineWidth: 1.5))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Notes
                    label("Notes")
                    TextField("Add notes…", text: $store.addForm.notes, axis: .vertical)
                        .font(.system(size: 14))
                        .foregroundColor(C.text)
                        .tint(C.primary)
                        .lineLimit(3...6)
                        .padding(14)
                        .background(C.card)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(C.border, lineWidth: 1.5))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Add button
                    Button { store.addTask() } label: {
                        Text("Add Task")
                            .font(.system(size: 17, weight: .heavy))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(addButtonBg)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                    .disabled(store.addForm.title.isEmpty)
                }
                .padding(24)
            }
            .background(C.bg)
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        store.showAddTask = false
                        store.addForm = AddForm()
                    }
                    .foregroundColor(C.primary)
                }
            }
        }
        .presentationDetents([.fraction(0.88)])
        .presentationDragIndicator(.visible)
        .presentationBackground(C.bg)
    }

    private var deadlineBinding: Binding<Date> {
        Binding(
            get: {
                let f = ISO8601DateFormatter(); f.formatOptions = [.withFullDate]
                return f.date(from: store.addForm.deadline) ?? Date()
            },
            set: { d in
                let f = ISO8601DateFormatter(); f.formatOptions = [.withFullDate]
                store.addForm.deadline = f.string(from: d)
            }
        )
    }

    @ViewBuilder var addButtonBg: some View {
        if store.addForm.title.isEmpty {
            C.border
        } else {
            LinearGradient(colors: [C.primary, C.primaryDark], startPoint: .leading, endPoint: .trailing)
        }
    }

    var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.categories) { cat in
                    let selected = store.addForm.category == cat.name
                    Button { store.addForm.category = cat.name } label: {
                        HStack(spacing: 6) {
                            Circle().fill(Color(hex: cat.color)).frame(width: 8, height: 8)
                            Text(cat.name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(selected ? C.primary : C.text)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(selected ? C.primaryLight : C.card)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? C.primary : C.border, lineWidth: 1.5))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder func label(_ s: String) -> some View {
        Text(s.uppercased())
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(C.muted)
            .tracking(0.8)
    }
}
