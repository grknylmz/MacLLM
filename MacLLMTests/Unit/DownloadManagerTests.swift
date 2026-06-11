import Testing
import Foundation
@testable import MacLLM

@MainActor
@Suite("DownloadManager Unit Tests", .serialized)
struct DownloadManagerTests {

    private let fm = FileManager.default

    private func createTestCacheDir() throws -> URL {
        let testDir = fm.temporaryDirectory
            .appendingPathComponent("mlx-test-download-\(UUID().uuidString)")
        try fm.createDirectory(at: testDir, withIntermediateDirectories: true)
        return testDir
    }

    private func cleanup(_ url: URL) {
        try? fm.removeItem(at: url)
    }

    private func makeManager() -> DownloadManager {
        DownloadManager(modelManager: nil, serverManager: nil)
    }

    @Test("initial state is empty")
    func testInitialState() {
        let manager = makeManager()
        #expect(manager.downloads.isEmpty)
        #expect(manager.completedDownloads.isEmpty)
        #expect(manager.state(for: "org/model") == .idle)
        #expect(!manager.hasIncompleteDownloads())
        #expect(manager.incompleteDownloadIds().isEmpty)
    }

    @Test("state returns idle for unknown models")
    func testStateForUnknown() {
        let manager = makeManager()
        #expect(manager.state(for: "nonexistent/model") == .idle)
    }

    @Test("clearDownload removes state and completed entry")
    func testClearDownload() {
        let manager = makeManager()
        manager.downloads["org/model"] = .completed
        manager.completedDownloads = ["org/model"]

        manager.clearDownload("org/model")

        #expect(manager.downloads["org/model"] == nil)
        #expect(!manager.completedDownloads.contains("org/model"))
    }

    @Test("clearDownload on nonexistent model does nothing")
    func testClearNonexistent() {
        let manager = makeManager()
        manager.clearDownload("org/nonexistent")
        #expect(manager.downloads.isEmpty)
    }

    @Test("hasIncompleteDownloads returns true for downloading")
    func testHasIncompleteDownloading() {
        let manager = makeManager()
        manager.downloads["org/model"] = .downloading(progress: 0.5)
        #expect(manager.hasIncompleteDownloads())
    }

    @Test("hasIncompleteDownloads returns true for paused")
    func testHasIncompletePaused() {
        let manager = makeManager()
        manager.downloads["org/model"] = .paused
        #expect(manager.hasIncompleteDownloads())
    }

    @Test("hasIncompleteDownloads returns true for failed")
    func testHasIncompleteFailed() {
        let manager = makeManager()
        manager.downloads["org/model"] = .failed("error")
        #expect(manager.hasIncompleteDownloads())
    }

    @Test("hasIncompleteDownloads returns false for completed")
    func testHasIncompleteCompleted() {
        let manager = makeManager()
        manager.downloads["org/model"] = .completed
        #expect(!manager.hasIncompleteDownloads())
    }

    @Test("hasIncompleteDownloads returns false for idle only")
    func testHasIncompleteIdleOnly() {
        let manager = makeManager()
        manager.downloads["org/model"] = .idle
        #expect(!manager.hasIncompleteDownloads())
    }

    @Test("incompleteDownloadIds returns correct IDs")
    func testIncompleteDownloadIds() {
        let manager = makeManager()
        manager.downloads["org/a"] = .downloading(progress: 0.1)
        manager.downloads["org/b"] = .completed
        manager.downloads["org/c"] = .failed("err")
        manager.downloads["org/d"] = .paused
        manager.downloads["org/e"] = .idle

        let ids = manager.incompleteDownloadIds().sorted()
        #expect(ids == ["org/a", "org/c", "org/d"])
    }

    @Test("stopDownload sets failed state")
    func testStopDownload() {
        let manager = makeManager()
        manager.downloads["org/model"] = .downloading(progress: 0.3)
        manager.stopDownload("org/model")
        #expect(manager.downloads["org/model"] == .failed("Download cancelled"))
    }

