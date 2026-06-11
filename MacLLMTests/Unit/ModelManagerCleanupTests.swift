import Testing
import Foundation
@testable import MacLLM

@MainActor
@Suite("ModelManager Cleanup Unit Tests", .serialized)
struct ModelManagerCleanupTests {

    private let fm = FileManager.default

    private func createTestCacheDir() throws -> URL {
        let testDir = fm.temporaryDirectory
            .appendingPathComponent("mlx-test-cleanup-\(UUID().uuidString)")
        try fm.createDirectory(at: testDir, withIntermediateDirectories: true)
        return testDir
    }

    private func cleanup(_ url: URL) {
        try? fm.removeItem(at: url)
    }

    @Test("cleanStaleDownloads removes empty model directory")
    func testRemoveEmptyModelDir() throws {
        let testDir = try createTestCacheDir()
        defer { cleanup(testDir) }

        let modelDir = testDir.appendingPathComponent("models--org--empty-model")
        try fm.createDirectory(at: modelDir, withIntermediateDirectories: true)

        let manager = ModelManager()
        manager.cleanStaleDownloads(in: testDir)

        #expect(!fm.fileExists(atPath: modelDir.path))
    }

    @Test("cleanStaleDownloads removes model with only incomplete blobs when not installed")
    func testRemoveIncompleteOnlyNotInstalled() throws {
        let testDir = try createTestCacheDir()
        defer { cleanup(testDir) }

        let blobsDir = testDir.appendingPathComponent("models--org--partial").appendingPathComponent("blobs")
        try fm.createDirectory(at: blobsDir, withIntermediateDirectories: true)

        try Data(repeating: 0xFF, count: 512).write(
            to: blobsDir.appendingPathComponent("abc12345def67890.incomplete")
        )

        let manager = ModelManager()
        #expect(!manager.installedModels.contains(where: { $0.fullName == "org/partial" }))
        manager.cleanStaleDownloads(in: testDir)

        #expect(!fm.fileExists(atPath: testDir.appendingPathComponent("models--org--partial").path))
    }

    @Test("cleanStaleDownloads keeps incomplete-only model when installed")
    func testKeepIncompleteWhenInstalled() throws {
        let testDir = try createTestCacheDir()
        defer { cleanup(testDir) }

        let blobsDir = testDir.appendingPathComponent("models--org--partial").appendingPathComponent("blobs")
        try fm.createDirectory(at: blobsDir, withIntermediateDirectories: true)

        try Data(repeating: 0xFF, count: 512).write(
            to: blobsDir.appendingPathComponent("abc12345def67890.incomplete")
        )

        let manager = ModelManager()
        var model = MLXModel(fullName: "org/partial")
        model.isDownloaded = true
        manager.installedModels = [model]

        manager.cleanStaleDownloads(in: testDir)

        #expect(fm.fileExists(atPath: testDir.appendingPathComponent("models--org--partial").path))
    }

    @Test("cleanStaleDownloads removes corrupt blob with invalid hash name")
    func testRemoveCorruptBlobInvalidName() throws {
        let testDir = try createTestCacheDir()
        defer { cleanup(testDir) }

        let blobsDir = testDir.appendingPathComponent("models--org--test").appendingPathComponent("blobs")
        let snapshotsDir = testDir.appendingPathComponent("models--org--test").appendingPathComponent("snapshots").appendingPathComponent("abc")
        try fm.createDirectory(at: blobsDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: snapshotsDir, withIntermediateDirectories: true)

        try Data(repeating: 0xFF, count: 100).write(
            to: blobsDir.appendingPathComponent("not-a-hex-name")
        )
        try Data(repeating: 0xFF, count: 200).write(
            to: blobsDir.appendingPathComponent("abc12345def67890")
        )

        let manager = ModelManager()
        manager.cleanStaleDownloads(in: testDir)

        let remainingFiles = try fm.contentsOfDirectory(at: blobsDir, includingPropertiesForKeys: nil)
        let names = remainingFiles.map(\.lastPathComponent)
        #expect(!names.contains("not-a-hex-name"))
        #expect(names.contains("abc12345def67890"))
    }

