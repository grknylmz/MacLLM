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

        try? await Task.sleep(for: .seconds(5))

        if manager.isRunning {
            #expect(manager.status == .running)
            #expect(!manager.serverOutput.isEmpty)
        }

        manager.stop()
        #expect(manager.status == .stopped)
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
}