    @Test("pauseDownload does nothing without active process")
    func testPauseDownload() {
        let manager = makeManager()
        manager.downloads["org/model"] = .downloading(progress: 0.3)
        manager.pauseDownload("org/model")
        #expect(manager.downloads["org/model"] == .downloading(progress: 0.3))
    }

    @Test("resumeDownload restarts download when no active process")
    func testResumeDownloadRestarts() {
        let manager = makeManager()
        manager.downloads["org/model"] = .paused
        manager.resumeDownload("org/model")

        #expect(manager.downloads["org/model"]?.isActive == true)
    }

    // MARK: - detectInterruptedDownloads

    @Test("detectInterruptedDownloads finds .incomplete blobs")
    func testDetectInterruptedWithIncompleteFiles() throws {
        let testDir = try createTestCacheDir()
        defer { cleanup(testDir) }

        let cacheName = "models--org--test-model"
        let blobsDir = testDir.appendingPathComponent(cacheName).appendingPathComponent("blobs")
        try fm.createDirectory(at: blobsDir, withIntermediateDirectories: true)

        try Data(repeating: 0xFF, count: 512).write(
            to: blobsDir.appendingPathComponent("abc12345def.incomplete")
        )

        let manager = makeManager()
        manager.detectInterruptedDownloads(in: testDir)

        #expect(manager.downloads["org/test-model"] == .paused)
    }

    @Test("detectInterruptedDownloads skips completed models")
    func testDetectInterruptedSkipsComplete() throws {
        let testDir = try createTestCacheDir()
        defer { cleanup(testDir) }

        let cacheName = "models--org--test-model"
        let modelDir = testDir.appendingPathComponent(cacheName)
        let blobsDir = modelDir.appendingPathComponent("blobs")
        let snapshotsDir = modelDir.appendingPathComponent("snapshots").appendingPathComponent("abc123")
        try fm.createDirectory(at: blobsDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: snapshotsDir, withIntermediateDirectories: true)

        try Data(repeating: 0xFF, count: 512).write(
            to: blobsDir.appendingPathComponent("abc12345def67890")
        )
        try Data(repeating: 0xFF, count: 256).write(
            to: blobsDir.appendingPathComponent("bbb12345def67890")
        )

        let manager = makeManager()
        manager.detectInterruptedDownloads(in: testDir)

        #expect(manager.downloads["org/test-model"] == nil)
    }

    @Test("detectInterruptedDownloads finds blobs without snapshots")
    func testDetectInterruptedNoSnapshots() throws {
        let testDir = try createTestCacheDir()
        defer { cleanup(testDir) }

        let cacheName = "models--org--test-model"
        let blobsDir = testDir.appendingPathComponent(cacheName).appendingPathComponent("blobs")
        try fm.createDirectory(at: blobsDir, withIntermediateDirectories: true)

        try Data(repeating: 0xFF, count: 512).write(
            to: blobsDir.appendingPathComponent("abc12345def67890")
        )

        let manager = makeManager()
        manager.detectInterruptedDownloads(in: testDir)

        #expect(manager.downloads["org/test-model"] == .paused)
    }

    @Test("detectInterruptedDownloads skips dirs with no blobs")
    func testDetectInterruptedNoBlobs() throws {
        let testDir = try createTestCacheDir()
        defer { cleanup(testDir) }

        let cacheName = "models--org--test-model"
        let modelDir = testDir.appendingPathComponent(cacheName)
        try fm.createDirectory(at: modelDir, withIntermediateDirectories: true)

        let manager = makeManager()
        manager.detectInterruptedDownloads(in: testDir)

        #expect(manager.downloads["org/test-model"] == nil)
    }

    @Test("detectInterruptedDownloads skips non-model directories")
    func testDetectInterruptedSkipsNonModel() throws {
        let testDir = try createTestCacheDir()
        defer { cleanup(testDir) }

        let blobsDir = testDir.appendingPathComponent("other-folder").appendingPathComponent("blobs")
        try fm.createDirectory(at: blobsDir, withIntermediateDirectories: true)
        try Data(repeating: 0xFF, count: 100).write(
            to: blobsDir.appendingPathComponent("abc123.incomplete")
        )

        let manager = makeManager()
        manager.detectInterruptedDownloads(in: testDir)

        #expect(manager.downloads.isEmpty)
    }

