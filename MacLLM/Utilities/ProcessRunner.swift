import Foundation

struct ProcessResult {
    let stdout: String
    let stderr: String
    let exitCode: Int32

    var success: Bool { exitCode == 0 }
}

enum ProcessRunner {
    @discardableResult
    static func run(
        executable: String,
        arguments: [String] = [],
        environment: [String: String]? = nil,
        workingDirectory: URL? = nil,
        timeout: TimeInterval = 300
    ) async throws -> ProcessResult {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe
            process.standardInput = FileHandle.nullDevice

            if let env = environment {
                var merged = ProcessInfo.processInfo.environment
                for (key, value) in env {
                    merged[key] = value
                }
                process.environment = merged
            }

            if let dir = workingDirectory {
                process.currentDirectoryURL = dir
            }

            var stdoutData = Data()
            var stderrData = Data()

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    stdoutData.append(data)
                }
            }

            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    stderrData.append(data)
                }
            }

            do {
                try process.run()
            } catch {
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                continuation.resume(returning: ProcessResult(
                    stdout: "",
                    stderr: error.localizedDescription,
                    exitCode: -1
                ))
                return
            }

            DispatchQueue.global().async {
                process.waitUntilExit()

                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil

                let remainingStdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let remainingStderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                stdoutData.append(remainingStdout)
                stderrData.append(remainingStderr)

                let result = ProcessResult(
                    stdout: String(data: stdoutData, encoding: .utf8) ?? "",
                    stderr: String(data: stderrData, encoding: .utf8) ?? "",
                    exitCode: process.terminationStatus
                )
                continuation.resume(returning: result)
            }
        }
    }

    @discardableResult
    static func runWithOutput(
        executable: String,
        arguments: [String] = [],
        environment: [String: String]? = nil,
        workingDirectory: URL? = nil,
        onStdout: @escaping (String) -> Void,
        onStderr: @escaping (String) -> Void
    ) async throws -> ProcessResult {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe
            process.standardInput = FileHandle.nullDevice

            if let env = environment {
                var merged = ProcessInfo.processInfo.environment
                for (key, value) in env {
                    merged[key] = value
                }
                process.environment = merged
            }

            if let dir = workingDirectory {
                process.currentDirectoryURL = dir
            }

            var stdoutData = Data()
            var stderrData = Data()

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    stdoutData.append(data)
                    if let str = String(data: data, encoding: .utf8) {
                        DispatchQueue.main.async { onStdout(str) }
                    }
                }
            }

            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    stderrData.append(data)
                    if let str = String(data: data, encoding: .utf8) {
                        DispatchQueue.main.async { onStderr(str) }
                    }
                }
            }

            do {
                try process.run()
            } catch {
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                continuation.resume(returning: ProcessResult(
                    stdout: "",
                    stderr: error.localizedDescription,
                    exitCode: -1
                ))
                return
            }

            DispatchQueue.global().async {
                process.waitUntilExit()

                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil

                let remainingStdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let remainingStderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                stdoutData.append(remainingStdout)
                stderrData.append(remainingStderr)

                let result = ProcessResult(
                    stdout: String(data: stdoutData, encoding: .utf8) ?? "",
                    stderr: String(data: stderrData, encoding: .utf8) ?? "",
                    exitCode: process.terminationStatus
                )
                continuation.resume(returning: result)
            }
        }
    }

    @discardableResult
    static func runShell(_ command: String, environment: [String: String]? = nil) async throws -> ProcessResult {
        try await run(
            executable: "/bin/zsh",
            arguments: ["-c", command],
            environment: environment
        )
    }
}
