import SwiftUI

struct MainTabView: View {
    @Environment(AppStore.self) var store

    var body: some View {
        @Bindable var store = store
        #if os(macOS)
        macLayout
        #else
        iosLayout
        #endif
    }

    #if os(macOS)
    var macLayout: some View {
        @Bindable var store = store
        let sel = Binding<AppTab?>(
            get: { store.selectedTab },
            set: { if let t = $0 { store.selectedTab = t } }
        )
        return NavigationSplitView {
            List(AppTab.allCases, id: \.self, selection: sel) { tab in
                Label(tab.title, systemImage: tab.icon)
            }
            .navigationTitle("GiGi")
            .listStyle(.sidebar)
        } detail: {
            NavigationStack {
                switch store.selectedTab {
                case .tasks:
                    TasksView()
                        .navigationDestination(isPresented: $store.showDetail) { TaskDetailView() }
                case .calendar:
                    CalendarView()
                        .navigationDestination(isPresented: $store.showDetail) { TaskDetailView() }
                case .history:
                    HistoryView()
                        .navigationDestination(isPresented: $store.showDetail) { TaskDetailView() }
                case .settings:
                    SettingsView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { store.openAddTask() } label: {
                        Label("New Task", systemImage: "plus")
                    }
                    .keyboardShortcut("n", modifiers: .command)
                }
            }
        }
        .tint(store.C.primary)
        .onChange(of: store.selectedTab) { _, _ in
            if store.showDetail { store.goBack() }
        }
    }
    #else
    var iosLayout: some View {
        @Bindable var store = store
        return TabView(selection: $store.selectedTab) {
            NavigationStack {
                TasksView()
                    .navigationDestination(isPresented: $store.showDetail) {
                        TaskDetailView()
                    }
            }
            .tabItem { Label("Tasks", systemImage: "checklist") }
            .badge(store.tasksAlertCount > 0 ? store.tasksAlertCount : 0)
            .tag(AppTab.tasks)

            NavigationStack {
                CalendarView()
                    .navigationDestination(isPresented: $store.showDetail) {
                        TaskDetailView()
                    }
            }
            .tabItem { Label("Calendar", systemImage: "calendar") }
            .tag(AppTab.calendar)

            NavigationStack {
                HistoryView()
                    .navigationDestination(isPresented: $store.showDetail) {
                        TaskDetailView()
                    }
            }
            .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            .tag(AppTab.history)

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
            .tag(AppTab.settings)
        }
        .tint(store.C.primary)
        .onChange(of: store.selectedTab) { _, _ in
            if store.showDetail { store.goBack() }
        }
    }
    #endif
}
