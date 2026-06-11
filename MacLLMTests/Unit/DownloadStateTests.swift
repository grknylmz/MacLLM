import Testing
import Foundation
@testable import MacLLM

@Suite("DownloadState Unit Tests")
struct DownloadStateTests {

    @Test("idle has correct properties")
    func testIdle() {
        let state = DownloadState.idle
        #expect(!state.isDownloading)
        #expect(!state.isActive)
        #expect(!state.isCompleted)
        #expect(!state.isFailed)
        #expect(state.progress == 0)
        #expect(state.errorMessage == nil)
        #expect(state.label == "Idle")
    }

    @Test("downloading has correct properties")
    func testDownloading() {
        let state = DownloadState.downloading(progress: 0.45)
        #expect(state.isDownloading)
        #expect(state.isActive)
        #expect(!state.isCompleted)
        #expect(!state.isFailed)
        #expect(state.progress == 0.45)
        #expect(state.errorMessage == nil)
        #expect(state.label == "Downloading 45%")
    }

    @Test("downloading with zero progress")
    func testDownloadingZero() {
        let state = DownloadState.downloading(progress: 0)
        #expect(state.isDownloading)
        #expect(state.progress == 0)
        #expect(state.label == "Downloading 0%")
    }

    @Test("downloading with full progress")
    func testDownloadingFull() {
        let state = DownloadState.downloading(progress: 1.0)
        #expect(state.isDownloading)
        #expect(state.progress == 1.0)
        #expect(state.label == "Downloading 100%")
    }

    @Test("downloading with very small progress")
    func testDownloadingVerySmall() {
        let state = DownloadState.downloading(progress: 0.001)
        #expect(state.isDownloading)
        #expect(state.progress == 0.001)
        #expect(state.label == "Downloading 0%")
    }

    @Test("downloading with 50 percent")
    func testDownloadingHalf() {
        let state = DownloadState.downloading(progress: 0.5)
        #expect(state.label == "Downloading 50%")
        #expect(state.progress == 0.5)
    }

    @Test("completed has correct properties")
    func testCompleted() {
        let state = DownloadState.completed
        #expect(!state.isDownloading)
        #expect(!state.isActive)
        #expect(state.isCompleted)
        #expect(!state.isFailed)
        #expect(state.progress == 0)
        #expect(state.errorMessage == nil)
        #expect(state.label == "Completed")
    }

    @Test("failed has correct properties")
    func testFailed() {
        let state = DownloadState.failed("some error")
        #expect(!state.isDownloading)
        #expect(!state.isActive)
        #expect(!state.isCompleted)
        #expect(state.isFailed)
        #expect(state.progress == 0)
        #expect(state.errorMessage == "some error")
        #expect(state.label == "Failed")
    }

    @Test("failed with empty message")
    func testFailedEmptyMessage() {
        let state = DownloadState.failed("")
        #expect(state.isFailed)
        #expect(state.errorMessage == "")
    }

    @Test("paused has correct properties")
    func testPaused() {
        let state = DownloadState.paused
        #expect(!state.isDownloading)
        #expect(state.isActive)
        #expect(!state.isCompleted)
        #expect(!state.isFailed)
        #expect(state.progress == 0)
        #expect(state.errorMessage == nil)
        #expect(state.label == "Paused")
    }

    @Test("equality works for all states")
    func testEquality() {
        #expect(DownloadState.idle == DownloadState.idle)
        #expect(DownloadState.downloading(progress: 0.5) == DownloadState.downloading(progress: 0.5))
        #expect(DownloadState.downloading(progress: 0.3) != DownloadState.downloading(progress: 0.7))
        #expect(DownloadState.completed == DownloadState.completed)
        #expect(DownloadState.failed("a") == DownloadState.failed("a"))
        #expect(DownloadState.failed("a") != DownloadState.failed("b"))
        #expect(DownloadState.paused == DownloadState.paused)
        #expect(DownloadState.idle != DownloadState.paused)
        #expect(DownloadState.completed != DownloadState.failed(""))
    }

    @Test("cross-state inequality")
    func testCrossStateInequality() {
        #expect(DownloadState.idle != DownloadState.downloading(progress: 0))
        #expect(DownloadState.idle != DownloadState.completed)
        #expect(DownloadState.idle != DownloadState.failed(""))
        #expect(DownloadState.paused != DownloadState.downloading(progress: 0))
        #expect(DownloadState.completed != DownloadState.downloading(progress: 1.0))
        #expect(DownloadState.failed("Paused") != DownloadState.paused)
    }

    @Test("errorMessage is nil for non-failed states")
    func testErrorMessageNilForNonFailed() {
        #expect(DownloadState.idle.errorMessage == nil)
        #expect(DownloadState.downloading(progress: 0.5).errorMessage == nil)
        #expect(DownloadState.completed.errorMessage == nil)
        #expect(DownloadState.paused.errorMessage == nil)
    }

    @Test("progress is 0 for non-downloading states")
    func testProgressZeroForNonDownloading() {
        #expect(DownloadState.idle.progress == 0)
        #expect(DownloadState.completed.progress == 0)
        #expect(DownloadState.failed("x").progress == 0)
        #expect(DownloadState.paused.progress == 0)
    }
}
