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
            if let task = store.lapsedTask {
                LapsedSessionModal(task: task)
                    .transition(.opacity)
                    .animation(.easeIn(duration: 0.2), value: true)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.scheduleMorningNotification() }
        }
    }
}
