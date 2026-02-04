import SwiftUI

@main
struct ClaudeStatsApp: App {
    @StateObject private var vm = StatsViewModel()
    @StateObject private var claudeCode = ClaudeCodeManager()
    @Environment(\.openWindow) var openWindow

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(openSettingsWindow: { openWindow(id: "settings") })
                .environmentObject(vm)
                .environmentObject(claudeCode)
        } label: {
            HStack(spacing: 4) {
                Image(nsImage: ClaudeIcon.menuBarImage(badgeCount: claudeCode.waitingCount))
                if vm.showPercentInMenuBar && vm.isLoggedIn {
                    Text("\(Int(vm.sessionPercent))%")
                        .font(.caption)
                }
            }
            .onReceive(vm.$initialLoadComplete) { complete in
                if complete && vm.needsLogin && !vm.isLoggedIn && !vm.hasAutoOpenedLoginWindow {
                    vm.hasAutoOpenedLoginWindow = true
                    openWindow(id: "settings")
                }
            }
        }
        .menuBarExtraStyle(.window)

        Window("Claude Stats Settings", id: "settings") {
            SettingsView()
                .environmentObject(vm)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}
