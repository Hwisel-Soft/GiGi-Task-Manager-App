import SwiftUI

@main
struct GiGiApp: App {
    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(store.darkMode ? .dark : .light)
        }
    }
}

struct RootView: View {
    @Environment(AppStore.self) var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var timerTick = 0

    // Re-evaluated every 60s via timerTick so the overlay fires while the app is open.
    // Without this, lapsedTask only refreshes on data changes, not on the clock.
    private var currentLapsedTask: GTask? {
        _ = timerTick
        return store.lapsedTask
    }

    var body: some View {
        @Bindable var store = store
        ZStack(alignment: .bottom) {
            MainTabView()
        }
        .sheet(isPresented: $store.showAddTask) { AddTaskSheet() }
        .sheet(isPresented: $store.showBookTime) { BookTimeSheet() }
        .sheet(isPresented: $store.showWaitingSheet) { WaitingSheet() }
        .sheet(isPresented: $store.showNudgeSheet) { NudgeSheet() }
        .sheet(isPresented: $store.showCategorySheet) { CategorySheet() }
        .sheet(isPresented: $store.showSiriInfo) { SiriInfoModal() }
        .sheet(isPresented: $store.showMicInfo) { MicInfoModal() }
        .overlay {
            if let task = currentLapsedTask {
                LapsedSessionModal(task: task)
                    .transition(.opacity)
                    .animation(.easeIn(duration: 0.2), value: true)
            }
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            timerTick += 1
            store.updateBadge()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.reloadTasksFromUserDefaults()
                store.scheduleMorningNotification()
                store.updateBadge()
            }
        }
        .task {
            await store.requestBadgePermissionIfNeeded()
        }
    }
}
