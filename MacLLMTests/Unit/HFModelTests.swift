import Testing
import Foundation
@testable import MacLLM

@Suite("HFModel Unit Tests")
struct HFModelTests {

    let decoder = JSONDecoder()

    @Test("Decodes HFModel from JSON with all fields")
    func testDecodeFullModel() throws {
        let json = """
        {
            "_id": "64a12345abc123",
            "modelId": "mlx-community/Qwen3.5-27B-4bit",
            "author": "mlx-community",
            "downloads": 15234,
            "tags": ["mlx", "4bit"],
            "pipeline_tag": "text-generation",
            "createdAt": "2024-01-01T00:00:00",
            "lastModified": "2024-06-01T00:00:00",
            "library_name": "mlx",
            "siblings": [
                {"rfilename": "config.json", "size": 512},
                {"rfilename": "model.safetensors", "size": 5368709120}
            ],
            "cardData": {
                "license": "apache-2.0",
                "language": ["en"],
                "tags": ["mlx"]
            }
        }
        """.data(using: .utf8)!

        let model = try decoder.decode(HFModel.self, from: json)
        #expect(model.id == "mlx-community/Qwen3.5-27B-4bit")
        #expect(model.internalId == "64a12345abc123")
        #expect(model.modelId == "mlx-community/Qwen3.5-27B-4bit")
        #expect(model.author == "mlx-community")
        #expect(model.downloads == 15234)
        #expect(model.tags == ["mlx", "4bit"])
        #expect(model.pipelineTag == "text-generation")
        #expect(model.libraryName == "mlx")
        #expect(model.siblings?.count == 2)
        #expect(model.siblings?[0].rfilename == "config.json")
        #expect(model.siblings?[0].size == 512)
        #expect(model.cardData?.license == "apache-2.0")
        #expect(model.cardData?.language == ["en"])
    }

    @Test("Decodes HFModel with minimal fields")
    func testDecodeMinimal() throws {
        let json = """
        {
            "_id": "abc123",
            "modelId": "org/model"
        }
        """.data(using: .utf8)!

        let model = try decoder.decode(HFModel.self, from: json)
        #expect(model.id == "org/model")
        #expect(model.internalId == "abc123")
        #expect(model.modelId == "org/model")
        #expect(model.author == nil)
        #expect(model.downloads == nil)
        #expect(model.tags == nil)
        #expect(model.siblings == nil)
        #expect(model.cardData == nil)
    }

    @Test("Decodes array of HFModel")
    func testDecodeArray() throws {
        let json = """
        [
            {"_id": "1", "modelId": "org/model-a"},
            {"_id": "2", "modelId": "org/model-b"},
            {"_id": "3", "modelId": "org/model-c"}
        ]
        """.data(using: .utf8)!

        let models = try decoder.decode([HFModel].self, from: json)
        #expect(models.count == 3)
        #expect(models[0].modelId == "org/model-a")
        #expect(models[2].modelId == "org/model-c")
    }

    @Test("formattedDownloads shows millions")
    func testFormattedDownloadsMillions() {
        let json = """
        {"_id": "1", "modelId": "org/model", "downloads": 2500000}
        """.data(using: .utf8)!
        let model = try! decoder.decode(HFModel.self, from: json)
        #expect(model.formattedDownloads == "2.5M")
    }

    @Test("formattedDownloads shows thousands")
    func testFormattedDownloadsThousands() {
        let json = """
        {"_id": "1", "modelId": "org/model", "downloads": 15400}
        """.data(using: .utf8)!
        let model = try! decoder.decode(HFModel.self, from: json)
        #expect(model.formattedDownloads == "15.4K")
    }

    @Test("formattedDownloads shows exact for under 1000")
    func testFormattedDownloadsSmall() {
        let json = """
        {"_id": "1", "modelId": "org/model", "downloads": 42}
        """.data(using: .utf8)!
        let model = try! decoder.decode(HFModel.self, from: json)
        #expect(model.formattedDownloads == "42")
    }

    @Test("formattedDownloads returns empty string for nil")
    func testFormattedDownloadsNil() {
        let json = """
        {"_id": "1", "modelId": "org/model"}
        """.data(using: .utf8)!
        let model = try! decoder.decode(HFModel.self, from: json)
        #expect(model.formattedDownloads == "")
    }

    @Test("formattedLikes shows millions")
    func testFormattedLikesMillions() {
        let json = """
        {"_id": "1", "modelId": "org/model", "likes": 1500000}
        """.data(using: .utf8)!
        let model = try! decoder.decode(HFModel.self, from: json)
        #expect(model.formattedLikes == "1.5M")
    }

    @Test("formattedLikes shows thousands")
    func testFormattedLikesThousands() {
        let json = """
        {"_id": "1", "modelId": "org/model", "likes": 3500}
        """.data(using: .utf8)!
        let model = try! decoder.decode(HFModel.self, from: json)
        #expect(model.formattedLikes == "3.5K")
    }

