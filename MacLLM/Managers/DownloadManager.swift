import Foundation
import Observation

enum DownloadState: Equatable {
    case idle
    case downloading(progress: Double)
    case completed
    case failed(String)
    case paused

    var isDownloading: Bool {
        if case .downloading = self { return true }
        return false
    }

    var isActive: Bool {
        switch self {
        case .downloading, .paused: return true
        default: return false
        }
    }

    var isCompleted: Bool {
        if case .completed = self { return true }
        return false
    }

    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }

    var progress: Double {
        if case .downloading(let p) = self { return p }
        return 0
    }

    var errorMessage: String? {
        if case .failed(let msg) = self { return msg }
        return nil
    }

    var label: String {
        switch self {
        case .idle: return "Idle"
        case .downloading(let p): return "Downloading \(Int(p * 100))%"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .paused: return "Paused"
        }
    }
}

@Observable
@MainActor
class DownloadManager {
    var downloads: [String: DownloadState] = [:]
    var completedDownloads: [String] = []

    private var activeProcesses: [String: Process] = [:]
    private var activeTasks: [String: Task<Void, Never>] = [:]
    private var progressTimers: [String: Task<Void, Never>] = [:]
    private var knownTotalSizes: [String: Int64] = [:]

    private let hfDownloadPath: String
    private weak var modelManager: ModelManager?
    private weak var serverManager: ServerManager?

    init(modelManager: ModelManager?, serverManager: ServerManager?) {
        self.modelManager = modelManager
        self.serverManager = serverManager
        self.hfDownloadPath = Constants.venvURL
            .appendingPathComponent("bin/huggingface-cli")
            .path
    }

