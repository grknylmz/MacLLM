import Foundation
import Observation

@Observable
@MainActor
class ModelManager {
    var installedModels: [MLXModel] = []
    var isLoading = false
    var isDeleting = false
    var deletingModelId: String?
    var error: String?

    private let fm = FileManager.default

    func refreshModels() async {
        isLoading = true
        error = nil

        let cacheURL = Constants.hfCacheURL
        guard fm.fileExists(atPath: cacheURL.path) else {
            installedModels = []
            isLoading = false
            return
        }

        do {
            let contents = try fm.contentsOfDirectory(at: cacheURL, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey])
            var models: [MLXModel] = []

            for url in contents {
                let name = url.lastPathComponent
                guard name.hasPrefix(Constants.hfModelsPrefix) else { continue }

                let modelName = String(name.dropFirst(Constants.hfModelsPrefix.count))
                let fullName = modelName.replacingOccurrences(of: "--", with: "/")

                var size: Int64 = 0
                if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) {
                    for case let fileURL as URL in enumerator {
                        if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                           let fileSize = resourceValues.fileSize {
                            size += Int64(fileSize)
                        }
                    }
                }

                var model = MLXModel(fullName: fullName, sizeOnDisk: size)
                model.isDownloaded = true
                model.architecture = readArchitecture(from: url)
                models.append(model)
            }

            models.sort { $0.fullName.lowercased() < $1.fullName.lowercased() }
            installedModels = models
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func deleteModel(_ model: MLXModel) async {
        isDeleting = true
        deletingModelId = model.id
        error = nil

        let cacheName = Constants.hfModelsPrefix + model.fullName.replacingOccurrences(of: "/", with: "--")
        let modelURL = Constants.hfCacheURL.appendingPathComponent(cacheName)

        do {
            if fm.fileExists(atPath: modelURL.path) {
                try fm.removeItem(at: modelURL)
            }

            let lockDir = Constants.hfCacheURL.appendingPathComponent(".locks").appendingPathComponent(cacheName)
            if fm.fileExists(atPath: lockDir.path) {
                try fm.removeItem(at: lockDir)
            }

            cleanOrphanedLocks()

            installedModels.removeAll { $0.id == model.id }
        } catch {
            self.error = "Failed to delete \(model.fullName): \(error.localizedDescription)"
        }

        isDeleting = false
        deletingModelId = nil
    }

    func modelDirectory(for model: MLXModel) -> URL {
        let cacheName = Constants.hfModelsPrefix + model.fullName.replacingOccurrences(of: "/", with: "--")
        return Constants.hfCacheURL.appendingPathComponent(cacheName)
    }

    func markModelRun(_ fullName: String) {
        if let idx = installedModels.firstIndex(where: { $0.fullName == fullName }) {
            installedModels[idx].lastRunAt = Date()
        }
    }