    @Test("cleanStaleDownloads removes zero-size completed blob")
    func testRemoveZeroSizeCompletedBlob() throws {
        let testDir = try createTestCacheDir()
        defer { cleanup(testDir) }

        let blobsDir = testDir.appendingPathComponent("models--org--test").appendingPathComponent("blobs")
        let snapshotsDir = testDir.appendingPathComponent("models--org--test").appendingPathComponent("snapshots").appendingPathComponent("abc")
        try fm.createDirectory(at: blobsDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: snapshotsDir, withIntermediateDirectories: true)

        try Data().write(to: blobsDir.appendingPathComponent("abc12345def67890"))
        try Data(repeating: 0xFF, count: 200).write(
            to: blobsDir.appendingPathComponent("bbb12345def67890")
        )

        let manager = ModelManager()
        manager.cleanStaleDownloads(in: testDir)

        let remainingFiles = try fm.contentsOfDirectory(at: blobsDir, includingPropertiesForKeys: nil)
        let names = remainingFiles.map(\.lastPathComponent)
        #expect(!names.contains("abc12345def67890"))
        #expect(names.contains("bbb12345def67890"))
    }

    @Test("cleanStaleDownloads removes .incomplete files from valid model")
    func testRemoveStaleIncompleteFromValidModel() throws {
        let testDir = try createTestCacheDir()
        defer { cleanup(testDir) }

        let blobsDir = testDir.appendingPathComponent("models--org--test").appendingPathComponent("blobs")
        let snapshotsDir = testDir.appendingPathComponent("models--org--test").appendingPathComponent("snapshots").appendingPathComponent("abc")
        try fm.createDirectory(at: blobsDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: snapshotsDir, withIntermediateDirectories: true)

        try Data(repeating: 0xFF, count: 200).write(
            to: blobsDir.appendingPathComponent("abc12345def67890")
        )
        try Data(repeating: 0xFF, count: 100).write(
            to: blobsDir.appendingPathComponent("bbb12345def67890.incomplete")
        )

        let manager = ModelManager()
        manager.cleanStaleDownloads(in: testDir)

        let remainingFiles = try fm.contentsOfDirectory(at: blobsDir, includingPropertiesForKeys: nil)
        let names = remainingFiles.map(\.lastPathComponent)
        #expect(names.contains("abc12345def67890"))
        #expect(!names.contains("bbb12345def67890.incomplete"))
        #expect(fm.fileExists(atPath: testDir.appendingPathComponent("models--org--test").path))
    }

    @Test("cleanStaleDownloads removes empty JSON in snapshot")
    func testRemoveEmptyJsonInSnapshot() throws {
        let testDir = try createTestCacheDir()
        defer { cleanup(testDir) }

        let blobsDir = testDir.appendingPathComponent("models--org--test").appendingPathComponent("blobs")
        let snapshotsDir = testDir.appendingPathComponent("models--org--test").appendingPathComponent("snapshots").appendingPathComponent("snap1")
        try fm.createDirectory(at: blobsDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: snapshotsDir, withIntermediateDirectories: true)

        try Data(repeating: 0xFF, count: 200).write(
            to: blobsDir.appendingPathComponent("abc12345def67890")
        )
        try Data().write(to: snapshotsDir.appendingPathComponent("config.json"))
        try "{\"key\":\"val\"}".write(
            to: snapshotsDir.appendingPathComponent("tokenizer.json"),
            atomically: true, encoding: .utf8
        )

        let manager = ModelManager()
        manager.cleanStaleDownloads(in: testDir)

        #expect(!fm.fileExists(atPath: snapshotsDir.appendingPathComponent("config.json").path))
        #expect(fm.fileExists(atPath: snapshotsDir.appendingPathComponent("tokenizer.json").path))
    }

