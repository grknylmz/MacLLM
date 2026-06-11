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
}
