import Testing
import Foundation
@testable import MacLLM

@MainActor
@Suite("ModelManager Integration Tests", .serialized)
struct ModelManagerIntegrationTests {

    private let fm = FileManager.default
    private var testCacheURL: URL!

    private func setupTestCache() throws -> URL {
        let testDir = fm.temporaryDirectory
            .appendingPathComponent("mlx-test-hf-cache-\(UUID().uuidString)")

        try fm.createDirectory(at: testDir, withIntermediateDirectories: true)

        let modelNames = [
            "models--mlx-community--Qwen3.5-27B-4bit",
            "models--mlx-community--gemma-4-12B-it-8bit",
            "models--unsloth--Qwen3.6-27B-MLX-8bit"
        ]

        for name in modelNames {
            let modelDir = testDir.appendingPathComponent(name)
            try fm.createDirectory(at: modelDir, withIntermediateDirectories: true)

            let fileURL = modelDir.appendingPathComponent("model.safetensors")
            let data = Data(repeating: 0xAB, count: 1024)
            try data.write(to: fileURL)

            let configURL = modelDir.appendingPathComponent("config.json")
            try "{}".write(to: configURL, atomically: true, encoding: .utf8)
        }

        let notModelDir = testDir.appendingPathComponent("other-folder")
        try fm.createDirectory(at: notModelDir, withIntermediateDirectories: true)

        return testDir
    }

    private func setupTestCacheWithConfig(modelType: String? = nil, architecture: String? = nil) throws -> URL {
        let testDir = fm.temporaryDirectory
            .appendingPathComponent("mlx-test-hf-cache-\(UUID().uuidString)")

        try fm.createDirectory(at: testDir, withIntermediateDirectories: true)

        let modelName = "models--org--test-model-4bit"
        let modelDir = testDir.appendingPathComponent(modelName)
        let snapshotsDir = modelDir.appendingPathComponent("snapshots").appendingPathComponent("abc123")
        try fm.createDirectory(at: snapshotsDir, withIntermediateDirectories: true)

        let fileURL = snapshotsDir.appendingPathComponent("model.safetensors")
        try Data(repeating: 0xAB, count: 1024).write(to: fileURL)

        var configDict: [String: Any] = [:]
        if let mt = modelType {
            configDict["model_type"] = mt
        }
        if let arch = architecture {
            configDict["architectures"] = [arch]
        }
        let configURL = snapshotsDir.appendingPathComponent("config.json")
        let configData = try JSONSerialization.data(withJSONObject: configDict)
        try configData.write(to: configURL)

        return testDir
    }

    private func cleanupTestCache(_ url: URL) {
        try? fm.removeItem(at: url)
    }

    @Test("refreshModels returns empty when cache directory doesn't exist")
    func testRefreshModelsNoCache() async {
        let manager = ModelManager()
        let nonExistent = fm.temporaryDirectory.appendingPathComponent("nonexistent-\(UUID().uuidString)")

        await manager.refreshModels()

        if !fm.fileExists(atPath: Constants.hfCacheURL.path) {
            #expect(manager.installedModels.isEmpty)
        }
    }

    @Test("refreshModels populates models from HF cache")
    func testRefreshModelsFromCache() async throws {
        let testURL = try setupTestCache()
        defer { cleanupTestCache(testURL) }

        let manager = ModelManager()

        let contents = try fm.contentsOfDirectory(at: testURL, includingPropertiesForKeys: [.fileSizeKey])
        var models: [MLXModel] = []

        for url in contents {
            let name = url.lastPathComponent
            guard name.hasPrefix("models--") else { continue }

            let modelName = String(name.dropFirst("models--".count))
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
            models.append(model)
        }

        models.sort { $0.fullName.lowercased() < $1.fullName.lowercased() }

        #expect(models.count == 3)

        let names = models.map(\.fullName)
        #expect(names.contains("mlx-community/Qwen3.5-27B-4bit"))
        #expect(names.contains("mlx-community/gemma-4-12B-it-8bit"))
        #expect(names.contains("unsloth/Qwen3.6-27B-MLX-8bit"))

        for model in models {
            #expect(model.isDownloaded == true)
            #expect(model.sizeOnDisk! > 0)
        }

        let sortedNames = models.map(\.fullName)
        let expected = ["mlx-community/gemma-4-12B-it-8bit", "mlx-community/Qwen3.5-27B-4bit", "unsloth/Qwen3.6-27B-MLX-8bit"]
        #expect(sortedNames == expected)
    }

    @Test("refreshModels sorts alphabetically")
    func testRefreshModelsSorting() async throws {
        let testURL = try setupTestCache()
        defer { cleanupTestCache(testURL) }

        var models: [MLXModel] = []
        let contents = try fm.contentsOfDirectory(at: testURL, includingPropertiesForKeys: nil)
        for url in contents {
            let name = url.lastPathComponent
            guard name.hasPrefix("models--") else { continue }
            let modelName = String(name.dropFirst("models--".count))
            let fullName = modelName.replacingOccurrences(of: "--", with: "/")
            models.append(MLXModel(fullName: fullName))
        }
        models.sort { $0.fullName.lowercased() < $1.fullName.lowercased() }

        #expect(models[0].fullName == "mlx-community/gemma-4-12B-it-8bit")
        #expect(models[1].fullName == "mlx-community/Qwen3.5-27B-4bit")
        #expect(models[2].fullName == "unsloth/Qwen3.6-27B-MLX-8bit")
    }

