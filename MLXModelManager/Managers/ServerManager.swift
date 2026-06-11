import Foundation
import Observation

enum ServerStatus: Equatable {
    case stopped
    case starting
    case running
    case error(String)
}

@Observable
@MainActor
class ServerManager {
    var status: ServerStatus = .stopped
    var activeModel: String?
    var serverPort: Int = Constants.defaultServerPort
    var serverOutput: String = ""

    private var process: Process?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?

    var isRunning: Bool {
        if case .running = status { return true }
        return false
    }

    var statusText: String {
        switch status {
        case .stopped: return "Stopped"
        case .starting: return "Starting..."
        case .running: return "Running"
        case .error(let msg): return "Error: \(msg)"
        }
    }

    var statusEmoji: String {
        switch status {
        case .stopped: return "red.circle"
        case .starting: return "yellow.circle"
        case .running: return "green.circle"
        case .error: return "red.circle"
        }
    }

    func start(model: String, port: Int? = nil) async {
        guard !isRunning else { return }

        let targetPort = port ?? serverPort
        activeModel = model
        serverPort = targetPort
        status = .starting
        serverOutput = ""

        guard FileManager.default.fileExists(atPath: Constants.mlxLmServerPath.path) else {
            status = .error("mlx-lm not installed")
            return
        }

        let proc = Process()
        let outPipe = Pipe()
        let errPipe = Pipe()

        proc.executableURL = Constants.mlxLmServerPath
        proc.arguments = ["--model", model, "--port", "\(targetPort)"]
        proc.standardOutput = outPipe
        proc.standardError = errPipe
        proc.standardInput = FileHandle.nullDevice

        let env = ProcessInfo.processInfo.environment
        proc.environment = env

        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                Task { @MainActor [weak self] in
                    self?.serverOutput += str
                    if str.contains("Uvicorn running on") || str.contains("Running on") {
                        self?.status = .running
                    }
                }
            }
        }

        errPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                Task { @MainActor [weak self] in
                    self?.serverOutput += str
                    if !(self?.status == .running) && (str.contains("Uvicorn running on") || str.contains("Running on")) {
                        self?.status = .running
                    }
                }
            }
        }

        proc.terminationHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if case .starting = self.status {
                    self.status = .stopped
                } else if case .running = self.status {
                    self.status = .stopped
                }
                self.process = nil
            }
        }

        self.process = proc
        self.stdoutPipe = outPipe
        self.stderrPipe = errPipe

        do {
            try proc.run()
        } catch {
            status = .error(error.localizedDescription)
            self.process = nil
        }
    }

    func stop() {
        guard let proc = process, proc.isRunning else {
            status = .stopped
            return
        }
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        proc.terminate()
        process = nil
        status = .stopped
    }

    func restart() async {
        let model = activeModel
        let port = serverPort
        stop()
        if let model {
            await start(model: model, port: port)
        }
    }

    func switchModel(to model: String) async {
        stop()
        await start(model: model, port: serverPort)
    }
}
