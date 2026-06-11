import Testing
import Foundation
@testable import MacLLM

@Suite("ProcessResult Unit Tests")
struct ProcessResultTests {

    @Test("success is true when exitCode is 0")
    func testSuccessTrue() {
        let result = ProcessResult(stdout: "out", stderr: "", exitCode: 0)
        #expect(result.success == true)
    }

    @Test("success is false when exitCode is non-zero")
    func testSuccessFalse() {
        for code: Int32 in [-1, 1, 127, 255] {
            let result = ProcessResult(stdout: "", stderr: "err", exitCode: code)
            #expect(result.success == false, "Expected failure for exit code \(code)")
        }
    }

    @Test("Stores all fields correctly")
    func testFieldStorage() {
        let result = ProcessResult(stdout: "hello", stderr: "world", exitCode: 42)
        #expect(result.stdout == "hello")
        #expect(result.stderr == "world")
        #expect(result.exitCode == 42)
    }
}
