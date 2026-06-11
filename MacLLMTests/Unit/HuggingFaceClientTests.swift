import Testing
import Foundation
@testable import MacLLM

@MainActor
@Suite("HuggingFaceClient Unit Tests", .serialized)
struct HuggingFaceClientTests {

    @Test("Empty query clears existing results via network fetch")
    func testEmptyQuery() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLCapturingProtocol.self]
        URLCapturingProtocol.reset()
        URLCapturingProtocol.mockData = "[]".data(using: .utf8)!
        URLCapturingProtocol.mockStatusCode = 200

        let session = URLSession(configuration: config)
        let client = HuggingFaceClient(session: session)
        client.searchResults = [
            HFModel(internalId: "1", modelId: "test", author: nil, downloads: nil, likes: nil, trendingScore: nil, tags: nil, pipelineTag: nil, createdAt: nil, lastModified: nil, libraryName: nil, siblings: nil, cardData: nil)
        ]

        await client.search(query: "")
        #expect(client.searchResults.isEmpty)
        #expect(client.error == nil)
        #expect(client.isSearching == false)
    }

    @Test("Whitespace-only query is treated as empty")
    func testWhitespaceQuery() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLCapturingProtocol.self]
        URLCapturingProtocol.reset()
        URLCapturingProtocol.mockData = "[]".data(using: .utf8)!
        URLCapturingProtocol.mockStatusCode = 200

        let session = URLSession(configuration: config)
        let client = HuggingFaceClient(session: session)
        await client.search(query: "   ")
        #expect(client.searchResults.isEmpty)
        #expect(client.isSearching == false)
    }

    @Test("Initial state")
    func testInitialState() {
        let client = HuggingFaceClient()
        #expect(client.searchResults.isEmpty)
        #expect(client.isSearching == false)
        #expect(client.error == nil)
    }

    @Test("HFError searchFailed has correct description")
    func testHFErrorDescription() {
        let error = HuggingFaceClient.HFError.searchFailed("HTTP 500")
        #expect(error.errorDescription == "Search failed: HTTP 500")
    }

    @Test("Search constructs correct URL components for short and full path queries")
    func testSearchURLConstruction() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLCapturingProtocol.self]
        URLCapturingProtocol.reset()
        URLCapturingProtocol.mockData = "[]".data(using: .utf8)!
        URLCapturingProtocol.mockStatusCode = 200

        let session = URLSession(configuration: config)

        let client1 = HuggingFaceClient(session: session)
        await client1.search(query: "qwen")
        #expect(client1.error == nil)
        #expect(client1.searchResults.isEmpty)

        URLCapturingProtocol.mockData = "[]".data(using: .utf8)!
        let session2 = URLSession(configuration: config)
        let client2 = HuggingFaceClient(session: session2)
        await client2.search(query: "mlx-community/Qwen3.5-27B-4bit")
        #expect(client2.error == nil)
    }

    @Test("searchPopularMLX uses most downloads sort and MLX library filter")
    func testSearchPopularMLX() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLCapturingProtocol.self]
        URLCapturingProtocol.reset()
        URLCapturingProtocol.mockData = "[]".data(using: .utf8)!
        URLCapturingProtocol.mockStatusCode = 200

        let session = URLSession(configuration: config)
        let client = HuggingFaceClient(session: session)
        await client.searchPopularMLX()
        #expect(client.error == nil)
        #expect(client.isSearching == false)

        let captured = URLCapturingProtocol.capturedURL
        #expect(captured != nil)
        let query = captured!.query ?? ""
        #expect(query.contains("sort=downloads"))
        #expect(query.contains("filter=mlx"))
    }

    @Test("Search handles HTTP error response")
    func testSearchHTTPError() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLCapturingProtocol.self]
        URLCapturingProtocol.reset()
        URLCapturingProtocol.mockData = Data()
        URLCapturingProtocol.mockStatusCode = 500

        let session = URLSession(configuration: config)
        let client = HuggingFaceClient(session: session)
        await client.search(query: "test")
        #expect(client.error != nil)
        #expect(client.isSearching == false)
    }

    @Test("Search returns decoded models")
    func testSearchReturnsModels() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLCapturingProtocol.self]
        URLCapturingProtocol.reset()
        URLCapturingProtocol.mockData = """
        [{"_id":"1","modelId":"org/test-model","downloads":100}]
        """.data(using: .utf8)!
        URLCapturingProtocol.mockStatusCode = 200

        let session = URLSession(configuration: config)
        let client = HuggingFaceClient(session: session)
        await client.search(query: "test")
        #expect(client.searchResults.count == 1)
        #expect(client.searchResults[0].modelId == "org/test-model")
        #expect(client.searchResults[0].downloads == 100)
    }
}