    @Test("cleanStaleDownloads removes orphaned lock directory")
    func testRemoveOrphanedLockDir() throws {
        let testDir = try createTestCacheDir()
        defer { cleanup(testDir) }

        let lockDir = testDir.appendingPathComponent(".locks").appendingPathComponent("models--org--deleted")
        try fm.createDirectory(at: lockDir, withIntermediateDirectories: true)
        try "lock".write(to: lockDir.appendingPathComponent("abc.lock"), atomically: true, encoding: .utf8)

        #expect(!fm.fileExists(atPath: testDir.appendingPathComponent("models--org--deleted").path))
        #expect(fm.fileExists(atPath: lockDir.path))

        let manager = ModelManager()
        manager.cleanStaleDownloads(in: testDir)

        #expect(!fm.fileExists(atPath: lockDir.path))
    }

    @Test("cleanStaleDownloads keeps lock dir for existing model")
    func testKeepLockDirForExistingModel() throws {
        let testDir = try createTestCacheDir()
        defer { cleanup(testDir) }

        let modelDir = testDir.appendingPathComponent("models--org--existing")
        let blobsDir = modelDir.appendingPathComponent("blobs")
        let snapshotsDir = modelDir.appendingPathComponent("snapshots").appendingPathComponent("snap1")
        try fm.createDirectory(at: blobsDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: snapshotsDir, withIntermediateDirectories: true)

        try Data(repeating: 0xFF, count: 200).write(
            to: blobsDir.appendingPathComponent("abc12345def67890")
        )

        let lockDir = testDir.appendingPathComponent(".locks").appendingPathComponent("models--org--existing")
        try fm.createDirectory(at: lockDir, withIntermediateDirectories: true)
        try "lock".write(to: lockDir.appendingPathComponent("abc.lock"), atomically: true, encoding: .utf8)

        let manager = ModelManager()
        manager.cleanStaleDownloads(in: testDir)

        #expect(fm.fileExists(atPath: lockDir.path))
    }

    @Test("cleanStaleDownloads removes model dir with no blobs or snapshots")
    func testRemoveDirNoBlobsNoSnapshots() throws {
        let testDir = try createTestCacheDir()
        defer { cleanup(testDir) }

        let modelDir = testDir.appendingPathComponent("models--org--empty-structure")
        let refsDir = modelDir.appendingPathComponent("refs")
        try fm.createDirectory(at: refsDir, withIntermediateDirectories: true)

        let lockDir = testDir.appendingPathComponent(".locks").appendingPathComponent("models--org--empty-structure")
        try fm.createDirectory(at: lockDir, withIntermediateDirectories: true)

        let manager = ModelManager()
        manager.cleanStaleDownloads(in: testDir)

        #expect(!fm.fileExists(atPath: modelDir.path))
        #expect(!fm.fileExists(atPath: lockDir.path))
    }

    @Test("cleanStaleDownloads cleans empty subdirectories")
    func testCleansEmptySubdirectories() throws {
        let testDir = try createTestCacheDir()
        defer { cleanup(testDir) }

        let modelDir = testDir.appendingPathComponent("models--org--test")
        let blobsDir = modelDir.appendingPathComponent("blobs")
        let snapshotsDir = modelDir.appendingPathComponent("snapshots").appendingPathComponent("snap1")
        let emptySubdir = modelDir.appendingPathComponent("refs").appendingPathComponent("main")
        try fm.createDirectory(at: blobsDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: snapshotsDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: emptySubdir, withIntermediateDirectories: true)

        try Data(repeating: 0xFF, count: 200).write(
            to: blobsDir.appendingPathComponent("abc12345def67890")
        )

        #expect(fm.fileExists(atPath: emptySubdir.path))

        let manager = ModelManager()
        manager.cleanStaleDownloads(in: testDir)

        #expect(!fm.fileExists(atPath: emptySubdir.path))
        #expect(!fm.fileExists(atPath: modelDir.appendingPathComponent("refs").path))
    }

