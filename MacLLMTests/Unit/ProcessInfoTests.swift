import Testing
import Foundation
@testable import MacLLM

@Suite("AppProcessInfo Unit Tests")
struct AppProcessInfoTests {

    @Test("formattedMemory shows MB for values under 1 GB")
    func testFormattedMemoryMB() {
        let proc = AppProcessInfo(id: 1, pid: 1, name: "Test", command: "/usr/bin/test", memoryMB: 512, cpuPercent: 5.0, isMLX: false)
        #expect(proc.formattedMemory == "512 MB")
    }

    @Test("formattedMemory shows GB for values over 1 GB")
    func testFormattedMemoryGB() {
        let proc = AppProcessInfo(id: 1, pid: 1, name: "Test", command: "/usr/bin/test", memoryMB: 2048, cpuPercent: 5.0, isMLX: false)
        #expect(proc.formattedMemory == "2.0 GB")
    }

    @Test("formattedMemory shows fractional GB")
    func testFormattedMemoryFractionalGB() {
        let proc = AppProcessInfo(id: 1, pid: 1, name: "Test", command: "/usr/bin/test", memoryMB: 1536, cpuPercent: 5.0, isMLX: false)
        #expect(proc.formattedMemory == "1.5 GB")
    }

    @Test("displayName returns name when short enough")
    func testDisplayNameShort() {
        let proc = AppProcessInfo(id: 1, pid: 1, name: "Chrome", command: "/Applications/Chrome", memoryMB: 100, cpuPercent: 1.0, isMLX: false)
        #expect(proc.displayName == "Chrome")
    }

    @Test("displayName truncates long names")
    func testDisplayNameLong() {
        let proc = AppProcessInfo(id: 1, pid: 1, name: "VeryLongProcessNameThatExceedsTwentyCharacters", command: "/path", memoryMB: 100, cpuPercent: 1.0, isMLX: false)
        let displayName = proc.displayName
        #expect(displayName.count <= 23)
        #expect(displayName.hasSuffix("..."))
        #expect(displayName.count < "VeryLongProcessNameThatExceedsTwentyCharacters".count)
    }

    @Test("id equals pid")
    func testIdEqualsPid() {
        let proc = AppProcessInfo(id: 42, pid: 42, name: "Test", command: "/test", memoryMB: 100, cpuPercent: 1.0, isMLX: false)
        #expect(proc.id == proc.pid)
    }

    @Test("isMLX flag is stored correctly")
    func testIsMLX() {
        let mlx = AppProcessInfo(id: 1, pid: 1, name: "mlx_lm.server", command: "/venv/bin/mlx_lm.server", memoryMB: 100, cpuPercent: 1.0, isMLX: true)
        let notMLX = AppProcessInfo(id: 2, pid: 2, name: "Chrome", command: "/Apps/Chrome", memoryMB: 100, cpuPercent: 1.0, isMLX: false)
        #expect(mlx.isMLX == true)
        #expect(notMLX.isMLX == false)
    }

    @Test("conformance to Identifiable")
    func testIdentifiable() {
        let proc = AppProcessInfo(id: 42, pid: 42, name: "Test", command: "/test", memoryMB: 100, cpuPercent: 1.0, isMLX: false)
        #expect(proc.id == 42)
    }
}
