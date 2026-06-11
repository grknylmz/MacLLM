import Foundation
import Observation

enum StartupStage: Equatable {
    case idle
    case loadingWeights
    case buildingModel
    case warmingUp
    case ready
    case failed(String)

    var isIdle: Bool {
        if case .idle = self { return true }
        return false
    }

    var isReady: Bool {
        if case .ready = self { return true }
        return false
    }

    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }

    var label: String {
        switch self {
        case .idle: return "Idle"
        case .loadingWeights: return "Loading weights..."
        case .buildingModel: return "Building model..."
        case .warmingUp: return "Warming up..."
        case .ready: return "Server ready"
        case .failed(let msg): return "Failed: \(msg)"
        }
    }
}

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
    var serverLogLines: [LogLine] = []
    var startupStage: StartupStage = .idle
    @ObservationIgnored private var logBuffer: [LogLine] = []
    private static let maxLogLines = 200
    static let defaultStartupTimeout: TimeInterval = 300

    private var process: Process?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    @ObservationIgnored private var startupTimeoutTask: Task<Void, Never>?

    var serverPID: Int32? {
        process?.processIdentifier
    }

    var isRunning: Bool {
        if case .running = status { return true }
        return false
    }

    var isStarting: Bool {
        if case .starting = status { return true }
        return false
    }

    var isActive: Bool {
        isRunning || isStarting
    }

    var statusText: String {
        switch status {
        case .stopped: return "Stopped"
        case .starting: return startupStage.label
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
        startupStage = .loadingWeights
        serverOutput = ""
        serverLogLines = []
        logBuffer = []

        guard FileManager.default.fileExists(atPath: Constants.mlxLmServerPath.path) else {
            status = .error("mlx-lm not installed")
            startupStage = .failed("mlx-lm not installed")
            return
        }

        let proc = Process()
        let outPipe = Pipe()
        let errPipe = Pipe()

        proc.executableURL = Constants.mlxLmServerPath
        var arguments = ["--model", model, "--port", "\(targetPort)"]

        let cacheLimit = UserDefaults.standard.double(forKey: "cacheLimitGB")
        if cacheLimit > 0 {
            arguments += ["--cache-limit-gb", "\(Int(cacheLimit))"]
        }

        proc.arguments = arguments
        proc.standardOutput = outPipe
        proc.standardError = errPipe
        proc.standardInput = FileHandle.nullDevice

        let env = ProcessInfo.processInfo.environment
        proc.environment = env

        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                Task { @MainActor [weak self] in
                    self?.processOutput(str)
                }
            }
        }

        errPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                Task { @MainActor [weak self] in
                    self?.processOutput(str)
                }
            }
        }

        proc.terminationHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if case .starting = self.status {
                    self.status = .stopped
                    self.startupStage = .idle
                } else if case .running = self.status {
                    self.status = .stopped
                    self.startupStage = .idle
                }
                self.process = nil
            }
        }

        self.process = proc
        self.stdoutPipe = outPipe
        self.stderrPipe = errPipe

        do {
            try proc.run()
            UserDefaults.standard.set(Int(proc.processIdentifier), forKey: "_lastKnownMLXPID")
            startStartupTimeout()
        } catch {
            status = .error(error.localizedDescription)
            startupStage = .failed(error.localizedDescription)
            self.process = nil
        }
    }

    func stop() {
        startupTimeoutTask?.cancel()
        startupTimeoutTask = nil

        guard let proc = process else {
            status = .stopped
            startupStage = .idle
            UserDefaults.standard.removeObject(forKey: "_lastKnownMLXPID")
            return
        }

        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil

        if proc.isRunning {
            let pid = proc.processIdentifier
            killProcessTree(pid: pid)
        }

        process = nil
        status = .stopped
        startupStage = .idle
        UserDefaults.standard.removeObject(forKey: "_lastKnownMLXPID")
    }

    func killOrphanedMLXProcesses() {
        let task = Process()
        let pipe = Pipe()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        task.arguments = ["-f", "mlx_lm"]
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        task.standardInput = FileHandle.nullDevice

        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            guard let output = String(data: data, encoding: .utf8) else { return }
            let pids = output.split(separator: "\n").compactMap { Int32($0.trimmingCharacters(in: .whitespaces)) }
            for pid in pids {
                killProcessTree(pid: pid)
            }
        } catch {}
    }

    private func killProcessTree(pid: Int32) {
        let childTask = Process()
        let childPipe = Pipe()
        childTask.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        childTask.arguments = ["-P", "\(pid)"]
        childTask.standardOutput = childPipe
        childTask.standardError = FileHandle.nullDevice
        childTask.standardInput = FileHandle.nullDevice

        var childPids: [Int32] = []
        do {
            try childTask.run()
            let data = childPipe.fileHandleForReading.readDataToEndOfFile()
            childTask.waitUntilExit()
            if let output = String(data: data, encoding: .utf8) {
                childPids = output.split(separator: "\n").compactMap { Int32($0.trimmingCharacters(in: .whitespaces)) }
            }
        } catch {}

        for childPid in childPids {
            killProcessTree(pid: childPid)
        }

        kill(pid, SIGTERM)

        Thread.sleep(forTimeInterval: 0.5)
        if kill(pid, 0) == 0 {
            kill(pid, SIGKILL)
        }
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

    func freeMemory() async {
        await restart()
    }

    func clearLogs() {
        serverLogLines = []
        logBuffer = []
        serverOutput = ""
    }

    private func startStartupTimeout() {
        startupTimeoutTask?.cancel()
        let timeout = UserDefaults.standard.double(forKey: "startupTimeoutSeconds")
        let timeoutInterval = timeout > 0 ? timeout : Self.defaultStartupTimeout

        startupTimeoutTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(timeoutInterval))
            guard !Task.isCancelled else { return }
            guard case .starting = self.status else { return }
            serverOutput += "\n[MLX Manager] Startup timed out after \(Int(timeoutInterval))s — killing process\n"
            self.stop()
            self.status = .error("Startup timed out after \(Int(timeoutInterval))s")
            self.startupStage = .failed("Startup timed out")
        }
    }

    func checkMemoryBeforeStart(estimatedRAMGB: Double?, freeGB: Double) -> Bool {
        guard let estimated = estimatedRAMGB else { return true }
        let headroom = UserDefaults.standard.double(forKey: "memoryHeadroomGB")
        let buffer = headroom > 0 ? headroom : 2.0
        return freeGB >= (estimated + buffer)
    }

    func processOutput(_ output: String) {
        serverOutput += output

        let lines = output.split(separator: "\n", omittingEmptySubsequences: false)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let logLine = LogLine(text: trimmed, timestamp: Date(), type: lineType(trimmed))
            logBuffer.append(logLine)
        }

        if logBuffer.count > Self.maxLogLines {
            logBuffer = Array(logBuffer.suffix(Self.maxLogLines))
        }
        serverLogLines = logBuffer

        updateStartupStage(output)
    }

    private func updateStartupStage(_ output: String) {
        let lower = output.lowercased()

        if lower.contains("error") || lower.contains("traceback") || lower.contains("exception") {
            if case .starting = status {
                let msg = output.trimmingCharacters(in: .whitespacesAndNewlines)
                let shortMsg = String(msg.prefix(200))
                startupStage = .failed(shortMsg)
            }
            return
        }

        if lower.contains("uvicorn running on") || lower.contains("running on http") {
            status = .running
            startupStage = .ready
            return
        }

        guard case .starting = status else { return }

        if lower.contains("load") && (lower.contains("weight") || lower.contains("model") || lower.contains("checkpoint") || lower.contains("download")) {
            if case .loadingWeights = startupStage { }
            else { startupStage = .loadingWeights }
        } else if lower.contains("build") || lower.contains("creat") || lower.contains("initializ") || lower.contains("compile") || lower.contains("fuse") {
            startupStage = .buildingModel
        } else if lower.contains("warm") || lower.contains("prepar") || lower.contains("start server") || lower.contains("serving") {
            startupStage = .warmingUp
        }
    }

    private func lineType(_ text: String) -> LogLineType {
        let lower = text.lowercased()
        if lower.contains("error") || lower.contains("traceback") || lower.contains("exception") || lower.contains("failed") {
            return .error
        } else if lower.contains("warning") || lower.contains("warn") {
            return .warning
        } else if lower.contains("debug") {
            return .debug
        }
        return .info
    }
}

enum LogLineType {
    case info
    case warning
    case error
    case debug
}

struct LogLine: Identifiable {
    let id = UUID()
    let text: String
    let timestamp: Date
    let type: LogLineType
}
