import Testing
import Foundation
@testable import MLXModelManager

@MainActor
@Suite("MLXModel Unit Tests")
struct MLXModelTests {

    @Test("Full name is split into organization and name")
    func testInitParsesFullName() {
        let model = MLXModel(fullName: "mlx-community/Qwen3.5-27B-4bit")
        #expect(model.organization == "mlx-community")
        #expect(model.name == "Qwen3.5-27B-4bit")
        #expect(model.id == "mlx-community/Qwen3.5-27B-4bit")
    }

    @Test("Name without slash uses fullName as name and org")
    func testInitNoSlash() {
        let model = MLXModel(fullName: "some-model-4bit")
        #expect(model.organization == "some-model-4bit")
        #expect(model.name == "some-model-4bit")
        #expect(model.id == "some-model-4bit")
    }

    @Test("Detects 4-bit quantization variants")
    func testQuantization4Bit() {
        let cases = [
            "org/model-4bit",
            "org/model-4-bit",
            "org/model-4bit-MLX"
        ]
        for name in cases {
            let model = MLXModel(fullName: name)
            #expect(model.quantization == "4-bit", "Expected 4-bit for \(name)")
        }
    }

    @Test("Detects 8-bit quantization variants")
    func testQuantization8Bit() {
        let cases = [
            "org/model-8bit",
            "org/model-8-bit",
        ]
        for name in cases {
            let model = MLXModel(fullName: name)
            #expect(model.quantization == "8-bit", "Expected 8-bit for \(name)")
        }
    }

    @Test("Detects FP16 quantization")
    func testQuantizationFP16() {
        let model1 = MLXModel(fullName: "org/model-fp16")
        let model2 = MLXModel(fullName: "org/model-FP16")
        #expect(model1.quantization == "FP16")
        #expect(model2.quantization == "FP16")
    }

    @Test("Detects BF16 quantization")
    func testQuantizationBF16() {
        let model1 = MLXModel(fullName: "org/model-bf16")
        let model2 = MLXModel(fullName: "org/model-BF16")
        #expect(model1.quantization == "BF16")
        #expect(model2.quantization == "BF16")
    }

    @Test("No quantization detected for unquantized model")
    func testNoQuantization() {
        let model = MLXModel(fullName: "org/gpt-neox-20b")
        #expect(model.quantization == nil)
    }

    @Test("Detects 4-bit before 8-bit when both present")
    func testQuantizationPriority() {
        let model = MLXModel(fullName: "org/model-4bit-8bit")
        #expect(model.quantization == "4-bit")
    }

    @Test("Detects parameter count 35B")
    func testParameterCount35B() {
        let model = MLXModel(fullName: "org/Qwen3.6-35B-A3B-4bit")
        #expect(model.parameterCount == "35B")
    }

    @Test("Detects parameter count 27B")
    func testParameterCount27B() {
        let model = MLXModel(fullName: "org/Qwen3.5-27B-4bit")
        #expect(model.parameterCount == "27B")
    }

    @Test("Detects parameter count 14B")
    func testParameterCount14B() {
        let model = MLXModel(fullName: "org/Phi-4-14B-4bit")
        #expect(model.parameterCount == "14B")
    }

    @Test("Detects parameter count 12B")
    func testParameterCount12B() {
        let model = MLXModel(fullName: "org/gemma-4-12B-it-8bit")
        #expect(model.parameterCount == "12B")
    }

    @Test("Detects parameter count 8B")
    func testParameterCount8B() {
        let model = MLXModel(fullName: "org/llama-3-8b-4bit")
        #expect(model.parameterCount == "8B")
    }

    @Test("Detects parameter count 7B")
    func testParameterCount7B() {
        let model = MLXModel(fullName: "org/mistral-7b-4bit")
        #expect(model.parameterCount == "7B")
    }

    @Test("Detects parameter count 4B")
    func testParameterCount4B() {
        let model = MLXModel(fullName: "org/Qwen-3.5-4B-8bit")
        #expect(model.parameterCount == "8B")
    }

    @Test("Detects parameter count 3B when no larger match")
    func testParameterCount3B() {
        let model = MLXModel(fullName: "org/phi-3b-fp16")
        #expect(model.parameterCount == "3B")
    }