@Suite("HFSortOption Tests")
struct HFSortOptionTests {

    @Test("All cases have correct API values")
    func testApiSortValues() {
        #expect(HFSortOption.trending.apiSortValue == "trending")
        #expect(HFSortOption.mostDownloads.apiSortValue == "downloads")
        #expect(HFSortOption.mostLikes.apiSortValue == "likes")
        #expect(HFSortOption.recentlyCreated.apiSortValue == "createdAt")
        #expect(HFSortOption.recentlyUpdated.apiSortValue == "lastModified")
    }

    @Test("All cases are present in CaseIterable")
    func testCaseIterable() {
        #expect(HFSortOption.allCases.count == 5)
    }

    @Test("Raw values match display names")
    func testRawValues() {
        #expect(HFSortOption.trending.rawValue == "Trending")
        #expect(HFSortOption.mostDownloads.rawValue == "Most Downloads")
        #expect(HFSortOption.mostLikes.rawValue == "Most Likes")
        #expect(HFSortOption.recentlyCreated.rawValue == "Recently Created")
        #expect(HFSortOption.recentlyUpdated.rawValue == "Recently Updated")
    }
}

@Suite("HFTaskFilter Tests")
struct HFTaskFilterTests {

    @Test("All filter has nil API value")
    func testAllFilterNilValue() {
        #expect(HFTaskFilter.all.apiTagValue == nil)
    }

    @Test("textGeneration has correct API value")
    func testTextGenerationValue() {
        #expect(HFTaskFilter.textGeneration.apiTagValue == "text-generation")
    }

    @Test("All cases are present in CaseIterable")
    func testCaseIterable() {
        #expect(HFTaskFilter.allCases.count == 16)
    }

    @Test("All non-all filters have non-nil API values")
    func testNonNilApiValues() {
        for filter in HFTaskFilter.allCases where filter != .all {
            #expect(filter.apiTagValue != nil, "\(filter.rawValue) should have non-nil apiTagValue")
        }
    }
}

@Suite("HFLibraryFilter Tests")
struct HFLibraryFilterTests {

    @Test("All filter has nil API value")
    func testAllFilterNilValue() {
        #expect(HFLibraryFilter.all.apiFilterValue == nil)
    }

    @Test("MLX filter has correct API value")
    func testMLXValue() {
        #expect(HFLibraryFilter.mlx.apiFilterValue == "mlx")
    }

    @Test("All cases are present in CaseIterable")
    func testCaseIterable() {
        #expect(HFLibraryFilter.allCases.count == 11)
    }

    @Test("All non-all filters have non-nil API values")
    func testNonNilApiValues() {
        for filter in HFLibraryFilter.allCases where filter != .all {
            #expect(filter.apiFilterValue != nil, "\(filter.rawValue) should have non-nil apiFilterValue")
        }
    }
}

final class URLCapturingProtocol: URLProtocol {
    nonisolated(unsafe) static var capturedURL: URL?
    nonisolated(unsafe) static var mockData: Data = Data()
    nonisolated(unsafe) static var mockStatusCode: Int = 200

    static func reset() {
        capturedURL = nil
        mockData = Data()
        mockStatusCode = 200
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.capturedURL = request.url
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: Self.mockStatusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.mockData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