    @Test("detectInterruptedDownloads handles mixed complete and incomplete blobs")
    func testDetectInterruptedMixed() throws {
        let testDir = try createTestCacheDir()
        defer { cleanup(testDir) }

        let cacheName = "models--org--test-model"
        let blobsDir = testDir.appendingPathComponent(cacheName).appendingPathComponent("blobs")
        try fm.createDirectory(at: blobsDir, withIntermediateDirectories: true)

        try Data(repeating: 0xFF, count: 512).write(
            to: blobsDir.appendingPathComponent("abc12345def67890")
        )
        try Data(repeating: 0xFF, count: 256).write(
            to: blobsDir.appendingPathComponent("bbb12345def67890.incomplete")
        )

        let manager = makeManager()
        manager.detectInterruptedDownloads(in: testDir)

        #expect(manager.downloads["org/test-model"] == .paused)
    }

    @Test("detectInterruptedDownloads handles empty blobs dir with 'incomplete' sentinel")
    func testDetectInterruptedEmptyBlobs() throws {
        let testDir = try createTestCacheDir()
        defer { cleanup(testDir) }

        let cacheName = "models--org--test-model"
        let blobsDir = testDir.appendingPathComponent(cacheName).appendingPathComponent("blobs")
        try fm.createDirectory(at: blobsDir, withIntermediateDirectories: true)

        try Data(repeating: 0xFF, count: 10).write(
            to: blobsDir.appendingPathComponent("incomplete")
        )

        let manager = makeManager()
        manager.detectInterruptedDownloads(in: testDir)

        #expect(manager.downloads["org/test-model"] == nil)
    }

    @Test("detectInterruptedDownloads skips files (non-directories)")
    func testDetectInterruptedSkipsFiles() throws {
        let testDir = try createTestCacheDir()
        defer { cleanup(testDir) }

        try Data(repeating: 0xFF, count: 100).write(
            to: testDir.appendingPathComponent("models--some-file")
        )

        let manager = makeManager()
        manager.detectInterruptedDownloads(in: testDir)

        #expect(manager.downloads.isEmpty)
    }

    // MARK: - parseError

    @Test("parseError returns repository not found message")
    func testParseErrorRepositoryNotFound() {
        let result = DownloadManager.parseError("Error: RepositoryNotFoundError(repo_id='bad/model')")
        #expect(result == "Repository not found. Check the model ID.")
    }

    @Test("parseError returns authentication message for 401")
    func testParseError401() {
        let result = DownloadManager.parseError("HTTP 401 Unauthorized")
        #expect(result == "Authentication required. Run: huggingface-cli login")
    }

    @Test("parseError returns authentication message for Unauthorized")
    func testParseErrorUnauthorized() {
        let result = DownloadManager.parseError("Error: Unauthorized access")
        #expect(result == "Authentication required. Run: huggingface-cli login")
    }

    @Test("parseError returns gated repo message")
    func testParseErrorGatedRepo() {
        let result = DownloadManager.parseError("Error: GatedRepoError")
        #expect(result == "This is a gated model. Visit huggingface.co to accept the license.")
    }

    @Test("parseError returns first non-empty line for unknown errors")
    func testParseErrorUnknown() {
        let result = DownloadManager.parseError("some random error\nline two\nline three")
        #expect(result == "some random error")
    }

    @Test("parseError returns Unknown error for empty string")
    func testParseErrorEmpty() {
        let result = DownloadManager.parseError("")
        #expect(result == "Unknown error")
    }

    @Test("parseError returns first non-empty line skipping blanks")
    func testParseErrorSkipsBlankLines() {
        let result = DownloadManager.parseError("\n\n  \nactual error here")
        #expect(result == "actual error here")
    }

    @Test("parseError truncates long error to 150 chars")
    func testParseErrorTruncation() {
        let longError = String(repeating: "x", count: 200)
        let result = DownloadManager.parseError(longError)
        #expect(result.count == 150)
    }

    // MARK: - calculateFilesystemProgress (via detectInterruptedDownloads)

