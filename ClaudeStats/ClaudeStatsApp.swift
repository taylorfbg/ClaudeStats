import SwiftUI

@main
struct ClaudeStatsApp: App {
    @StateObject private var vm = StatsViewModel()
    @Environment(\.openWindow) var openWindow

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(openSettingsWindow: { openWindow(id: "settings") })
                .environmentObject(vm)
        } label: {
            HStack(spacing: 4) {
                Image(nsImage: ClaudeIcon.menuBarImage())
                if vm.showPercentInMenuBar && vm.isLoggedIn {
                    Text("\(Int(vm.sessionPercent))%")
                        .font(.caption)
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
