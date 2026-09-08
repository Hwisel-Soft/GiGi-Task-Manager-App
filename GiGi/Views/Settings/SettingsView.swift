import SwiftUI
import AppIntents

struct SettingsView: View {
    @Environment(AppStore.self) var store
    private var C: GColors { store.C }

    var body: some View {
        @Bindable var store = store
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Settings")
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundColor(C.text)
                    .tracking(-1)
                    .padding(.horizontal, 24)
                    .padding(.top, 18)

                // Notifications
                settingsCard {
                    sectionHeader("Notifications")
                    toggleRow(label: "Lapsed Session Alert", value: $store.lapsedAlert,
                               sub: "Prompt when a booked task's time passes")
                    Divider().background(C.border)
                    toggleRow(label: "Morning Summary", value: $store.morningSummary,
                               sub: "Daily digest at \(store.morningSummary ? store.morningTimeLabel : "—")")

                    if store.morningSummary {
                        Divider().background(C.border)
                        HStack {
                            Text("Summary time")
                                .font(.system(size: 15))
                                .foregroundColor(C.text)
                            Spacer()
                            DatePicker("", selection: morningTimeBinding, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .tint(C.primary)
                        }
                        notificationPreview
                    }
                }

                // Calendar
                settingsCard {
                    sectionHeader("Calendar")
                    toggleRow(label: "Calendar Sync", value: $store.calSync,
                               sub: "Add booked tasks to your calendar")
                    if store.calSync {
                        Divider().background(C.border)
                        valueRow(label: "Target Calendar", value: store.defaultCalendarName)
                    }
                }

                // Siri
                settingsCard {
                    sectionHeader("Siri")
                    HStack(spacing: 12) {
                        Image(systemName: "waveform")
                            .font(.system(size: 20))
                            .foregroundColor(.purple)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add Task Shortcut")
                                .font(.system(size: 15))
                                .foregroundColor(C.text)
                            Text("Automatically available in Siri")
                                .font(.system(size: 12))
                                .foregroundColor(C.muted)
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    Divider().background(C.border).padding(.vertical, 8)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SAY TO SIRI")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(C.muted)
                            .tracking(0.8)
                        Text("\"Hey Siri, add task in GiGi\"")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(C.text)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(C.bg)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }

                // Categories
                settingsCard {
                    sectionHeader("Categories")
                    ForEach(store.categories) { cat in
                        VStack(spacing: 0) {
                            HStack {
                                Text("🏷")
                                Text(cat.name)
                                    .font(.system(size: 15))
                                    .foregroundColor(C.text)
                                Spacer()
                                Circle()
                                    .fill(Color(hex: cat.color))
                                    .frame(width: 12, height: 12)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(C.muted)
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                store.editingCategoryId = cat.id
                                store.catForm = CatForm(name: cat.name, color: cat.color)
                                store.showCategorySheet = true
                            }
                            if cat.id != store.categories.last?.id {
                                Divider().background(C.border)
                            }
                        }
                    }
                    Divider().background(C.border)
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(C.primary)
                        Text("Add Category")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(C.primary)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        store.editingCategoryId = nil
                        store.catForm = CatForm()
                        store.showCategorySheet = true
                    }
                }

                // Task Defaults
                settingsCard {
                    sectionHeader("Task Defaults")
                    HStack {
                        Text("Default Duration")
                            .font(.system(size: 15))
                            .foregroundColor(C.text)
                        Spacer()
                        Picker("", selection: $store.defaultDuration) {
                            ForEach(["15m","30m","45m","1h","2h"], id: \.self) { d in
                                Text(d).tag(d)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    Divider().background(C.border)
                    HStack {
                        Text("Default Priority")
                            .font(.system(size: 15))
                            .foregroundColor(C.text)
                        Spacer()
                        Picker("", selection: $store.defaultPriority) {
                            ForEach(Priority.allCases, id: \.self) { p in
                                Text(p.label).tag(p)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                // App
                settingsCard {
                    sectionHeader("App")
                    toggleRow(label: "Colorful Task Cards", value: $store.colorfulCards,
                               sub: "Tinted backgrounds on calendar cards")
                    Divider().background(C.border)
                    toggleRow(label: "Dark Mode", value: $store.darkMode, sub: nil)
                    Divider().background(C.border)
                    HStack {
                        Text("Version")
                            .font(.system(size: 15))
                            .foregroundColor(C.text)
                        Spacer()
                        Text(appVersionString)
                            .font(.system(size: 15))
                            .foregroundColor(C.muted)
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .background(C.bg)
        .navigationBarHidden(true)
        .onChange(of: store.darkMode) { _, _ in store.save() }
        .onChange(of: store.colorfulCards) { _, _ in store.save() }
        .onChange(of: store.lapsedAlert) { _, _ in store.save() }
        .onChange(of: store.morningSummary) { _, newVal in
            store.save()
            if newVal { store.requestMorningNotificationIfNeeded() }
            else { store.cancelMorningNotification() }
        }
        .onChange(of: store.morningHour) { _, _ in store.save(); store.scheduleMorningNotification() }
        .onChange(of: store.morningMinute) { _, _ in store.save(); store.scheduleMorningNotification() }
        .onChange(of: store.calSync) { _, newVal in
            store.save()
            if newVal { store.requestCalendarAccessIfNeeded() }
        }
        .onChange(of: store.defaultDuration) { _, _ in store.save() }
        .onChange(of: store.defaultPriority) { _, _ in store.save() }
    }

    var morningTimeBinding: Binding<Date> {
        Binding(
            get: {
                var c = DateComponents()
                c.hour = store.morningHour
                c.minute = store.morningMinute
                return Calendar.current.date(from: c) ?? Date()
            },
            set: { d in
                let c = Calendar.current.dateComponents([.hour, .minute], from: d)
                store.morningHour = c.hour ?? 8
                store.morningMinute = c.minute ?? 0
            }
        )
    }

    var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    @ViewBuilder
    func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(16)
        .background(C.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    func sectionHeader(_ s: String) -> some View {
        Text(s.uppercased())
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(C.muted)
            .tracking(0.8)
            .padding(.bottom, 10)
    }

    @ViewBuilder
    func toggleRow(label: String, value: Binding<Bool>, sub: String?) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 15))
                    .foregroundColor(C.text)
                if let sub {
                    Text(sub)
                        .font(.system(size: 12))
                        .foregroundColor(C.muted)
                }
            }
            Spacer()
            Toggle("", isOn: value)
                .tint(C.primary)
                .labelsHidden()
        }
    }

    @ViewBuilder
    func valueRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(C.text)
            Spacer()
            Text(value)
                .font(.system(size: 15))
                .foregroundColor(C.muted)
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(C.muted)
        }
    }

    var notificationPreview: some View {
        @Bindable var store = store
        let scheduled = store.todaysScheduledTasks.count
        let unscheduled = store.unscheduledTasks.count
        let followUps = store.waitingTasks.filter { store.isFollowUpDue($0) }.count
        let topTasks = Array(store.todaysScheduledTasks.prefix(2))
        return VStack(alignment: .leading, spacing: 0) {
            Divider().background(C.border)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LinearGradient(colors: [C.primary, C.pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 36, height: 36)
                        Text("G")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        HStack {
                            Text("GiGi").font(.system(size: 12, weight: .bold)).foregroundColor(C.text)
                            Spacer()
                            Text("8:00 AM").font(.system(size: 11)).foregroundColor(C.muted)
                        }
                        Text("\(scheduled) scheduled · \(unscheduled) unscheduled\(followUps > 0 ? " · \(followUps) follow-up\(followUps == 1 ? "" : "s")" : "")")
                            .font(.system(size: 12))
                            .foregroundColor(C.sub)
                    }
                }
                if !topTasks.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(topTasks) { task in
                            HStack(spacing: 6) {
                                Circle().fill(C.priorityColor(task.priority)).frame(width: 6, height: 6)
                                Text(task.title)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(C.text)
                                    .lineLimit(1)
                                if let s = task.startTime, let p = task.period {
                                    Spacer()
                                    Text("\(s) \(p)")
                                        .font(.system(size: 11))
                                        .foregroundColor(C.muted)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
                Text("This is how your morning notification will appear.")
                    .font(.system(size: 11))
                    .foregroundColor(C.muted)
            }
            .padding(12)
            .background(C.bg)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