    @Test("formattedLikes shows exact for under 1000")
    func testFormattedLikesSmall() {
        let json = """
        {"_id": "1", "modelId": "org/model", "likes": 42}
        """.data(using: .utf8)!
        let model = try! decoder.decode(HFModel.self, from: json)
        #expect(model.formattedLikes == "42")
    }

    @Test("formattedLikes returns empty string for nil")
    func testFormattedLikesNil() {
        let json = """
        {"_id": "1", "modelId": "org/model"}
        """.data(using: .utf8)!
        let model = try! decoder.decode(HFModel.self, from: json)
        #expect(model.formattedLikes == "")
    }

    @Test("Decodes HFModel with likes and trendingScore")
    func testDecodeWithLikesAndTrendingScore() throws {
        let json = """
        {
            "_id": "abc123",
            "modelId": "org/model",
            "likes": 500,
            "trendingScore": 42
        }
        """.data(using: .utf8)!

        let model = try decoder.decode(HFModel.self, from: json)
        #expect(model.likes == 500)
        #expect(model.trendingScore == 42)
    }

    @Test("displayName returns modelId")
    func testDisplayName() throws {
        let json = """
        {"_id": "1", "modelId": "mlx-community/Qwen3.5-27B-4bit"}
        """.data(using: .utf8)!
        let model = try decoder.decode(HFModel.self, from: json)
        #expect(model.displayName == "mlx-community/Qwen3.5-27B-4bit")
    }

    @Test("Conformance to Identifiable uses modelId")
    func testIdentifiable() throws {
        let json = """
        {"_id": "unique-id-123", "modelId": "org/model"}
        """.data(using: .utf8)!
        let model = try decoder.decode(HFModel.self, from: json)
        #expect(model.id == "org/model")
    }
}

@Suite("HFSibling Unit Tests")
struct HFSiblingTests {

    @Test("Decodes HFSibling with size")
    func testDecodeWithSize() throws {
        let json = """
        {"rfilename": "model.safetensors", "size": 1073741824}
        """.data(using: .utf8)!
        let sibling = try JSONDecoder().decode(HFSibling.self, from: json)
        #expect(sibling.rfilename == "model.safetensors")
        #expect(sibling.size == 1073741824)
    }

    @Test("Decodes HFSibling without size")
    func testDecodeWithoutSize() throws {
        let json = """
        {"rfilename": "config.json"}
        """.data(using: .utf8)!
        let sibling = try JSONDecoder().decode(HFSibling.self, from: json)
        #expect(sibling.rfilename == "config.json")
        #expect(sibling.size == nil)
    }
}

@Suite("HFCardData Unit Tests")
struct HFCardDataTests {

    @Test("Decodes HFCardData with all fields")
    func testDecodeFull() throws {
        let json = """
        {
            "license": "mit",
            "language": ["en", "fr"],
            "tags": ["mlx", "text-generation"]
        }
        """.data(using: .utf8)!
        let card = try JSONDecoder().decode(HFCardData.self, from: json)
        #expect(card.license == "mit")
        #expect(card.language == ["en", "fr"])
        #expect(card.tags == ["mlx", "text-generation"])
    }

    @Test("Decodes HFCardData with empty object")
    func testDecodeEmpty() throws {
        let json = """
        {}
        """.data(using: .utf8)!
        let card = try JSONDecoder().decode(HFCardData.self, from: json)
        #expect(card.license == nil)
        #expect(card.language == nil)
        #expect(card.tags == nil)
    }
}

@Suite("HFModelSearchResponse Unit Tests")
struct HFModelSearchResponseTests {

    @Test("Decodes HFModelSearchResponse from array")
    func testDecodeFromArray() throws {
        let json = """
        [
            {"_id": "1", "modelId": "org/a"},
            {"_id": "2", "modelId": "org/b"}
        ]
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(HFModelSearchResponse.self, from: json)
        #expect(response.models.count == 2)
        #expect(response.models[0].modelId == "org/a")
    }

    @Test("Decodes empty array")
    func testDecodeEmptyArray() throws {
        let json = """
        []
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(HFModelSearchResponse.self, from: json)
        #expect(response.models.isEmpty)
    }

    @Test("Skips invalid entries and continues decoding")
    func testSkipsInvalidEntries() throws {
        let json = """
        [
            {"_id": "1", "modelId": "org/a"},
            {"invalid": true},
            {"_id": "3", "modelId": "org/c"}
        ]
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(HFModelSearchResponse.self, from: json)
        #expect(response.models.count == 2)
        #expect(response.models[0].modelId == "org/a")
        #expect(response.models[1].modelId == "org/c")
    }
}
