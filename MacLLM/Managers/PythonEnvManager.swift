import Foundation
import Observation

@Observable
@MainActor
class PythonEnvManager {
    var isReady = false
    var isInstalling = false
    var installOutput: String = ""
    var error: String?

    private let fm = FileManager.default

    var venvExists: Bool {
        fm.fileExists(atPath: Constants.venvURL.path)
    }

    var pythonExists: Bool {
        fm.fileExists(atPath: Constants.pythonBinURL.path)
    }

    var mlxLmInstalled: Bool {
        fm.fileExists(atPath: Constants.mlxLmServerPath.path)
    }

    func setupIfNeeded() async {
        if mlxLmInstalled {
            isReady = true
            return
        }
        await fullSetup()
    }

    func fullSetup() async {
        isInstalling = true
        installOutput = ""
        error = nil

        do {
            if !fm.fileExists(atPath: Constants.appDirectory.path) {
                try fm.createDirectory(at: Constants.appDirectory, withIntermediateDirectories: true)
            }

            if !venvExists {
                installOutput += "Creating virtual environment...\n"
                let result = try await ProcessRunner.run(
                    executable: Constants.systemPythonPath,
                    arguments: ["-m", "venv", Constants.venvURL.path]
                )
                if !result.success {
                    throw EnvError.venvCreation(result.stderr)
                }
                installOutput += "Virtual environment created.\n"
            }

            installOutput += "Upgrading pip...\n"
            let _ = try await ProcessRunner.run(
                executable: Constants.pipBinURL.path,
                arguments: ["install", "--upgrade", "pip"]
            )

            installOutput += "Installing mlx-lm...\n"
            let installResult = try await ProcessRunner.run(
                executable: Constants.pipBinURL.path,
                arguments: ["install", "mlx-lm"],
                timeout: 600
            )
            if !installResult.success {
                throw EnvError.pipInstall(installResult.stderr)
            }

            installOutput += "mlx-lm installed successfully!\n"
            isReady = true
            isInstalling = false
        } catch {
            self.error = error.localizedDescription
            isInstalling = false
        }
    }

    enum EnvError: LocalizedError {
        case venvCreation(String)
        case pipInstall(String)

        var errorDescription: String? {
            switch self {
            case .venvCreation(let msg): return "Failed to create venv: \(msg)"
            case .pipInstall(let msg): return "Failed to install mlx-lm: \(msg)"
            }
        }
    }
}
