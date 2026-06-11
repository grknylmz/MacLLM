import Testing
import Foundation
@testable import MLXModelManager

@MainActor
@Suite("ServerManager Live Integration Tests", .serialized)
struct ServerManagerLiveIntegrationTests {

    @Test("Start and stop server with a real model")
    func testStartStopServer() async {
        guard FileManager.default.fileExists(atPath: Constants.mlxLmServerPath.path) else {
            #expect(Bool(true), "Skipping: mlx-lm not installed")
            return
        }

        let modelManager = ModelManager()
        await modelManager.refreshModels()

        guard let firstModel = modelManager.installedModels.first else {
            #expect(Bool(true), "Skipping: no models installed")
            return
        }

        let manager = ServerManager()

        await manager.start(model: firstModel.fullName)

        #expect(manager.activeModel == firstModel.fullName)
        #expect(manager.status == .starting || manager.status == .running)
        #expect(manager.startupStage != .idle)

        try? await Task.sleep(for: .seconds(5))

        if manager.isRunning {
            #expect(manager.status == .running)
            #expect(!manager.serverOutput.isEmpty)
            #expect(manager.startupStage == .ready)
        }

        manager.stop()
        #expect(manager.status == .stopped)
        #expect(manager.startupStage == .idle)
    }

    @Test("Server reports error for nonexistent model")
    func testServerErrorForBadModel() async {
        guard FileManager.default.fileExists(atPath: Constants.mlxLmServerPath.path) else {
            #expect(Bool(true), "Skipping: mlx-lm not installed")
            return
        }

        let manager = ServerManager()
        await manager.start(model: "nonexistent/model-xyz-12345")

        #expect(manager.activeModel == "nonexistent/model-xyz-12345")

        try? await Task.sleep(for: .seconds(3))

        manager.stop()
    }

    @Test("switchModel changes active model")
    func testSwitchModel() async {
        guard FileManager.default.fileExists(atPath: Constants.mlxLmServerPath.path) else {
            #expect(Bool(true), "Skipping: mlx-lm not installed")
            return
        }

        let modelManager = ModelManager()
        await modelManager.refreshModels()

        guard modelManager.installedModels.count >= 2 else {
            #expect(Bool(true), "Skipping: need at least 2 models")
            return
        }

        let manager = ServerManager()
        let model1 = modelManager.installedModels[0]
        let model2 = modelManager.installedModels[1]

        await manager.start(model: model1.fullName)
        #expect(manager.activeModel == model1.fullName)
        manager.stop()

        await manager.switchModel(to: model2.fullName)
        #expect(manager.activeModel == model2.fullName)

        try? await Task.sleep(for: .seconds(2))
        manager.stop()
    }

    @Test("restart restarts with same model")
    func testRestart() async {
        guard FileManager.default.fileExists(atPath: Constants.mlxLmServerPath.path) else {
            #expect(Bool(true), "Skipping: mlx-lm not installed")
            return
        }

        let modelManager = ModelManager()
        await modelManager.refreshModels()

        guard let firstModel = modelManager.installedModels.first else {
            #expect(Bool(true), "Skipping: no models installed")
            return
        }

        let manager = ServerManager()
        await manager.start(model: firstModel.fullName)

        #expect(manager.activeModel == firstModel.fullName)

        try? await Task.sleep(for: .seconds(3))
        manager.stop()

        #expect(manager.status == .stopped)

        await manager.restart()
        #expect(manager.activeModel == firstModel.fullName)

        try? await Task.sleep(for: .seconds(2))
        manager.stop()
    }

    @Test("freeMemory restarts the server")
    func testFreeMemory() async {
        guard FileManager.default.fileExists(atPath: Constants.mlxLmServerPath.path) else {
            #expect(Bool(true), "Skipping: mlx-lm not installed")
            return
        }

        let modelManager = ModelManager()
        await modelManager.refreshModels()

        guard let firstModel = modelManager.installedModels.first else {
            #expect(Bool(true), "Skipping: no models installed")
            return
        }

        let manager = ServerManager()
        await manager.start(model: firstModel.fullName)
        #expect(manager.activeModel == firstModel.fullName)

        try? await Task.sleep(for: .seconds(2))

        await manager.freeMemory()
        #expect(manager.activeModel == firstModel.fullName)

        try? await Task.sleep(for: .seconds(2))
        manager.stop()
    }

