import Foundation
import Combine

struct ClaudeCodeSession: Identifiable, Equatable {
    let id: String // PID as string
    let pid: Int
    let tty: String
    let title: String
    let status: SessionStatus
    let startTime: Date?

    enum SessionStatus: Equatable {
        case working    // Actively processing (high CPU)
        case waiting    // Just finished, needs user input (low CPU, recent JSONL activity)
        case idle       // Been sitting idle for a while

        var label: String {
            switch self {
            case .working: return "Working..."
            case .waiting: return "Needs input"
            case .idle: return "Idle"
            }
        }

        var colorName: String {
            switch self {
            case .working: return "blue"
            case .waiting: return "orange"
            case .idle: return "gray"
            }
        }
    }
}

class ClaudeCodeManager: ObservableObject {
    @Published var sessions: [ClaudeCodeSession] = []
    @Published var waitingCount: Int = 0

    private var timer: Timer?
    private var titleCache: [Int: String] = [:]
    // Cache the matched JSONL path per PID for modification time checks
    private var jsonlPathCache: [Int: URL] = [:]

    init() {
        refreshSessions()
        startPolling()
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - Public

    func refreshSessions() {
        DispatchQueue.global(qos: .userInitiated).async {
            let sessions = self.detectRunningSessions()
            let waiting = sessions.filter { $0.status == .waiting }.count
            DispatchQueue.main.async {
                self.sessions = sessions
                self.waitingCount = waiting
            }
        }
    }

    func openNewSession() {
        let script = """
        tell application "Terminal"
            do script "claude"
            activate
        end tell
        """
        DispatchQueue.global(qos: .userInitiated).async {
            self.runOsascript(script)
        }
    }

    func focusSession(_ session: ClaudeCodeSession) {
        let ttyDevice = "/dev/\(session.tty)"
        let script = """
        tell application "Terminal"
            set targetTTY to "\(ttyDevice)"
            repeat with w in windows
                repeat with t in tabs of w
                    if tty of t is targetTTY then
                        set index of w to 1
                        set selected tab of w to t
                        activate
                        return
                    end if
                end repeat
            end repeat
        end tell
        """
        DispatchQueue.global(qos: .userInitiated).async {
            self.runOsascript(script)
        }
    }

    // MARK: - Private

    private func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.refreshSessions()
        }
    }

    private func detectRunningSessions() -> [ClaudeCodeSession] {
        let pidOutput = shell("/usr/bin/pgrep -x claude")
        let pids = pidOutput
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }

        guard !pids.isEmpty else { return [] }

        var sessions: [ClaudeCodeSession] = []

        for pid in pids {
            let info = shell("/bin/ps -p \(pid) -o tty=,state=,lstart=")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !info.isEmpty else { continue }

            let parts = info.split(separator: " ", maxSplits: 6, omittingEmptySubsequences: true).map(String.init)
            guard parts.count >= 7 else { continue }

            let tty = parts[0]
            let state = parts[1]
            let startTimeStr = parts[2...6].joined(separator: " ")
            let startTime = parseStartTime(startTimeStr)

            // Get CPU usage
            let cpuStr = shell("/bin/ps -p \(pid) -o %cpu=").trimmingCharacters(in: .whitespacesAndNewlines)
            let cpu = Double(cpuStr) ?? 0.0

            // Get title and JSONL path (cached)
            let title: String
            if let cached = titleCache[pid] {
                title = cached
            } else {
                let (foundTitle, jsonlURL) = findSessionInfo(pid: pid, tty: tty, startTime: startTime)
                title = foundTitle
                titleCache[pid] = title
                if let url = jsonlURL {
                    jsonlPathCache[pid] = url
                }
            }

            // Determine status using CPU + JSONL recency
            let status: ClaudeCodeSession.SessionStatus
            if state.contains("R") || cpu > 2.0 {
                status = .working
            } else {
                // Check if the session's JSONL was modified recently
                let recentlyActive = isJsonlRecentlyModified(pid: pid)
                if recentlyActive {
                    status = .waiting
                } else {
                    status = .idle
                }
            }

            sessions.append(ClaudeCodeSession(
                id: String(pid),
                pid: pid,
                tty: tty,
                title: title,
                status: status,
                startTime: startTime
            ))
        }

        // Clean caches of dead PIDs
        let livePids = Set(pids)
        titleCache = titleCache.filter { livePids.contains($0.key) }
        jsonlPathCache = jsonlPathCache.filter { livePids.contains($0.key) }

        return sessions.sorted { ($0.startTime ?? .distantPast) > ($1.startTime ?? .distantPast) }
    }

    private func isJsonlRecentlyModified(pid: Int) -> Bool {
        guard let url = jsonlPathCache[pid] else { return false }
        // Use FileManager.attributesOfItem instead of URL.resourceValues to avoid cached values
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modDate = attrs[.modificationDate] as? Date else { return false }
        // "Recently" = modified within last 2 minutes
        return Date().timeIntervalSince(modDate) < 120
    }

    private func findSessionInfo(pid: Int, tty: String, startTime: Date?) -> (title: String, jsonlURL: URL?) {
        let projectsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")

        guard let topLevel = try? FileManager.default.contentsOfDirectory(
            at: projectsDir,
            includingPropertiesForKeys: nil
        ) else {
            return (fallbackTitle(pid: pid, tty: tty), nil)
        }

        let projectDirs = topLevel.filter {
            var isDir: ObjCBool = false
            return FileManager.default.fileExists(atPath: $0.path, isDirectory: &isDir) && isDir.boolValue
        }

        var bestMatch: (title: String, url: URL, timeDiff: TimeInterval)?

        for dir in projectDirs {
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.contentModificationDateKey, .creationDateKey]
            ) else { continue }

            let jsonlFiles = files.filter { $0.pathExtension == "jsonl" }

            for file in jsonlFiles {
                guard let attrs = try? file.resourceValues(forKeys: [.creationDateKey]),
                      let creationDate = attrs.creationDate else { continue }

                guard let processStart = startTime else { continue }
                let diff = abs(creationDate.timeIntervalSince(processStart))
                guard diff < 300 else { continue }

                if bestMatch == nil || diff < bestMatch!.timeDiff {
                    let title = readFirstUserMessage(from: file)
                    bestMatch = (title, file, diff)
                }
            }
        }

        if let match = bestMatch {
            return (match.title, match.url)
        }

        return (fallbackTitle(pid: pid, tty: tty), nil)
    }

    private func fallbackTitle(pid: Int, tty: String) -> String {
        let lsofOutput = shell("/usr/sbin/lsof -p \(pid) -a -d cwd -Fn 2>/dev/null")
        let cwd = lsofOutput
            .components(separatedBy: "\n")
            .first { $0.hasPrefix("n/") }
            .map { String($0.dropFirst()) }

        if let cwd = cwd, !cwd.isEmpty {
            let dirName = URL(fileURLWithPath: cwd).lastPathComponent
            if dirName != "taylorforward" && dirName != NSUserName() {
                return "Claude Code - \(dirName)"
            }
        }

        return "Claude Code (\(tty))"
    }

    private func readFirstUserMessage(from url: URL) -> String {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return url.deletingPathExtension().lastPathComponent
        }
        defer { handle.closeFile() }

        let data = handle.readData(ofLength: 16384)
        guard let text = String(data: data, encoding: .utf8) else {
            return url.deletingPathExtension().lastPathComponent
        }

        for line in text.components(separatedBy: "\n") {
            guard !line.isEmpty,
                  let jsonData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                continue
            }

            let type = json["type"] as? String
            let message = json["message"] as? [String: Any]
            let role = message?["role"] as? String

            if type == "user" || role == "user" {
                if let content = message?["content"] as? String, !content.isEmpty {
                    return truncateTitle(content)
                }
                if let contentArray = message?["content"] as? [[String: Any]] {
                    for item in contentArray {
                        if item["type"] as? String == "text",
                           let text = item["text"] as? String, !text.isEmpty {
                            return truncateTitle(text)
                        }
                    }
                }
            }
        }

        return url.deletingPathExtension().lastPathComponent
    }

    private func truncateTitle(_ text: String) -> String {
        let cleaned = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)
        if cleaned.count <= 50 {
            return cleaned
        }
        return String(cleaned.prefix(47)) + "..."
    }

    private func parseStartTime(_ str: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE MMM d HH:mm:ss yyyy"
        if let date = formatter.date(from: str) {
            return date
        }
        formatter.dateFormat = "EEE MMM  d HH:mm:ss yyyy"
        return formatter.date(from: str)
    }

    private func runOsascript(_ source: String) {
        let process = Process()
        let inputPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-"]
        process.standardInput = inputPipe
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            inputPipe.fileHandleForWriting.write(source.data(using: .utf8)!)
            inputPipe.fileHandleForWriting.closeFile()
            process.waitUntilExit()
        } catch {
            print("osascript error: \(error)")
        }
    }

    private func shell(_ command: String) -> String {
        let process = Process()
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]

        do {
            try process.run()
        } catch {
            print("Shell error: \(error)")
            return ""
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
