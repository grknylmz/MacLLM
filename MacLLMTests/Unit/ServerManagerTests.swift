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
        #expect(StartupStage.buildingModel.isReady == false)
        #expect(StartupStage.warmingUp.isReady == false)
        #expect(StartupStage.failed("err").isReady == false)
    }

    @Test("isFailed is true only for failed")
    func testIsFailed() {
        #expect(StartupStage.failed("err").isFailed == true)
        #expect(StartupStage.idle.isFailed == false)
        #expect(StartupStage.ready.isFailed == false)
        #expect(StartupStage.loadingWeights.isFailed == false)
        #expect(StartupStage.buildingModel.isFailed == false)
        #expect(StartupStage.warmingUp.isFailed == false)
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

    @Test("equality works")
    func testEquality() {
        #expect(StartupStage.idle == StartupStage.idle)
        #expect(StartupStage.loadingWeights == StartupStage.loadingWeights)
        #expect(StartupStage.ready == StartupStage.ready)
        #expect(StartupStage.failed("a") == StartupStage.failed("a"))
        #expect(StartupStage.failed("a") != StartupStage.failed("b"))
        #expect(StartupStage.idle != StartupStage.ready)
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

@Suite("LogLineType Unit Tests")
struct LogLineTypeTests {

    @Test("LogLineType has all cases")
    func testAllCases() {
        let allTypes: [LogLineType] = [.info, .warning, .error, .debug]
        #expect(allTypes.count == 4)
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

    @Test("statusText uses startupStage label when starting")
    func testStatusTextStartupStages() {
        let manager = ServerManager()
        manager.status = .starting

        manager.startupStage = .buildingModel
        #expect(manager.statusText == "Building model...")

        manager.startupStage = .warmingUp
        #expect(manager.statusText == "Warming up...")

        manager.startupStage = .ready
        #expect(manager.statusText == "Server ready")

        manager.startupStage = .failed("oops")
        #expect(manager.statusText == "Failed: oops")
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

    @Test("start does not proceed when already running")
    func testStartDoesNotProceedWhenRunning() async {
        let manager = ServerManager()
        manager.status = .running
        manager.activeModel = "org/existing"
        await manager.start(model: "org/new")
        #expect(manager.activeModel == "org/existing")
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

    @Test("checkMemoryBeforeStart with zero estimated but headroom fails")
    func testCheckMemoryZeroEstimated() {
        let manager = ServerManager()
        #expect(manager.checkMemoryBeforeStart(estimatedRAMGB: 0.0, freeGB: 1.0) == false)
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

    // MARK: - processOutput / updateStartupStage / lineType

    @Test("processOutput appends to serverOutput")
    func testProcessOutputAppends() {
        let manager = ServerManager()
        manager.status = .starting
        manager.startupStage = .loadingWeights

        manager.processOutput("line 1\n")
        manager.processOutput("line 2\n")

        #expect(manager.serverOutput == "line 1\nline 2\n")
    }

    @Test("processOutput creates log lines for non-empty content")
    func testProcessOutputCreatesLogLines() {
        let manager = ServerManager()
        manager.status = .starting
        manager.startupStage = .loadingWeights

        manager.processOutput("hello\nworld\n")

        #expect(manager.serverLogLines.count == 2)
        #expect(manager.serverLogLines[0].text == "hello")
        #expect(manager.serverLogLines[1].text == "world")
    }

    @Test("processOutput skips empty lines")
    func testProcessOutputSkipsEmptyLines() {
        let manager = ServerManager()
        manager.status = .starting
        manager.startupStage = .loadingWeights

        manager.processOutput("hello\n\n  \nworld\n")

        #expect(manager.serverLogLines.count == 2)
    }

    @Test("processOutput detects uvicorn running and sets status to running")
    func testProcessOutputDetectsUvicornRunning() {
        let manager = ServerManager()
        manager.status = .starting
        manager.startupStage = .loadingWeights

        manager.processOutput("INFO: Uvicorn running on http://0.0.0.0:8080\n")

        #expect(manager.status == .running)
        #expect(manager.startupStage == .ready)
    }

    @Test("processOutput detects 'running on http' and sets status to running")
    func testProcessOutputDetectsRunningOnHttp() {
        let manager = ServerManager()
        manager.status = .starting
        manager.startupStage = .loadingWeights

        manager.processOutput("Running on http://127.0.0.1:8080\n")

        #expect(manager.status == .running)
        #expect(manager.startupStage == .ready)
    }

    @Test("processOutput detects error and sets failed stage")
    func testProcessOutputDetectsError() {
        let manager = ServerManager()
        manager.status = .starting
        manager.startupStage = .loadingWeights

        manager.processOutput("Traceback (most recent call last):\n  File \"test.py\"\n")

        #expect(manager.startupStage.isFailed)
    }

    @Test("processOutput detects exception and sets failed stage")
    func testProcessOutputDetectsException() {
        let manager = ServerManager()
        manager.status = .starting
        manager.startupStage = .loadingWeights

        manager.processOutput("RuntimeError: something went wrong\n")

        #expect(manager.startupStage.isFailed)
    }

    @Test("processOutput detects building model stage")
    func testProcessOutputDetectsBuildingModel() {
        let manager = ServerManager()
        manager.status = .starting
        manager.startupStage = .loadingWeights

        manager.processOutput("Building model...\n")

        #expect(manager.startupStage == .buildingModel)
    }

    @Test("processOutput detects warming up stage")
    func testProcessOutputDetectsWarmingUp() {
        let manager = ServerManager()
        manager.status = .starting
        manager.startupStage = .loadingWeights

        manager.processOutput("Warming up the model\n")

        #expect(manager.startupStage == .warmingUp)
    }

    @Test("processOutput does not change stage when status is not starting")
    func testProcessOutputNoChangeWhenNotStarting() {
        let manager = ServerManager()
        manager.status = .running
        manager.startupStage = .ready

        manager.processOutput("Building model...\n")

        #expect(manager.startupStage == .ready)
    }

    @Test("processOutput error does not override non-starting status")
    func testProcessOutputErrorOnlyWhenStarting() {
        let manager = ServerManager()
        manager.status = .running
        manager.startupStage = .ready

        manager.processOutput("Error: something bad\n")

        #expect(manager.startupStage == .ready)
        #expect(manager.status == .running)
    }

    @Test("processOutput truncates log buffer to maxLogLines")
    func testProcessOutputTruncatesLogBuffer() {
        let manager = ServerManager()
        manager.status = .starting
        manager.startupStage = .loadingWeights

        for i in 0..<250 {
            manager.processOutput("line \(i)\n")
        }

        #expect(manager.serverLogLines.count <= 200)
    }

    @Test("processOutput detects 'compile' keyword for building model")
    func testProcessOutputDetectsCompile() {
        let manager = ServerManager()
        manager.status = .starting
        manager.startupStage = .loadingWeights

        manager.processOutput("compile model graph\n")

        #expect(manager.startupStage == .buildingModel)
    }

    @Test("processOutput detects 'fuse' keyword for building model")
    func testProcessOutputDetectsFuse() {
        let manager = ServerManager()
        manager.status = .starting
        manager.startupStage = .loadingWeights

        manager.processOutput("fuse layers\n")

        #expect(manager.startupStage == .buildingModel)
    }

    @Test("processOutput detects 'serving' keyword for warming up")
    func testProcessOutputDetectsServing() {
        let manager = ServerManager()
        manager.status = .starting
        manager.startupStage = .loadingWeights

        manager.processOutput("Serving model now\n")

        #expect(manager.startupStage == .warmingUp)
    }

    @Test("processOutput detects 'load weights' for loadingWeights")
    func testProcessOutputDetectsLoadWeights() {
        let manager = ServerManager()
        manager.status = .starting
        manager.startupStage = .loadingWeights

        manager.processOutput("Loading model weights from checkpoint\n")

        #expect(manager.startupStage == .loadingWeights)
    }

    // MARK: - lineType

    @Test("lineType detects error keywords")
    func testLineTypeError() {
        let manager = ServerManager()
        manager.status = .starting
        manager.startupStage = .loadingWeights

        manager.processOutput("Error: failed to load\n")
        #expect(manager.serverLogLines.last?.type == .error)

        manager.processOutput("Traceback details here\n")
        #expect(manager.serverLogLines.last?.type == .error)

        manager.processOutput("Exception occurred\n")
        #expect(manager.serverLogLines.last?.type == .error)

        manager.processOutput("Process failed\n")
        #expect(manager.serverLogLines.last?.type == .error)
    }

    @Test("lineType detects warning keywords")
    func testLineTypeWarning() {
        let manager = ServerManager()
        manager.status = .starting
        manager.startupStage = .loadingWeights

        manager.processOutput("Warning: low memory\n")
        #expect(manager.serverLogLines.last?.type == .warning)

        manager.processOutput("Warn: deprecated API\n")
        #expect(manager.serverLogLines.last?.type == .warning)
    }

    @Test("lineType detects debug keyword")
    func testLineTypeDebug() {
        let manager = ServerManager()
        manager.status = .starting
        manager.startupStage = .loadingWeights

        manager.processOutput("Debug: verbose output\n")
        #expect(manager.serverLogLines.last?.type == .debug)
    }

    @Test("lineType defaults to info")
    func testLineTypeInfo() {
        let manager = ServerManager()
        manager.status = .starting
        manager.startupStage = .loadingWeights

        manager.processOutput("Normal log line\n")
        #expect(manager.serverLogLines.last?.type == .info)
    }
}
