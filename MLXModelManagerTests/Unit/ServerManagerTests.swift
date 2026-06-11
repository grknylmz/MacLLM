import Testing
import Foundation
@testable import MLXModelManager

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
    }

    @Test("statusText returns correct strings")
    func testStatusText() {
        let manager = ServerManager()

        manager.status = .stopped
        #expect(manager.statusText == "Stopped")

        manager.status = .starting
        #expect(manager.statusText == "Starting...")

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

    @Test("start sets error when mlx-lm not installed, otherwise proceeds")
    func testStartWithoutMLXLM() async {
        let manager = ServerManager()
        await manager.start(model: "org/test-model")

        #expect(manager.activeModel == "org/test-model")
        #expect(manager.serverPort == Constants.defaultServerPort)

        if !FileManager.default.fileExists(atPath: Constants.mlxLmServerPath.path) {
            #expect(manager.status == .error("mlx-lm not installed"))
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

    @Test("stop when already stopped remains stopped")
    func testStopWhenStopped() {
        let manager = ServerManager()
        manager.stop()
        #expect(manager.status == .stopped)
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
}
