import SwiftUI
import WebKit

struct WebViewRepresentable: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView {
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

struct SettingsView: View {
    @EnvironmentObject var vm: StatsViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                if vm.isLoggedIn {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Logged in")
                        .font(.subheadline)
                } else {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .foregroundColor(.orange)
                    Text("Log in to claude.ai below")
                        .font(.subheadline)
                }

                Spacer()

                if vm.isLoggedIn {
                    HStack(spacing: 8) {
                        Text("Session: \(Int(vm.sessionPercent))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Weekly: \(Int(vm.weeklyPercent))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Button(action: { vm.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Refresh")

                if vm.isLoggedIn {
                    Button("Logout") {
                        vm.logout()
                        vm.loadUsagePage()
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }
            .padding(10)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // WebView showing claude.ai
            WebViewRepresentable(webView: vm.webView)
        }
        .frame(width: 800, height: 600)
    }
}

#Preview {
    SettingsView()
        .environmentObject(StatsViewModel())
}
