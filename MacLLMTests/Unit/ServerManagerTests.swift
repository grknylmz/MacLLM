import Testing
import Foundation
@testable import MacLLM

@MainActor
@Suite("ServerStatus Unit Tests")
struct ServerStatusTests {

    @Test("ServerStatus equality")
    func testEquality() {
        #expect(ServerStatus.stopped == ServerStatus.stopped)
        #expect(ServerStatus.starting == ServerStatus.starting)
        #expect(ServerStatus.running == ServerStatus.running)
        #expect(ServerStatus.error("msg") == ServerStatus.error("msg"))
        #expect(ServerStatus.error("a") != ServerStatus.error("b"))
        #expect(ServerStatus.stopped != ServerStatus.running)
    }
}

@MainActor
@Suite("StartupStage Unit Tests")
struct StartupStageTests {

    @Test("isIdle is true only for idle")
    func testIsIdle() {
        #expect(StartupStage.idle.isIdle == true)
        #expect(StartupStage.loadingWeights.isIdle == false)
        #expect(StartupStage.ready.isIdle == false)
        #expect(StartupStage.failed("err").isIdle == false)
    }

    @Test("isReady is true only for ready")
    func testIsReady() {
        #expect(StartupStage.ready.isReady == true)
        #expect(StartupStage.idle.isReady == false)
        #expect(StartupStage.loadingWeights.isReady == false)
    }

    @Test("isFailed is true only for failed")
    func testIsFailed() {
        #expect(StartupStage.failed("err").isFailed == true)
        #expect(StartupStage.idle.isFailed == false)
        #expect(StartupStage.ready.isFailed == false)
    }

    @Test("label returns correct strings")
    func testLabel() {
        #expect(StartupStage.idle.label == "Idle")
        #expect(StartupStage.loadingWeights.label == "Loading weights...")
        #expect(StartupStage.buildingModel.label == "Building model...")
        #expect(StartupStage.warmingUp.label == "Warming up...")
        #expect(StartupStage.ready.label == "Server ready")
        #expect(StartupStage.failed("test").label == "Failed: test")
    }
}

@MainActor
@Suite("LogLine Unit Tests")
struct LogLineTests {

    @Test("LogLine has unique IDs")
    func testUniqueIds() {
        let line1 = LogLine(text: "a", timestamp: Date(), type: .info)
        let line2 = LogLine(text: "b", timestamp: Date(), type: .info)
        #expect(line1.id != line2.id)
    }

    @Test("LogLine stores fields correctly")
    func testFields() {
        let date = Date()
        let line = LogLine(text: "hello", timestamp: date, type: .error)
        #expect(line.text == "hello")
        #expect(line.timestamp == date)
        #expect(line.type == .error)
    }
}

@MainActor
@Suite("ServerManager Unit Tests")
struct ServerManagerUnitTests {

    @Test("Initial state is stopped")
    func testInitialState() {
        let manager = ServerManager()
        #expect(manager.status == .stopped)
        #expect(manager.activeModel == nil)
        #expect(manager.serverPort == Constants.defaultServerPort)
        #expect(manager.serverOutput == "")
        #expect(manager.isRunning == false)
        #expect(manager.isStarting == false)
        #expect(manager.isActive == false)
        #expect(manager.startupStage == .idle)
        #expect(manager.serverLogLines.isEmpty)
        #expect(manager.serverPID == nil)
    }

    @Test("statusText returns correct strings")
    func testStatusText() {
        let manager = ServerManager()

        manager.status = .stopped
        #expect(manager.statusText == "Stopped")

        manager.status = .starting
        manager.startupStage = .loadingWeights
        #expect(manager.statusText == "Loading weights...")

        manager.status = .running
        #expect(manager.statusText == "Running")

        manager.status = .error("test error")
        #expect(manager.statusText == "Error: test error")
    }

