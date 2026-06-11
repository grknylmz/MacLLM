import Testing
import Foundation
@testable import MacLLM

@Suite("Constants Unit Tests")
struct ConstantsTests {

    @Test("App directory name is .macllm")
    func testAppDirectoryName() {
        #expect(Constants.appDirectoryName == ".macllm")
    }

    @Test("Venv directory name is venv")
    func testVenvDirectoryName() {
        #expect(Constants.venvDirectoryName == "venv")
    }

    @Test("Default server port is 8080")
    func testDefaultServerPort() {
        #expect(Constants.defaultServerPort == 8080)
    }

    @Test("HF cache path is correct")
    func testHFCachePath() {
        #expect(Constants.hfCachePath == ".cache/huggingface/hub")
    }

    @Test("HF models prefix is correct")
    func testHFModelsPrefix() {
        #expect(Constants.hfModelsPrefix == "models--")
    }

    @Test("System python path")
    func testSystemPythonPath() {
        #expect(Constants.systemPythonPath == "/usr/bin/python3")
    }

    @Test("App directory URL points to home/.macllm")
    func testAppDirectoryURL() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let expected = home.appendingPathComponent(".macllm")
        #expect(Constants.appDirectory == expected)
    }

    @Test("Venv URL is inside app directory")
    func testVenvURL() {
        let expected = Constants.appDirectory.appendingPathComponent("venv")
        #expect(Constants.venvURL == expected)
    }

    @Test("Python bin URL is inside venv/bin/python3")
    func testPythonBinURL() {
        let expected = Constants.venvURL.appendingPathComponent("bin/python3")
        #expect(Constants.pythonBinURL == expected)
    }

    @Test("Pip bin URL is inside venv/bin/pip3")
    func testPipBinURL() {
        let expected = Constants.venvURL.appendingPathComponent("bin/pip3")
        #expect(Constants.pipBinURL == expected)
    }

    @Test("MLX LM server path is inside venv/bin/mlx_lm.server")
    func testMlxLmServerPath() {
        let expected = Constants.venvURL.appendingPathComponent("bin/mlx_lm.server")
        #expect(Constants.mlxLmServerPath == expected)
    }

    @Test("HF cache URL points to home/.cache/huggingface/hub")
    func testHFCacheURL() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let expected = home.appendingPathComponent(".cache/huggingface/hub")
        #expect(Constants.hfCacheURL == expected)
    }
}