    @Test("detectInterruptedDownloads calculates progress for incomplete downloads")
    func testDetectInterruptedWithProgressCalculation() throws {
        let testDir = try createTestCacheDir()
        defer { cleanup(testDir) }

        let cacheName = "models--org--test-model"
        let modelDir = testDir.appendingPathComponent(cacheName)
        let blobsDir = modelDir.appendingPathComponent("blobs")
        let snapshotsDir = modelDir.appendingPathComponent("snapshots").appendingPathComponent("abc123")
        try fm.createDirectory(at: blobsDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: snapshotsDir, withIntermediateDirectories: true)

        try Data(repeating: 0xFF, count: 1024).write(
            to: blobsDir.appendingPathComponent("abc12345def67890")
        )
        try Data(repeating: 0xFF, count: 512).write(
            to: blobsDir.appendingPathComponent("bbb12345def67890.incomplete")
        )

        let metadataJSON: [String: Any] = [
            "metadata": ["total_size": Int64(2048)]
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: metadataJSON)
        try jsonData.write(to: blobsDir.appendingPathComponent("meta12345abcde"))

        let manager = makeManager()
        manager.detectInterruptedDownloads(in: testDir)

        #expect(manager.downloads["org/test-model"] == .paused)
    }

    @Test("detectInterruptedDownloads handles multiple models")
    func testDetectInterruptedMultipleModels() throws {
        let testDir = try createTestCacheDir()
        defer { cleanup(testDir) }

        for modelName in ["org/model-a", "org/model-b"] {
            let cacheName = "models--" + modelName.replacingOccurrences(of: "/", with: "--")
            let blobsDir = testDir.appendingPathComponent(cacheName).appendingPathComponent("blobs")
            try fm.createDirectory(at: blobsDir, withIntermediateDirectories: true)
            try Data(repeating: 0xFF, count: 256).write(
                to: blobsDir.appendingPathComponent("abc12345def67890.incomplete")
            )
        }

        let manager = makeManager()
        manager.detectInterruptedDownloads(in: testDir)

        #expect(manager.downloads["org/model-a"] == .paused)
        #expect(manager.downloads["org/model-b"] == .paused)
    }

    // MARK: - startDownload edge cases

    @Test("startDownload does not start if already active")
    func testStartDownloadAlreadyActive() {
        let manager = makeManager()
        manager.downloads["org/model"] = .downloading(progress: 0.5)
        manager.startDownload("org/model")
        #expect(manager.downloads["org/model"] == .downloading(progress: 0.5))
    }

    @Test("startDownload does not start if paused")
    func testStartDownloadWhilePaused() {
        let manager = makeManager()
        manager.downloads["org/model"] = .paused
        manager.startDownload("org/model")
        #expect(manager.downloads["org/model"] == .paused)
    }

    @Test("startDownload sets downloading state immediately")
    func testStartDownloadSetsState() {
        let manager = makeManager()
        manager.startDownload("org/model")
        #expect(manager.downloads["org/model"]?.isDownloading == true)
    }

    // MARK: - state access

    @Test("state for active download returns downloading")
    func testStateForActiveDownload() {
        let manager = makeManager()
        manager.downloads["org/model"] = .downloading(progress: 0.75)
        let state = manager.state(for: "org/model")
        #expect(state.isDownloading)
        #expect(state.progress == 0.75)
    }

    @Test("state for completed download returns completed")
    func testStateForCompleted() {
        let manager = makeManager()
        manager.downloads["org/model"] = .completed
        let state = manager.state(for: "org/model")
        #expect(state.isCompleted)
    }

    // MARK: - stopDownload edge cases

    @Test("stopDownload on idle model sets failed state")
    func testStopDownloadIdle() {
        let manager = makeManager()
        manager.downloads["org/model"] = .idle
        manager.stopDownload("org/model")
        #expect(manager.downloads["org/model"] == .failed("Download cancelled"))
    }

    @Test("stopDownload on unknown model sets failed state")
    func testStopDownloadUnknown() {
        let manager = makeManager()
        manager.stopDownload("org/unknown")
        #expect(manager.downloads["org/unknown"] == .failed("Download cancelled"))
    }
}