    private func readArchitecture(from modelURL: URL) -> String? {
        let snapshotURLs = (try? fm.contentsOfDirectory(at: modelURL.appendingPathComponent("snapshots"), includingPropertiesForKeys: [.isDirectoryKey])) ?? []
        guard let snapshotURL = snapshotURLs.first else { return nil }

        let configURL = snapshotURL.appendingPathComponent("config.json")
        guard let data = fm.contents(atPath: configURL.path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let modelType = json["model_type"] as? String {
            return modelType.uppercased()
        }
        if let arch = json["architectures"] as? [String], let first = arch.first {
            return first
                .replacingOccurrences(of: "ForCausalLM", with: "")
                .replacingOccurrences(of: "Model", with: "")
        }
        return nil
    }

    func cleanOrphanedLocks(in cacheURL: URL = Constants.hfCacheURL) {
        let locksURL = cacheURL.appendingPathComponent(".locks")
        guard fm.fileExists(atPath: locksURL.path),
              let lockDirs = try? fm.contentsOfDirectory(at: locksURL, includingPropertiesForKeys: [.isDirectoryKey]) else { return }

        for lockDir in lockDirs {
            let lockName = lockDir.lastPathComponent
            guard lockName.hasPrefix(Constants.hfModelsPrefix) else { continue }

            let modelURL = cacheURL.appendingPathComponent(lockName)
            if !fm.fileExists(atPath: modelURL.path) {
                try? fm.removeItem(at: lockDir)
            }
        }
    }

    func cleanStaleDownloads() {
        performCleanup(in: Constants.hfCacheURL)
    }

    func cleanStaleDownloads(in cacheURL: URL) {
        performCleanup(in: cacheURL)
    }

    private func performCleanup(in cacheURL: URL) {
        guard fm.fileExists(atPath: cacheURL.path),
              let contents = try? fm.contentsOfDirectory(at: cacheURL, includingPropertiesForKeys: [.isDirectoryKey]) else { return }

        for url in contents {
            let name = url.lastPathComponent
            guard name.hasPrefix(Constants.hfModelsPrefix) else { continue }

            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard isDir else {
                debugLog("Removing unexpected file in cache: \(name)")
                try? fm.removeItem(at: url)
                continue
            }

            let modelName = String(name.dropFirst(Constants.hfModelsPrefix.count))
                .replacingOccurrences(of: "--", with: "/")

            let blobsURL = url.appendingPathComponent("blobs")
            let snapshotsURL = url.appendingPathComponent("snapshots")

            if !fm.fileExists(atPath: blobsURL.path) && !fm.fileExists(atPath: snapshotsURL.path) {
                debugLog("Removing empty/corrupt model dir (no blobs/snapshots): \(name)")
                try? fm.removeItem(at: url)
                removeLockDir(cacheName: name, in: cacheURL)
                continue
            }

            if fm.fileExists(atPath: blobsURL.path) {
                cleanupCorruptBlobs(in: blobsURL, modelName: modelName)
            }

            let validation = validateModelDirectory(url)
            if validation == .empty {
                debugLog("Removing empty model dir: \(name)")
                try? fm.removeItem(at: url)
                removeLockDir(cacheName: name, in: cacheURL)
            } else if validation == .onlyIncomplete {
                if !installedModels.contains(where: { $0.fullName == modelName }) {
                    debugLog("Removing incomplete-only model dir (not installed): \(name)")
                    try? fm.removeItem(at: url)
                    removeLockDir(cacheName: name, in: cacheURL)
                }
            } else if validation == .validWithIncomplete {
                cleanupIncompleteFiles(in: blobsURL, modelName: modelName)
            }

            if fm.fileExists(atPath: snapshotsURL.path) {
                cleanupBrokenSnapshots(snapshotsURL, blobsURL: blobsURL)
            }
        }

        cleanOrphanedLocks(in: cacheURL)
        cleanEmptyDirectories(at: cacheURL)
    }

    private enum ModelValidation {
        case empty
        case onlyIncomplete
        case valid
        case validWithIncomplete
    }

    private func validateModelDirectory(_ url: URL) -> ModelValidation {
        let blobsURL = url.appendingPathComponent("blobs")
        let snapshotsURL = url.appendingPathComponent("snapshots")

        let hasSnapshots = fm.fileExists(atPath: snapshotsURL.path)
        let hasBlobs = fm.fileExists(atPath: blobsURL.path)

        if !hasBlobs { return hasSnapshots ? .valid : .empty }

        guard let files = try? fm.contentsOfDirectory(at: blobsURL, includingPropertiesForKeys: nil) else {
            return .empty
        }

        let meaningfulFiles = files.filter { file in
            let name = file.lastPathComponent
            return !name.hasPrefix(".") && name != "incomplete"
        }

        if meaningfulFiles.isEmpty { return .empty }

        let completedFiles = meaningfulFiles.filter { $0.pathExtension != "incomplete" }
        let incompleteFiles = meaningfulFiles.filter { $0.pathExtension == "incomplete" }

        if completedFiles.isEmpty && !incompleteFiles.isEmpty {
            return .onlyIncomplete
        }

        if !incompleteFiles.isEmpty {
            return .validWithIncomplete
        }

        return .valid
    }

    private func cleanupCorruptBlobs(in blobsURL: URL, modelName: String) {
        guard let files = try? fm.contentsOfDirectory(at: blobsURL, includingPropertiesForKeys: [.fileSizeKey]) else { return }

        for file in files {
            let name = file.lastPathComponent
            guard !name.hasPrefix(".") else { continue }

            let isDir = (try? file.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard !isDir else { continue }

            let fileSize = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            let isIncomplete = name.hasSuffix(".incomplete")
            let baseName = isIncomplete ? String(name.dropLast(".incomplete".count)) : name

            if baseName.isEmpty {
                debugLog("Removing corrupt blob (empty name): \(name) in \(modelName)")
                try? fm.removeItem(at: file)
                continue
            }

            let hasValidHexName = baseName.count >= 8 && baseName.allSatisfy { $0.isHexDigit }
            if !hasValidHexName {
                debugLog("Removing corrupt blob (invalid hash name): \(name) in \(modelName)")
                try? fm.removeItem(at: file)
                continue
            }

            if !isIncomplete && fileSize == 0 {
                debugLog("Removing zero-size completed blob: \(name) in \(modelName)")
                try? fm.removeItem(at: file)
            }
        }
    }

    private func cleanupIncompleteFiles(in blobsURL: URL, modelName: String) {
        guard let files = try? fm.contentsOfDirectory(at: blobsURL, includingPropertiesForKeys: nil) else { return }

        let incompleteFiles = files.filter { $0.lastPathComponent.hasSuffix(".incomplete") }
        for file in incompleteFiles {
            debugLog("Removing stale .incomplete blob: \(file.lastPathComponent) in \(modelName)")
            try? fm.removeItem(at: file)
        }
    }

    private func cleanupBrokenSnapshots(_ snapshotsURL: URL, blobsURL: URL) {
        guard let snapshotDirs = try? fm.contentsOfDirectory(at: snapshotsURL, includingPropertiesForKeys: [.isDirectoryKey]) else { return }

        for snapDir in snapshotDirs {
            let isDir = (try? snapDir.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard isDir else { continue }

            guard let files = try? fm.contentsOfDirectory(at: snapDir, includingPropertiesForKeys: [.isDirectoryKey]) else { continue }

            for file in files {
                let isFileDir = (try? file.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                guard !isFileDir else { continue }

                if fm.fileExists(atPath: file.path) {
                    let attrs = (try? fm.attributesOfItem(atPath: file.path))
                    let fileSize = attrs?[.size] as? Int ?? 0
                    let fileName = file.lastPathComponent

                    if fileName.hasSuffix(".json") && fileSize == 0 {
                        debugLog("Removing empty JSON in snapshot: \(fileName)")
                        try? fm.removeItem(at: file)
                    }
                }
            }
        }
    }

    private func removeLockDir(cacheName: String, in cacheURL: URL) {
        let lockDir = cacheURL.appendingPathComponent(".locks").appendingPathComponent(cacheName)
        if fm.fileExists(atPath: lockDir.path) {
            try? fm.removeItem(at: lockDir)
        }
    }

    private func cleanEmptyDirectories(at url: URL) {
        guard let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey]) else { return }

        for dir in contents {
            let isDir = (try? dir.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard isDir else { continue }
            let name = dir.lastPathComponent
            guard name.hasPrefix(Constants.hfModelsPrefix) || name == ".locks" else { continue }

            cleanEmptySubdirectories(at: dir)
        }
    }

    private func cleanEmptySubdirectories(at url: URL) {
        guard let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey]) else { return }

        for dir in contents {
            let isDir = (try? dir.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard isDir else { continue }
            cleanEmptySubdirectories(at: dir)

            let remaining = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
            if remaining.isEmpty {
                try? fm.removeItem(at: dir)
            }
        }
    }
}