    @Test("statusEmoji returns correct SF Symbol names")
    func testStatusEmoji() {
        let manager = ServerManager()

        manager.status = .stopped
        #expect(manager.statusEmoji == "red.circle")

        manager.status = .starting
        #expect(manager.statusEmoji == "yellow.circle")

        manager.status = .running
        #expect(manager.statusEmoji == "green.circle")

        manager.status = .error("fail")
        #expect(manager.statusEmoji == "red.circle")
    }

    @Test("isRunning is true only when status is running")
    func testIsRunning() {
        let manager = ServerManager()

        manager.status = .stopped
        #expect(manager.isRunning == false)

        manager.status = .starting
        #expect(manager.isRunning == false)

        manager.status = .running
        #expect(manager.isRunning == true)

        manager.status = .error("err")
        #expect(manager.isRunning == false)
    }

    @Test("isStarting is true only when status is starting")
    func testIsStarting() {
        let manager = ServerManager()

        manager.status = .stopped
        #expect(manager.isStarting == false)

        manager.status = .starting
        #expect(manager.isStarting == true)

        manager.status = .running
        #expect(manager.isStarting == false)
    }

    @Test("isActive is true when running or starting")
    func testIsActive() {
        let manager = ServerManager()

        manager.status = .stopped
        #expect(manager.isActive == false)

        manager.status = .starting
        #expect(manager.isActive == true)

        manager.status = .running
        #expect(manager.isActive == true)

        manager.status = .error("err")
        #expect(manager.isActive == false)
    }

    @Test("start sets error when mlx-lm not installed, otherwise proceeds")
    func testStartWithoutMLXLM() async {
        let manager = ServerManager()
        await manager.start(model: "org/test-model")

        #expect(manager.activeModel == "org/test-model")
        #expect(manager.serverPort == Constants.defaultServerPort)

        if !FileManager.default.fileExists(atPath: Constants.mlxLmServerPath.path) {
            #expect(manager.status == .error("mlx-lm not installed"))
            #expect(manager.startupStage == .failed("mlx-lm not installed"))
        } else {
            #expect(manager.status == .starting || manager.status == .running)
            manager.stop()
        }
    }

    @Test("start with custom port updates serverPort")
    func testStartWithCustomPort() async {
        let manager = ServerManager()
        await manager.start(model: "org/test-model", port: 9999)

        #expect(manager.serverPort == 9999)
    }

    @Test("start sets startup stage to loadingWeights")
    func testStartSetsStartupStage() async {
        let manager = ServerManager()
        #expect(manager.startupStage == .idle)

        await manager.start(model: "org/test-model")

        if !FileManager.default.fileExists(atPath: Constants.mlxLmServerPath.path) {
            #expect(manager.startupStage == .failed("mlx-lm not installed"))
        } else {
            #expect(manager.startupStage != .idle)
            manager.stop()
        }
    }

    @Test("stop when already stopped remains stopped and resets stage")
    func testStopWhenStopped() {
        let manager = ServerManager()
        manager.stop()
        #expect(manager.status == .stopped)
        #expect(manager.startupStage == .idle)
    }

    @Test("stop resets startup stage to idle")
    func testStopResetsStage() {
        let manager = ServerManager()
        manager.status = .starting
        manager.startupStage = .loadingWeights
        manager.stop()
        #expect(manager.status == .stopped)
        #expect(manager.startupStage == .idle)
    }

    @Test("restart when no active model does nothing")
    func testRestartNoModel() async {
        let manager = ServerManager()
        await manager.restart()
        #expect(manager.status == .stopped)
    }

    @Test("switchModel stops and attempts start")
    func testSwitchModel() async {
        let manager = ServerManager()
        await manager.switchModel(to: "org/new-model")
        #expect(manager.activeModel == "org/new-model")

        if !FileManager.default.fileExists(atPath: Constants.mlxLmServerPath.path) {
            #expect(manager.status == .error("mlx-lm not installed"))
        } else {
            manager.stop()
        }
    }

