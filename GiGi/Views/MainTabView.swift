import SwiftUI

struct MainTabView: View {
    @Environment(AppStore.self) var store

    var body: some View {
        @Bindable var store = store
        TabView(selection: $store.selectedTab) {
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
    }
}
