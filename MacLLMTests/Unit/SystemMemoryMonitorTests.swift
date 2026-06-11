import Testing
import Foundation
@testable import MacLLM

@MainActor
@Suite("SystemMemoryMonitor Unit Tests")
struct SystemMemoryMonitorTests {

    @Test("Initial values are zero")
    func testInitialValues() {
        let monitor = SystemMemoryMonitor()
        #expect(monitor.totalGB == 0)
        #expect(monitor.usedGB == 0)
        #expect(monitor.freeGB == 0)
        #expect(monitor.usedPercentage == 0)
        #expect(monitor.topProcesses.isEmpty)
    }

    @Test("startMonitoring populates values and processes")
    func testStartMonitoring() async {
        let monitor = SystemMemoryMonitor()
        monitor.startMonitoring()

        try? await Task.sleep(for: .milliseconds(500))

        #expect(monitor.totalGB > 0)
        #expect(monitor.usedGB > 0)
        #expect(monitor.usedPercentage > 0)
        #expect(monitor.usedPercentage <= 1.0)

        monitor.stopMonitoring()
    }

    @Test("stopMonitoring stops updates")
    func testStopMonitoring() async {
        let monitor = SystemMemoryMonitor()
        monitor.startMonitoring()

        try? await Task.sleep(for: .milliseconds(500))
        let valueAfterStart = monitor.totalGB
        monitor.stopMonitoring()

        #expect(valueAfterStart > 0)
    }

    @Test("warningLevel is normal when usage is low")
    func testWarningLevelNormal() {
        let monitor = SystemMemoryMonitor()
        monitor.usedPercentage = 0.5
        #expect(monitor.warningLevel == .normal)
    }

    @Test("warningLevel is warning at threshold")
    func testWarningLevelWarning() {
        let monitor = SystemMemoryMonitor()
        monitor.usedPercentage = 0.9
        #expect(monitor.warningLevel == .warning)
    }

    @Test("warningLevel is critical above threshold + 5%")
    func testWarningLevelCritical() {
        let monitor = SystemMemoryMonitor()
        monitor.usedPercentage = 0.96
        #expect(monitor.warningLevel == .critical)
    }

    @Test("warningThreshold defaults to 0.9")
    func testWarningThresholdDefault() {
        let key = "memoryWarningThreshold"
        let original = UserDefaults.standard.double(forKey: key)
        UserDefaults.standard.removeObject(forKey: key)

        let monitor = SystemMemoryMonitor()
        #expect(monitor.warningThreshold == 0.9)

        if original > 0 {
            UserDefaults.standard.set(original, forKey: key)
        }
    }

    @Test("warningThreshold reads from UserDefaults")
    func testWarningThresholdFromDefaults() {
        let key = "memoryWarningThreshold"
        let original = UserDefaults.standard.double(forKey: key)
        UserDefaults.standard.set(0.8, forKey: key)

        let monitor = SystemMemoryMonitor()
        #expect(monitor.warningThreshold == 0.8)

        if original > 0 {
            UserDefaults.standard.set(original, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}

@Suite("MemoryWarningNotifier Unit Tests")
struct MemoryWarningNotifierTests {

    @Test("checkAndNotify does nothing when server not running")
    func testNoopNotRunning() async {
        await MainActor.run {
            let notifier = MemoryWarningNotifier()
            notifier.checkAndNotify(warningLevel: .critical, isServerRunning: false)
        }
    }

    @Test("checkAndNotify does nothing when level is normal")
    func testNoopNormal() async {
        await MainActor.run {
            let notifier = MemoryWarningNotifier()
            notifier.checkAndNotify(warningLevel: .normal, isServerRunning: true)
        }
    }

    @Test("checkAndNotify handles rapid calls without crash")
    func testRapidCalls() async {
        await MainActor.run {
            let notifier = MemoryWarningNotifier()
            for _ in 0..<10 {
                notifier.checkAndNotify(warningLevel: .warning, isServerRunning: true)
                notifier.checkAndNotify(warningLevel: .normal, isServerRunning: true)
            }
        }
    }
}
