import SwiftUI

struct MenuContentView: View {
    @EnvironmentObject var vm: StatsViewModel
    @EnvironmentObject var claudeCode: ClaudeCodeManager
    var openSettingsWindow: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                Text("Claude Usage")
                    .font(.headline)
                Spacer()
                if vm.isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                } else {
                    Button(action: { vm.refresh() }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Refresh stats")
                }
            }

            Divider()

            if vm.needsLogin && !vm.isLoggedIn {
                // Prompt to log in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.exclamationmark")
                            .foregroundColor(.orange)
                        Text("Not logged in")
                            .font(.subheadline)
                    }
                    Text("Click below to log in to claude.ai")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button("Log in to Claude") {
                        openSettingsWindow()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if let error = vm.errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                // Current Session
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current session")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    HStack {
                        Text("Resets in \(vm.sessionResetsIn)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(vm.sessionPercent))% used")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    UsageBarView(percentage: vm.sessionPercent / 100)
                }

                Divider()
                    .padding(.vertical, 4)

                // Weekly Limits
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weekly limits")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    HStack {
                        Text("Resets \(vm.weeklyResetsAt)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(vm.weeklyPercent))% used")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    UsageBarView(percentage: vm.weeklyPercent / 100)
                }
            }

            Divider()

            // Claude Code Section
            claudeCodeSection

            Divider()

            // Show in menu bar toggle
            Toggle("Show % in menu bar", isOn: $vm.showPercentInMenuBar)
                .font(.caption)
                .toggleStyle(.switch)
                .controlSize(.small)

            Toggle("Launch at login", isOn: Binding(
                get: { vm.launchAtLogin },
                set: { vm.setLaunchAtLogin($0) }
            ))
                .font(.caption)
                .toggleStyle(.switch)
                .controlSize(.small)

            Divider()

            // Footer buttons
            HStack {
                Button {
                    openSettingsWindow()
                } label: {
                    Label("Settings", systemImage: "gear")
                }
                .buttonStyle(.plain)

                Spacer()

                if let lastRefresh = vm.lastRefresh {
                    Text("Updated \(lastRefresh, style: .relative) ago")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
            }
            .font(.caption)
        }
        .padding()
        .frame(width: 280)
    }

    // MARK: - Claude Code Section

    private var claudeCodeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "terminal.fill")
                    .foregroundColor(.purple)
                Text("Claude Code")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Button(action: { claudeCode.openNewSession() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("New")
                    }
                    .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
                .help("Open new Claude Code session")
            }

            if claudeCode.sessions.isEmpty {
                Text("No active sessions")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(claudeCode.sessions) { session in
                        sessionRow(session)
                    }
                }
            }
        }
    }

    private func sessionRow(_ session: ClaudeCodeSession) -> some View {
        Button(action: { claudeCode.focusSession(session) }) {
            HStack(spacing: 6) {
                // Status indicator
                statusIndicator(for: session.status)

                // Session title
                Text(session.title)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                // Status label
                Text(session.status.label)
                    .font(.caption2)
                    .foregroundColor(statusColor(for: session.status))
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .help("Click to focus this session")
    }

    @ViewBuilder
    private func statusIndicator(for status: ClaudeCodeSession.SessionStatus) -> some View {
        Circle()
            .fill(statusColor(for: status))
            .frame(width: 7, height: 7)
    }

    private func statusColor(for status: ClaudeCodeSession.SessionStatus) -> Color {
        switch status {
        case .working: return .blue
        case .waiting: return .orange
        case .idle: return .gray
        }
    }
}

struct UsageBarView: View {
    let percentage: Double

    var barColor: Color {
        if percentage >= 0.9 {
            return .red
        } else if percentage >= 0.7 {
            return .orange
        } else {
            return .blue
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 8)

                RoundedRectangle(cornerRadius: 4)
                    .fill(barColor)
                    .frame(width: max(0, geometry.size.width * CGFloat(min(percentage, 1.0))), height: 8)
            }
        }
        .frame(height: 8)
    }
}

#Preview {
    MenuContentView()
        .environmentObject(StatsViewModel())
        .environmentObject(ClaudeCodeManager())
}