    @Test("cleanStaleDownloads ignores dotfiles in blobs")
    func testIgnoreDotfilesInBlobs() throws {
        let testDir = try createTestCacheDir()
        defer { cleanup(testDir) }

        let blobsDir = testDir.appendingPathComponent("models--org--test").appendingPathComponent("blobs")
        let snapshotsDir = testDir.appendingPathComponent("models--org--test").appendingPathComponent("snapshots").appendingPathComponent("abc")
        try fm.createDirectory(at: blobsDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: snapshotsDir, withIntermediateDirectories: true)

        try Data(repeating: 0xFF, count: 100).write(
            to: blobsDir.appendingPathComponent(".incomplete")
        )
        try Data(repeating: 0xFF, count: 200).write(
            to: blobsDir.appendingPathComponent("abc12345def67890")
        )

        let manager = ModelManager()
        manager.cleanStaleDownloads(in: testDir)

        let remainingFiles = try fm.contentsOfDirectory(at: blobsDir, includingPropertiesForKeys: nil)
        let names = remainingFiles.map(\.lastPathComponent)
        #expect(names.contains(".incomplete"))
    }

    @Test("deleteModel removes lock directory alongside model")
    func testDeleteModelRemovesLock() throws {
        let testDir = try createTestCacheDir()
        defer { cleanup(testDir) }

        let cacheName = "models--org--test-model"
        let modelDir = testDir.appendingPathComponent(cacheName)
        let blobsDir = modelDir.appendingPathComponent("blobs")
        try fm.createDirectory(at: blobsDir, withIntermediateDirectories: true)
        try Data(repeating: 0xFF, count: 100).write(to: blobsDir.appendingPathComponent("abc12345def67890"))

        let lockDir = testDir.appendingPathComponent(".locks").appendingPathComponent(cacheName)
        try fm.createDirectory(at: lockDir, withIntermediateDirectories: true)
        try "lock".write(to: lockDir.appendingPathComponent("abc.lock"), atomically: true, encoding: .utf8)

        #expect(fm.fileExists(atPath: modelDir.path))
        #expect(fm.fileExists(atPath: lockDir.path))

        let manager = ModelManager()
        var model = MLXModel(fullName: "org/test-model")
        model.isDownloaded = true
        manager.installedModels = [model]

        try fm.removeItem(at: modelDir)
        let lockDirPath = Constants.hfCacheURL.appendingPathComponent(".locks").appendingPathComponent(cacheName)
        if fm.fileExists(atPath: lockDirPath.path) {
            try fm.removeItem(at: lockDirPath)
        }
        manager.installedModels.removeAll { $0.id == model.id }

        #expect(!manager.installedModels.contains(where: { $0.fullName == "org/test-model" }))
    }

    @Test("cleanStaleDownloads skips non-model directories")
    func testSkipNonModelDirs() throws {
        let testDir = try createTestCacheDir()
        defer { cleanup(testDir) }

        let otherDir = testDir.appendingPathComponent("other-folder")
        try fm.createDirectory(at: otherDir, withIntermediateDirectories: true)
        try Data(repeating: 0xFF, count: 100).write(to: otherDir.appendingPathComponent("file.txt"))

        let manager = ModelManager()
        manager.cleanStaleDownloads()

        #expect(fm.fileExists(atPath: otherDir.path))
    }

    @Test("cleanStaleDownloads skips dotfiles in blobs")
    func testSkipsDotfilesInBlobs() throws {
        let testDir = try createTestCacheDir()
        defer { cleanup(testDir) }

        let blobsDir = testDir.appendingPathComponent("models--org--test").appendingPathComponent("blobs")
        let snapshotsDir = testDir.appendingPathComponent("models--org--test").appendingPathComponent("snapshots").appendingPathComponent("abc")
        try fm.createDirectory(at: blobsDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: snapshotsDir, withIntermediateDirectories: true)

        try Data(repeating: 0xFF, count: 200).write(
            to: blobsDir.appendingPathComponent("abc12345def67890")
        )
        try Data(repeating: 0xFF, count: 50).write(
            to: blobsDir.appendingPathComponent(".DS_Store")
        )

        let manager = ModelManager()
        manager.cleanStaleDownloads()

        #expect(fm.fileExists(atPath: blobsDir.appendingPathComponent(".DS_Store").path))
        #expect(fm.fileExists(atPath: blobsDir.appendingPathComponent("abc12345def67890").path))
    }
}
