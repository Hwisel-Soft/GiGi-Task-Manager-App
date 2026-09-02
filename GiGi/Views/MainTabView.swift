import SwiftUI

struct MainTabView: View {
    @Environment(AppStore.self) var store

    var body: some View {
        @Bindable var store = store
        TabView(selection: $store.selectedTab) {
            NavigationStack {
                TodayView()
                    .navigationDestination(isPresented: $store.showDetail) {
                        TaskDetailView()
                    }
            }
            .tabItem { Label("Today", systemImage: "house") }
            .tag(AppTab.today)

            NavigationStack {
                CalendarView()
                    .navigationDestination(isPresented: $store.showDetail) {
                        TaskDetailView()
                    }
            }
            .tabItem { Label("Calendar", systemImage: "calendar") }
            .tag(AppTab.calendar)

            NavigationStack {
                WaitingView()
                    .navigationDestination(isPresented: $store.showDetail) {
                        TaskDetailView()
                    }
            }
            .tabItem {
                Label("Waiting", systemImage: "hourglass")
            }
            .badge(store.waitingTasks.count > 0 ? store.waitingTasks.count : 0)
            .tag(AppTab.waiting)

            NavigationStack {
                HistoryView()
            }
            .tabItem { Label("History", systemImage: "checkmark.circle") }
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
