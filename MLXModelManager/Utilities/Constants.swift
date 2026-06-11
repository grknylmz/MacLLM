import Foundation

enum Constants {
    static let appDirectoryName = ".mlx-manager"
    static let venvDirectoryName = "venv"
    static let defaultServerPort = 8080
    static let hfCachePath = ".cache/huggingface/hub"
    static let hfModelsPrefix = "models--"

    static var appDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(appDirectoryName)
    }

    static var venvURL: URL {
        appDirectory.appendingPathComponent(venvDirectoryName)
    }

    static var pythonBinURL: URL {
        venvURL.appendingPathComponent("bin/python3")
    }

    static var pipBinURL: URL {
        venvURL.appendingPathComponent("bin/pip3")
    }

    static var mlxLmServerPath: URL {
        venvURL.appendingPathComponent("bin/mlx_lm.server")
    }

    static var hfCacheURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(hfCachePath)
    }

    static var systemPythonPath: String {
        "/usr/bin/python3"
    }
}
