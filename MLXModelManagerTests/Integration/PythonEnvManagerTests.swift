import Testing
import Foundation
@testable import MLXModelManager

@MainActor
@Suite("PythonEnvManager Integration Tests", .serialized)
struct PythonEnvManagerIntegrationTests {

    private let fm = FileManager.default

    private func cleanupTestEnv(at path: URL) {
        try? fm.removeItem(at: path)
    }

    @Test("setupIfNeeded skips when mlx-lm already appears installed")
    func testSetupSkipsWhenReady() async {
        let manager = PythonEnvManager()
        manager.isReady = true
        await manager.setupIfNeeded()
        #expect(manager.isReady == true)
        #expect(manager.isInstalling == false)
    }

    @Test("fullSetup creates venv and installs mlx-lm")
    func testFullSetup() async {
        let manager = PythonEnvManager()
        await manager.fullSetup()

        #expect(manager.isInstalling == false)
        if let error = manager.error {
            #expect(manager.isReady == false)
            Issue.record("Setup failed: \(error)")
        } else {
            #expect(manager.isReady == true)
        }

        #expect(fm.fileExists(atPath: Constants.venvURL.path))
        #expect(fm.fileExists(atPath: Constants.pythonBinURL.path))
        #expect(fm.fileExists(atPath: Constants.mlxLmServerPath.path))
    }

    @Test("venvExists is accurate")
    func testVenvExists() {
        let manager = PythonEnvManager()
        if fm.fileExists(atPath: Constants.venvURL.path) {
            #expect(manager.venvExists == true)
        }
    }

    @Test("pythonExists is accurate after setup")
    func testPythonExists() async {
        let manager = PythonEnvManager()
        if !manager.mlxLmInstalled {
            await manager.fullSetup()
        }
        #expect(manager.pythonExists == true)
    }

    @Test("mlxLmInstalled is accurate after setup")
    func testMlxLmInstalled() async {
        let manager = PythonEnvManager()
        if !manager.mlxLmInstalled {
            await manager.fullSetup()
        }
        #expect(manager.mlxLmInstalled == true)
    }

    @Test("installOutput contains expected messages after setup")
    func testInstallOutputMessages() async {
        let manager = PythonEnvManager()
        if !manager.mlxLmInstalled {
            await manager.fullSetup()
        }

        if manager.isReady {
            #expect(manager.installOutput.contains("mlx-lm installed successfully"))
        }
    }
}
