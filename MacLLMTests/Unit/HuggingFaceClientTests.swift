import Testing
import Foundation
@testable import MacLLM

@MainActor
@Suite("HuggingFaceClient Unit Tests")
struct HuggingFaceClientTests {

    @Test("Empty query clears results")
    func testEmptyQuery() async {
        let client = HuggingFaceClient()
        client.searchResults = [
            HFModel(id: "1", modelId: "test", author: nil, downloads: nil, tags: nil, pipelineTag: nil, createdAt: nil, lastModified: nil, libraryName: nil, siblings: nil, cardData: nil)
        ]

        await client.search(query: "")
        #expect(client.searchResults.isEmpty)
        #expect(client.error == nil)
        #expect(client.isSearching == false)
    }

    @Test("Whitespace-only query is treated as empty")
    func testWhitespaceQuery() async {
        let client = HuggingFaceClient()
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
        URLCapturingProtocol.mockData = "[]".data(using: .utf8)!
        URLCapturingProtocol.mockStatusCode = 200

        let session = URLSession(configuration: config)

        let client1 = HuggingFaceClient(session: session)
        await client1.search(query: "qwen")
        #expect(client1.error == nil)
        #expect(client1.searchResults.isEmpty)

        let session2 = URLSession(configuration: config)
        let client2 = HuggingFaceClient(session: session2)
        await client2.search(query: "mlx-community/Qwen3.5-27B-4bit")
        #expect(client2.error == nil)
    }
}

final class URLCapturingProtocol: URLProtocol {
    nonisolated(unsafe) static var capturedURL: URL?
    nonisolated(unsafe) static var mockData: Data = Data()
    nonisolated(unsafe) static var mockStatusCode: Int = 200

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