    func startDownload(_ modelId: String) {
        guard downloads[modelId]?.isActive != true else { return }

        downloads[modelId] = .downloading(progress: 0)

        let task = Task {
            let cliExists = FileManager.default.fileExists(atPath: hfDownloadPath)
            debugLog("=== startDownload: '\(modelId)' cliExists=\(cliExists) ===")

            guard cliExists else {
                downloads[modelId] = .failed("huggingface-cli not found")
                return
            }

            tryToReadTotalSize(modelId: modelId)
            startProgressPolling(modelId: modelId)

            let modelIdForClosure = modelId

            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: hfDownloadPath)
            process.arguments = ["download", modelId]
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe
            process.standardInput = FileHandle.nullDevice
            process.environment = ProcessInfo.processInfo.environment

            self.activeProcesses[modelId] = process

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                    let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { debugLog("[STDOUT] \(trimmed)") }
                }
            }

            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                    let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { debugLog("[STDERR] \(trimmed)") }
                    if trimmed.contains("model.safetensors.index.json") {
                        Task { @MainActor in
                            self.tryToReadTotalSize(modelId: modelIdForClosure)
                        }
                    }
                }
            }

            do {
                try process.run()
                debugLog("Process started (PID: \(process.processIdentifier)) for '\(modelId)'")
            } catch {
                debugLog("ERROR: Process failed to start: \(error.localizedDescription)")
                stopProgressPolling(modelId: modelId)
                downloads[modelId] = .failed(error.localizedDescription)
                activeProcesses.removeValue(forKey: modelId)
                return
            }

            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                DispatchQueue.global().async {
                    process.waitUntilExit()

                    stdoutPipe.fileHandleForReading.readabilityHandler = nil
                    stderrPipe.fileHandleForReading.readabilityHandler = nil

                    let remainingErr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    let stderr = String(data: remainingErr, encoding: .utf8) ?? ""

                    Task { @MainActor in
                        self.stopProgressPolling(modelId: modelId)
                        self.activeProcesses.removeValue(forKey: modelId)

                        let exitCode = process.terminationStatus
                        debugLog("Process exited with code: \(exitCode) for '\(modelId)'")

                        if exitCode == 0 {
                            self.downloads[modelId] = .completed
                            self.completedDownloads.append(modelId)
                            debugLog("Download completed: '\(modelId)'")

                            await self.modelManager?.refreshModels()

                            if self.serverManager?.activeModel == nil {
                                debugLog("Auto-starting server with '\(modelId)'")
                                await self.serverManager?.start(model: modelId)
                            }
                        } else {
                            let shortError = Self.parseError(stderr)
                            if case .paused = self.downloads[modelId] {
                                debugLog("Download was paused, not marking as failed")
                            } else {
                                self.downloads[modelId] = .failed(shortError)
                                debugLog("Download failed: \(shortError)")
                            }
                        }

                        continuation.resume()
                    }
                }
            }
        }

        activeTasks[modelId] = task
    }

    func stopDownload(_ modelId: String) {
        debugLog("Stopping download: '\(modelId)'")
        stopProgressPolling(modelId: modelId)
        if let process = activeProcesses[modelId], process.isRunning {
            process.terminate()
            activeProcesses.removeValue(forKey: modelId)
        }
        activeTasks[modelId]?.cancel()
        activeTasks.removeValue(forKey: modelId)
        downloads[modelId] = .failed("Download cancelled")
    }

    func pauseDownload(_ modelId: String) {
        debugLog("Pausing download: '\(modelId)'")
        stopProgressPolling(modelId: modelId)
        if let process = activeProcesses[modelId], process.isRunning {
            process.suspend()
            downloads[modelId] = .paused
        }
    }

    func resumeDownload(_ modelId: String) {
        debugLog("Resuming download: '\(modelId)'")
        if let process = activeProcesses[modelId], process.isRunning {
            process.resume()
            let currentProgress = downloads[modelId]?.progress ?? 0
            downloads[modelId] = .downloading(progress: currentProgress)
            startProgressPolling(modelId: modelId)
        } else {
            startDownload(modelId)
        }
    }

    func clearDownload(_ modelId: String) {
        downloads.removeValue(forKey: modelId)
        completedDownloads.removeAll { $0 == modelId }
    }

    func state(for modelId: String) -> DownloadState {
        downloads[modelId] ?? .idle
    }

    func hasIncompleteDownloads() -> Bool {
        downloads.values.contains { $0.isActive || $0.isFailed }
    }

    func incompleteDownloadIds() -> [String] {
        downloads.filter { $0.value.isActive || $0.value.isFailed }.map(\.key)
    }

    func detectInterruptedDownloads() {
        performInterruptedDetection(in: Constants.hfCacheURL)
    }

    func detectInterruptedDownloads(in cacheURL: URL) {
        performInterruptedDetection(in: cacheURL)
    }

    private func performInterruptedDetection(in cacheURL: URL) {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: cacheURL, includingPropertiesForKeys: [.isDirectoryKey]) else { return }

        for url in contents {
            let name = url.lastPathComponent
            guard name.hasPrefix(Constants.hfModelsPrefix) else { continue }

            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard isDir else { continue }

            let modelName = String(name.dropFirst(Constants.hfModelsPrefix.count))
                .replacingOccurrences(of: "--", with: "/")

            let blobsURL = url.appendingPathComponent("blobs")
            let snapshotsURL = url.appendingPathComponent("snapshots")

            guard fm.fileExists(atPath: blobsURL.path) else { continue }

            let blobFiles = (try? fm.contentsOfDirectory(at: blobsURL, includingPropertiesForKeys: nil)) ?? []
            let incompleteFiles = blobFiles.filter { $0.lastPathComponent.hasSuffix(".incomplete") }
            let completedFiles = blobFiles.filter {
                let n = $0.lastPathComponent
                return !n.hasPrefix(".") && !n.hasSuffix(".incomplete") && n != "incomplete"
            }

            if completedFiles.isEmpty && incompleteFiles.isEmpty {
                continue
            }

            let hasSnapshots = fm.fileExists(atPath: snapshotsURL.path) &&
                !((try? fm.contentsOfDirectory(at: snapshotsURL, includingPropertiesForKeys: nil)) ?? []).isEmpty

            if !completedFiles.isEmpty && hasSnapshots && incompleteFiles.isEmpty {
                continue
            }

            if !completedFiles.isEmpty || !incompleteFiles.isEmpty {
                tryToReadTotalSize(modelId: modelName)
                let progress = calculateFilesystemProgress(modelId: modelName)
                debugLog("Detected interrupted download: '\(modelName)' progress=\(Int(progress * 100))% (\(incompleteFiles.count) incomplete, \(completedFiles.count) completed blobs, hasSnapshots=\(hasSnapshots))")
                downloads[modelName] = .paused
            }
        }
    }

    // MARK: - Filesystem Progress Polling

    private func startProgressPolling(modelId: String) {
        progressTimers[modelId]?.cancel()
        progressTimers[modelId] = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                guard case .downloading = self.downloads[modelId] else { return }

                if self.knownTotalSizes[modelId] == nil {
                    self.tryToReadTotalSize(modelId: modelId)
                }

                let progress = self.calculateFilesystemProgress(modelId: modelId)
                self.downloads[modelId] = .downloading(progress: progress)
            }
        }
    }

    private func stopProgressPolling(modelId: String) {
        progressTimers[modelId]?.cancel()
        progressTimers.removeValue(forKey: modelId)
    }

    private func calculateFilesystemProgress(modelId: String) -> Double {
        let blobsURL = blobsDirectory(for: modelId)
        let fm = FileManager.default
        guard fm.fileExists(atPath: blobsURL.path) else { return 0 }

        guard let files = try? fm.contentsOfDirectory(at: blobsURL, includingPropertiesForKeys: nil) else { return 0 }

        var downloadedBytes: Int64 = 0
        for file in files {
            let fileName = file.lastPathComponent
            guard !fileName.isEmpty && !fileName.hasPrefix(".") else { continue }

            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: file.path, isDirectory: &isDir), !isDir.boolValue else { continue }

            let isComplete = !fileName.hasSuffix(".incomplete")
            let isIncomplete = fileName.hasSuffix(".incomplete")

            if isComplete || isIncomplete {
                if let attrs = try? fm.attributesOfItem(atPath: file.path),
                   let size = attrs[.size] as? NSNumber {
                    downloadedBytes += size.int64Value
                }
            }
        }

        guard let totalSize = knownTotalSizes[modelId], totalSize > 0 else {
            return 0
        }

        return min(Double(downloadedBytes) / Double(totalSize), 1.0)
    }

    private func tryToReadTotalSize(modelId: String) {
        let cacheName = Constants.hfModelsPrefix + modelId.replacingOccurrences(of: "/", with: "--")
        let modelDir = Constants.hfCacheURL.appendingPathComponent(cacheName)
        let fm = FileManager.default

        guard fm.fileExists(atPath: modelDir.path) else { return }

        if let totalSize = readTotalSizeFromSnapshots(modelDir: modelDir) {
            knownTotalSizes[modelId] = totalSize
            debugLog("Read total_size=\(totalSize) bytes for '\(modelId)' from snapshot index.json")
            return
        }

        if let totalSize = scanBlobsForTotalSize(modelDir: modelDir) {
            knownTotalSizes[modelId] = totalSize
            debugLog("Read total_size=\(totalSize) bytes for '\(modelId)' from blobs scan")
            return
        }

        debugLog("Could not determine total_size for '\(modelId)', progress will show 0%")
    }

    private func readTotalSizeFromSnapshots(modelDir: URL) -> Int64? {
        let fm = FileManager.default
        let snapshotsURL = modelDir.appendingPathComponent("snapshots")
        let refsURL = modelDir.appendingPathComponent("refs")

        var snapshotDirs: [URL] = []
        if let snapContents = try? fm.contentsOfDirectory(at: snapshotsURL, includingPropertiesForKeys: [.isDirectoryKey]) {
            snapshotDirs = snapContents.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false }
        }

        for snapDir in snapshotDirs {
            if let contents = try? fm.contentsOfDirectory(at: snapDir, includingPropertiesForKeys: nil) {
                for file in contents where file.lastPathComponent == "model.safetensors.index.json" {
                    if let totalSize = parseTotalSizeFromJSON(file) {
                        return totalSize
                    }
                }
            }
        }

        if let refs = try? fm.contentsOfDirectory(at: refsURL, includingPropertiesForKeys: nil) {
            for refFile in refs {
                if let hash = try? String(contentsOf: refFile, encoding: .utf8)
                    .trimmingCharacters(in: .whitespacesAndNewlines) {
                    let snapDir = snapshotsURL.appendingPathComponent(hash)
                    if let contents = try? fm.contentsOfDirectory(at: snapDir, includingPropertiesForKeys: nil) {
                        for file in contents where file.lastPathComponent == "model.safetensors.index.json" {
                            if let totalSize = parseTotalSizeFromJSON(file) {
                                return totalSize
                            }
                        }
                    }
                }
            }
        }

        return nil
    }

    private func scanBlobsForTotalSize(modelDir: URL) -> Int64? {
        let fm = FileManager.default
        let blobsURL = modelDir.appendingPathComponent("blobs")

        guard fm.fileExists(atPath: blobsURL.path),
              let blobFiles = try? fm.contentsOfDirectory(at: blobsURL, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]) else {
            return nil
        }

        for file in blobFiles {
            let name = file.lastPathComponent
            guard !name.hasPrefix(".") && !name.hasSuffix(".incomplete") else { continue }

            if let data = fm.contents(atPath: file.path),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let metadata = json["metadata"] as? [String: Any],
               let totalSize = metadata["total_size"] as? Int64 {
                return totalSize
            }
        }

        return nil
    }

    private func parseTotalSizeFromJSON(_ file: URL) -> Int64? {
        guard let data = FileManager.default.contents(atPath: file.path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let metadata = json["metadata"] as? [String: Any],
              let totalSize = metadata["total_size"] as? Int64 else {
            return nil
        }
        return totalSize
    }

    private func blobsDirectory(for modelId: String) -> URL {
        let cacheName = Constants.hfModelsPrefix + modelId.replacingOccurrences(of: "/", with: "--")
        return Constants.hfCacheURL.appendingPathComponent(cacheName).appendingPathComponent("blobs")
    }

    static func parseError(_ stderr: String) -> String {
        if stderr.contains("RepositoryNotFoundError") {
            return "Repository not found. Check the model ID."
        } else if stderr.contains("401") || stderr.contains("Unauthorized") {
            return "Authentication required. Run: huggingface-cli login"
        } else if stderr.contains("GatedRepo") {
            return "This is a gated model. Visit huggingface.co to accept the license."
        } else {
            let firstLine = stderr.components(separatedBy: "\n")
                .map({ $0.trimmingCharacters(in: .whitespaces) })
                .first(where: { !$0.isEmpty }) ?? "Unknown error"
            return String(firstLine.prefix(150))
        }
    }
}