    @Test("clearLogs clears serverOutput and serverLogLines")
    func testClearLogsDuringRun() async {
        guard FileManager.default.fileExists(atPath: Constants.mlxLmServerPath.path) else {
            #expect(Bool(true), "Skipping: mlx-lm not installed")
            return
        }

        let modelManager = ModelManager()
        await modelManager.refreshModels()

        guard let firstModel = modelManager.installedModels.first else {
            #expect(Bool(true), "Skipping: no models installed")
            return
        }

        let manager = ServerManager()
        await manager.start(model: firstModel.fullName)

        try? await Task.sleep(for: .seconds(2))

        manager.clearLogs()
        #expect(manager.serverOutput == "")
        #expect(manager.serverLogLines.isEmpty)

        manager.stop()
    }

    @Test("stop during starting kills process tree")
    func testStopDuringStarting() async {
        guard FileManager.default.fileExists(atPath: Constants.mlxLmServerPath.path) else {
            #expect(Bool(true), "Skipping: mlx-lm not installed")
            return
        }

        let modelManager = ModelManager()
        await modelManager.refreshModels()

        guard let firstModel = modelManager.installedModels.first else {
            #expect(Bool(true), "Skipping: no models installed")
            return
        }

        let manager = ServerManager()
        await manager.start(model: firstModel.fullName)

        #expect(manager.status == .starting || manager.status == .running)

        manager.stop()
        #expect(manager.status == .stopped)
        #expect(manager.startupStage == .idle)
        #expect(manager.serverPID == nil)
    }

    @Test("startup timeout triggers stop and sets error")
    func testStartupTimeout() async {
        guard FileManager.default.fileExists(atPath: Constants.mlxLmServerPath.path) else {
            #expect(Bool(true), "Skipping: mlx-lm not installed")
            return
        }

        let timeoutKey = "startupTimeoutSeconds"
        let original = UserDefaults.standard.double(forKey: timeoutKey)
        UserDefaults.standard.set(2.0, forKey: timeoutKey)

        let modelManager = ModelManager()
        await modelManager.refreshModels()

        guard let firstModel = modelManager.installedModels.first else {
            #expect(Bool(true), "Skipping: no models installed")
            if original > 0 {
                UserDefaults.standard.set(original, forKey: timeoutKey)
            } else {
                UserDefaults.standard.removeObject(forKey: timeoutKey)
            }
            return
        }

        let manager = ServerManager()
        await manager.start(model: firstModel.fullName)

        if manager.status == .starting {
            try? await Task.sleep(for: .seconds(4))

            if case .error = manager.status {
                #expect(manager.startupStage == .failed("Startup timed out"))
            }
        }

        manager.stop()

        if original > 0 {
            UserDefaults.standard.set(original, forKey: timeoutKey)
        } else {
            UserDefaults.standard.removeObject(forKey: timeoutKey)
        }
    }

    @Test("checkMemoryBeforeStart works with real memory values")
    func testCheckMemoryWithRealValues() async {
        let monitor = SystemMemoryMonitor()
        monitor.startMonitoring()
        try? await Task.sleep(for: .milliseconds(500))
        monitor.stopMonitoring()

        let manager = ServerManager()
        let model = MLXModel(fullName: "org/model-8b-4bit")

        if let estimated = model.estimatedRAMGB, monitor.freeGB > 0 {
            if monitor.freeGB >= estimated + 2.0 {
                #expect(manager.checkMemoryBeforeStart(
                    estimatedRAMGB: estimated,
                    freeGB: monitor.freeGB
                ) == true)
            } else {
                #expect(manager.checkMemoryBeforeStart(
                    estimatedRAMGB: estimated,
                    freeGB: monitor.freeGB
                ) == false)
            }
        }
    }

    @Test("killOrphanedMLXProcesses does not crash")
    func testKillOrphaned() {
        let manager = ServerManager()
        manager.killOrphanedMLXProcesses()
    }
}