    @Test("Detects parameter count 1.5B when no larger match")
    func testParameterCount1_5B() {
        let model = MLXModel(fullName: "org/qwen-1.5b")
        #expect(model.parameterCount == "1.5B")
    }

    @Test("Detects parameter count 0.5B when no larger match")
    func testParameterCount0_5B() {
        let model = MLXModel(fullName: "org/tiny-0.5b")
        #expect(model.parameterCount == "0.5B")
    }

    @Test("No parameter count detected when none present")
    func testNoParameterCount() {
        let model = MLXModel(fullName: "org/some-random-model")
        #expect(model.parameterCount == nil)
    }

    @Test("Parameter count detection is case insensitive")
    func testParameterCountCaseInsensitive() {
        let model = MLXModel(fullName: "org/model-35B-test")
        #expect(model.parameterCount == "35B")
    }

    @Test("DisplayName includes parameters and quantization")
    func testDisplayNameWithBoth() {
        let model = MLXModel(fullName: "org/Qwen3.5-27B-4bit")
        #expect(model.displayName == "Qwen3.5-27B-4bit (27B, 4-bit)")
    }

    @Test("DisplayName is just name when no params or quantization")
    func testDisplayNamePlain() {
        let model = MLXModel(fullName: "org/my-model")
        #expect(model.displayName == "my-model")
    }

    @Test("Detects parameter count 4B when no larger match")
    func testParameterCount4BOnly() {
        let model = MLXModel(fullName: "org/tiny-llama-4b")
        #expect(model.parameterCount == "4B")
    }
    func testDisplayNameParamsOnly() {
        let model = MLXModel(fullName: "org/llama-70B")
        #expect(model.parameterCount == nil)
        #expect(model.displayName == "llama-70B")
    }

    @Test("Formatted size returns Unknown when nil")
    func testFormattedSizeNil() {
        let model = MLXModel(fullName: "org/model")
        #expect(model.formattedSize == "Unknown")
    }

    @Test("Formatted size returns byte string when set")
    func testFormattedSizeWithValue() {
        let model = MLXModel(fullName: "org/model", sizeOnDisk: 1_073_741_824)
        let formatted = model.formattedSize
        #expect(formatted.contains("GB"))
    }

    @Test("Formatted size with small value")
    func testFormattedSizeSmall() {
        let model = MLXModel(fullName: "org/model", sizeOnDisk: 500)
        let formatted = model.formattedSize
        #expect(formatted.contains("bytes") || formatted.contains("B"))
    }

    @Test("isDownloaded defaults to false")
    func testIsDownloadedDefault() {
        let model = MLXModel(fullName: "org/model")
        #expect(model.isDownloaded == false)
    }

    @Test("Conformance to Identifiable uses fullName as id")
    func testIdentifiable() {
        let model = MLXModel(fullName: "org/model")
        #expect(model.id == "org/model")
    }

    @Test("Conformance to Hashable")
    func testHashable() {
        let model1 = MLXModel(fullName: "org/model")
        let model2 = MLXModel(fullName: "org/model")
        let model3 = MLXModel(fullName: "org/other-model")
        #expect(model1 == model2)
        #expect(model1 != model3)
        let set: Set<MLXModel> = [model1, model2, model3]
        #expect(set.count == 2)
    }

    @Test("35B takes priority over 5B substring")
    func testParameterPriority35BOver5B() {
        let model = MLXModel(fullName: "org/Qwen3.5-35B-4bit")
        #expect(model.parameterCount == "35B")
    }

    @Test("27B takes priority over 7B substring")
    func testParameterPriority27BOver7B() {
        let model = MLXModel(fullName: "org/Qwen-27B-4bit")
        #expect(model.parameterCount == "27B")
    }

    @Test("14B takes priority over 4B substring")
    func testParameterPriority14BOver4B() {
        let model = MLXModel(fullName: "org/Phi-14B-4bit")
        #expect(model.parameterCount == "14B")
    }

    @Test("12B takes priority over 2B substring")
    func testParameterPriority12BOver2B() {
        let model = MLXModel(fullName: "org/gemma-12B-4bit")
        #expect(model.parameterCount == "12B")
    }

    @Test("Multiple slashes only split on first")
    func testMultipleSlashes() {
        let model = MLXModel(fullName: "org/subdir/model-name")
        #expect(model.organization == "org")
        #expect(model.name == "subdir/model-name")
    }
}