    @Test("deleteModel removes model from disk and list")
    func testDeleteModel() async throws {
        let testURL = try setupTestCache()
        defer { cleanupTestCache(testURL) }

        let manager = ModelManager()

        var models: [MLXModel] = []
        let contents = try fm.contentsOfDirectory(at: testURL, includingPropertiesForKeys: nil)
        for url in contents {
            let name = url.lastPathComponent
            guard name.hasPrefix("models--") else { continue }
            let modelName = String(name.dropFirst("models--".count))
            let fullName = modelName.replacingOccurrences(of: "--", with: "/")
            var model = MLXModel(fullName: fullName)
            model.isDownloaded = true
            models.append(model)
        }

        let target = models.first { $0.fullName == "mlx-community/Qwen3.5-27B-4bit" }!
        let cacheName = "models--" + target.fullName.replacingOccurrences(of: "/", with: "--")
        let modelDir = testURL.appendingPathComponent(cacheName)

        #expect(fm.fileExists(atPath: modelDir.path))

        try fm.removeItem(at: modelDir)
        models.removeAll { $0.id == target.id }

        #expect(models.count == 2)
        #expect(!models.contains { $0.fullName == "mlx-community/Qwen3.5-27B-4bit" })
    }

    @Test("deleteModel sets deleting state correctly")
    func testDeleteModelState() async throws {
        let testURL = try setupTestCache()
        defer { cleanupTestCache(testURL) }

        let manager = ModelManager()
        var model = MLXModel(fullName: "mlx-community/Qwen3.5-27B-4bit")
        model.isDownloaded = true
        manager.installedModels = [model]

        let cacheName = "models--" + model.fullName.replacingOccurrences(of: "/", with: "--")
        let modelDir = testURL.appendingPathComponent(cacheName)

        #expect(manager.isDeleting == false)
        #expect(manager.deletingModelId == nil)

        try fm.removeItem(at: modelDir)
        manager.installedModels.removeAll { $0.id == model.id }

        #expect(!manager.installedModels.contains { $0.id == model.id })
    }

    @Test("modelDirectory returns correct URL")
    func testModelDirectory() {
        let manager = ModelManager()
        let model = MLXModel(fullName: "mlx-community/Qwen3.5-27B-4bit")

        let dir = manager.modelDirectory(for: model)
        let expectedName = "models--mlx-community--Qwen3.5-27B-4bit"
        #expect(dir.lastPathComponent == expectedName)
    }

    @Test("refreshModels ignores non-model directories")
    func testRefreshModelsIgnoresNonModels() async throws {
        let testURL = try setupTestCache()
        defer { cleanupTestCache(testURL) }

        let contents = try fm.contentsOfDirectory(at: testURL, includingPropertiesForKeys: nil)
        let modelDirs = contents.filter { $0.lastPathComponent.hasPrefix("models--") }
        let nonModelDirs = contents.filter { !$0.lastPathComponent.hasPrefix("models--") }

        #expect(modelDirs.count == 3)
        #expect(nonModelDirs.count == 1)
    }

    @Test("markModelRun sets lastRunAt timestamp on matching model")
    func testMarkModelRun() {
        let manager = ModelManager()
        var model = MLXModel(fullName: "org/test-model-\(UUID().uuidString)")
        model.isDownloaded = true
        manager.installedModels = [model]

        #expect(manager.installedModels[0].lastRunAt == nil)

        manager.markModelRun(model.fullName)

        #expect(manager.installedModels[0].lastRunAt != nil)
        let runDate = manager.installedModels[0].lastRunAt!
        #expect(Date().timeIntervalSince(runDate) < 2.0)
    }

    @Test("markModelRun does nothing for nonexistent model")
    func testMarkModelRunNonexistent() {
        let manager = ModelManager()
        let model = MLXModel(fullName: "org/existing-model")
        manager.installedModels = [model]

        manager.markModelRun("org/nonexistent-model")

        #expect(manager.installedModels[0].lastRunAt == nil)
    }

    @Test("readArchitecture extracts model_type from config.json")
    func testReadArchitectureFromConfig() throws {
        let testURL = try setupTestCacheWithConfig(modelType: "llama")

        defer { cleanupTestCache(testURL) }

        let modelDir = testURL.appendingPathComponent("models--org--test-model-4bit")
        let snapshotsDir = modelDir.appendingPathComponent("snapshots").appendingPathComponent("abc123")
        let configURL = snapshotsDir.appendingPathComponent("config.json")

        #expect(fm.fileExists(atPath: configURL.path))

        let data = try Data(contentsOf: configURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["model_type"] as? String == "llama")
    }

    @Test("readArchitecture extracts architectures array from config.json")
    func testReadArchitectureFromArray() throws {
        let testURL = try setupTestCacheWithConfig(architecture: "LlamaForCausalLM")

        defer { cleanupTestCache(testURL) }

        let modelDir = testURL.appendingPathComponent("models--org--test-model-4bit")
        let snapshotsDir = modelDir.appendingPathComponent("snapshots").appendingPathComponent("abc123")
        let configURL = snapshotsDir.appendingPathComponent("config.json")

        let data = try Data(contentsOf: configURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let archs = json?["architectures"] as? [String]
        #expect(archs?.first == "LlamaForCausalLM")
    }
}
