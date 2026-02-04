import Foundation
import UserNotifications

class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    @Published var notificationsEnabled: Bool = false

    // Track which thresholds have already fired so we don't spam
    private var firedSessionThresholds: Set<Int> = []
    private var firedWeeklyThresholds: Set<Int> = []
    private var firedSessionContextWarning: Bool = false

    private let thresholds = [50, 75, 90]

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.notificationsEnabled = granted
            }
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }

    // MARK: - Check Thresholds

    func checkUsageThresholds(sessionPercent: Double, weeklyPercent: Double, sessionResetsIn: String) {
        guard notificationsEnabled else { return }

        let sessionInt = Int(sessionPercent)
        let weeklyInt = Int(weeklyPercent)

        // Check session thresholds
        for threshold in thresholds {
            if sessionInt >= threshold && !firedSessionThresholds.contains(threshold) {
                firedSessionThresholds.insert(threshold)
                sendNotification(
                    title: "Session Usage at \(threshold)%",
                    body: "Your current Claude session is \(sessionInt)% used. Resets in \(sessionResetsIn).",
                    identifier: "session-\(threshold)"
                )
            }
        }

        // Check weekly thresholds
        for threshold in thresholds {
            if weeklyInt >= threshold && !firedWeeklyThresholds.contains(threshold) {
                firedWeeklyThresholds.insert(threshold)
                sendNotification(
                    title: "Weekly Usage at \(threshold)%",
                    body: "Your weekly Claude usage is \(weeklyInt)% used.",
                    identifier: "weekly-\(threshold)"
                )
            }
        }

        // Session context running low: fire at 80%+ session usage
        if sessionInt >= 80 && !firedSessionContextWarning {
            firedSessionContextWarning = true
            sendNotification(
                title: "Session Context Running Low",
                body: "Your session context is \(sessionInt)% used. Consider starting a new session soon.",
                identifier: "session-context-low"
            )
        }

        // Reset thresholds if usage drops (e.g. after a reset)
        if sessionInt < 50 {
            firedSessionThresholds.removeAll()
            firedSessionContextWarning = false
        }
        if weeklyInt < 50 {
            firedWeeklyThresholds.removeAll()
        }
    }

    // MARK: - Send Notification

    private func sendNotification(title: String, body: String, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to deliver notification: \(error)")
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    // Show notifications even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
