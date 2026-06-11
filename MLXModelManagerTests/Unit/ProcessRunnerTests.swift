import Testing
import Foundation
@testable import MLXModelManager

@Suite("ProcessRunner Unit Tests")
struct ProcessRunnerTests {

    @Test("Run simple echo command captures stdout")
    func testRunEcho() async throws {
        let result = try await ProcessRunner.run(
            executable: "/bin/echo",
            arguments: ["hello world"]
        )
        #expect(result.success)
        #expect(result.stdout.contains("hello world"))
        #expect(result.exitCode == 0)
    }

    @Test("Run command that writes to stderr")
    func testRunStderr() async throws {
        let result = try await ProcessRunner.runShell("echo 'error msg' >&2")
        #expect(result.success)
        #expect(result.stderr.contains("error msg"))
    }

    @Test("Run command with non-zero exit code")
    func testRunNonZeroExit() async throws {
        let result = try await ProcessRunner.runShell("exit 42")
        #expect(!result.success)
        #expect(result.exitCode == 42)
    }

    @Test("Run nonexistent executable returns error")
    func testRunNonexistentExecutable() async throws {
        let result = try await ProcessRunner.run(
            executable: "/nonexistent/path/binary"
        )
        #expect(!result.success)
        #expect(result.exitCode == -1)
        #expect(!result.stderr.isEmpty)
    }

    @Test("Run with environment variables")
    func testRunWithEnvironment() async throws {
        let result = try await ProcessRunner.runShell(
            "echo $MY_TEST_VAR",
            environment: ["MY_TEST_VAR": "test_value_123"]
        )
        #expect(result.success)
        #expect(result.stdout.contains("test_value_123"))
    }

    @Test("Run with working directory")
    func testRunWithWorkingDirectory() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
        let result = try await ProcessRunner.run(
            executable: "/bin/pwd",
            workingDirectory: tmpDir
        )
        #expect(result.success)
        #expect(result.stdout.contains(tmpDir.path))
    }

    @Test("Run shell command via runShell")
    func testRunShell() async throws {
        let result = try await ProcessRunner.runShell("echo 'shell test' && echo 'second line'")
        #expect(result.success)
        #expect(result.stdout.contains("shell test"))
        #expect(result.stdout.contains("second line"))
    }

    @Test("Run shell with pipe")
    func testRunShellPipe() async throws {
        let result = try await ProcessRunner.runShell("echo 'a b c' | tr ' ' '\\n' | sort")
        #expect(result.success)
        let lines = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(lines == "a\nb\nc")
    }

    @Test("ProcessResult success property")
    func testProcessResultSuccess() {
        let successResult = ProcessResult(stdout: "", stderr: "", exitCode: 0)
        #expect(successResult.success)

        let failResult = ProcessResult(stdout: "", stderr: "error", exitCode: 1)
        #expect(!failResult.success)
    }

    @Test("Run captures multiline output")
    func testRunMultilineOutput() async throws {
        let result = try await ProcessRunner.runShell("for i in 1 2 3; do echo \"line $i\"; done")
        #expect(result.success)
        #expect(result.stdout.contains("line 1"))
        #expect(result.stdout.contains("line 2"))
        #expect(result.stdout.contains("line 3"))
    }
}

@Suite("ProcessRunner runWithOutput Tests")
struct ProcessRunnerWithOutputTests {

    @Test("runWithOutput captures stdout via callback")
    func testRunWithOutputCallback() async throws {
        var capturedOutput: [String] = []

        let result = try await ProcessRunner.runWithOutput(
            executable: "/bin/echo",
            arguments: ["callback test"],
            onStdout: { output in
                capturedOutput.append(output)
            },
            onStderr: { _ in }
        )

        #expect(result.success)
        #expect(result.stdout.contains("callback test"))
        let combined = capturedOutput.joined()
        #expect(combined.contains("callback test"))
    }

    @Test("runWithOutput captures stderr via callback")
    func testRunWithOutputStderr() async throws {
        var capturedStderr: [String] = []

        let result = try await ProcessRunner.runWithOutput(
            executable: "/bin/zsh",
            arguments: ["-c", "echo 'err' >&2"],
            onStdout: { _ in },
            onStderr: { output in
                capturedStderr.append(output)
            }
        )

        #expect(result.success)
        let combined = capturedStderr.joined()
        #expect(combined.contains("err"))
    }
}
