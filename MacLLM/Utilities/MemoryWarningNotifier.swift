import Foundation
import UserNotifications

@MainActor
class MemoryWarningNotifier {
    private var lastNotificationTime: Date?
    private let minimumInterval: TimeInterval = 300
    private var previousLevel: MemoryWarningLevel = .normal

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func checkAndNotify(warningLevel: MemoryWarningLevel, isServerRunning: Bool) {
        guard isServerRunning else {
            previousLevel = .normal
            return
        }

        if warningLevel == .normal {
            previousLevel = .normal
            return
        }

        guard previousLevel == .normal else { return }
        previousLevel = warningLevel

        let now = Date()
        if let last = lastNotificationTime, now.timeIntervalSince(last) < minimumInterval {
            return
        }
        lastNotificationTime = now

        let content = UNMutableNotificationContent()
        if warningLevel == .critical {
            content.title = "Memory Critical"
            content.body = "System memory usage is critically high. Consider freeing memory to prevent crashes."
        } else {
            content.title = "Memory Warning"
            content.body = "System memory usage is high. You may want to free memory from MacLLM."
        }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "macllm-memory-warning",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { _ in }
    }
}