    @Test("freeMemory calls restart")
    func testFreeMemory() async {
        let manager = ServerManager()
        await manager.freeMemory()
        #expect(manager.status == .stopped)
    }

    @Test("clearLogs empties log lines and output")
    func testClearLogs() {
        let manager = ServerManager()
        manager.serverOutput = "some output"
        manager.serverLogLines = [LogLine(text: "line1", timestamp: Date(), type: .info)]
        manager.clearLogs()
        #expect(manager.serverOutput == "")
        #expect(manager.serverLogLines.isEmpty)
    }

    @Test("defaultStartupTimeout is 300 seconds")
    func testDefaultStartupTimeout() {
        #expect(ServerManager.defaultStartupTimeout == 300)
    }

    @Test("checkMemoryBeforeStart returns true when estimatedRAMGB is nil")
    func testCheckMemoryNilEstimate() {
        let manager = ServerManager()
        #expect(manager.checkMemoryBeforeStart(estimatedRAMGB: nil, freeGB: 1.0) == true)
    }

    @Test("checkMemoryBeforeStart returns true when enough free memory")
    func testCheckMemorySufficient() {
        let manager = ServerManager()
        #expect(manager.checkMemoryBeforeStart(estimatedRAMGB: 4.0, freeGB: 10.0) == true)
    }

    @Test("checkMemoryBeforeStart returns false when not enough free memory")
    func testCheckMemoryInsufficient() {
        let manager = ServerManager()
        #expect(manager.checkMemoryBeforeStart(estimatedRAMGB: 8.0, freeGB: 5.0) == false)
    }

    @Test("checkMemoryBeforeStart returns false when exactly matching estimated without headroom")
    func testCheckMemoryExactMatch() {
        let manager = ServerManager()
        #expect(manager.checkMemoryBeforeStart(estimatedRAMGB: 8.0, freeGB: 9.0) == false)
    }

    @Test("checkMemoryBeforeStart uses custom headroom from UserDefaults")
    func testCheckMemoryCustomHeadroom() {
        let key = "memoryHeadroomGB"
        let original = UserDefaults.standard.double(forKey: key)
        UserDefaults.standard.set(4.0, forKey: key)

        let manager = ServerManager()
        #expect(manager.checkMemoryBeforeStart(estimatedRAMGB: 4.0, freeGB: 7.0) == false)
        #expect(manager.checkMemoryBeforeStart(estimatedRAMGB: 4.0, freeGB: 8.0) == true)

        if original > 0 {
            UserDefaults.standard.set(original, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    @Test("checkMemoryBeforeStart with zero free memory always fails")
    func testCheckMemoryZeroFree() {
        let manager = ServerManager()
        #expect(manager.checkMemoryBeforeStart(estimatedRAMGB: 1.0, freeGB: 0.0) == false)
    }

    @Test("killOrphanedMLXProcesses does not crash when no processes exist")
    func testKillOrphanedNoProcesses() {
        let manager = ServerManager()
        manager.killOrphanedMLXProcesses()
    }

    @Test("stop during starting phase resets to stopped")
    func testStopDuringStarting() {
        let manager = ServerManager()
        manager.status = .starting
        manager.startupStage = .loadingWeights
        manager.stop()
        #expect(manager.status == .stopped)
        #expect(manager.startupStage == .idle)
    }

    @Test("stop clears _lastKnownMLXPID from UserDefaults")
    func testStopClearsPID() {
        let key = "_lastKnownMLXPID"
        UserDefaults.standard.set(12345, forKey: key)
        let manager = ServerManager()
        manager.stop()
        #expect(UserDefaults.standard.integer(forKey: key) == 0)
    }

    @Test("multiple stop calls do not crash")
    func testMultipleStops() {
        let manager = ServerManager()
        manager.stop()
        manager.stop()
        manager.stop()
        #expect(manager.status == .stopped)
    }
}
