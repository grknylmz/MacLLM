import Foundation
import Observation

@Observable
@MainActor
class HuggingFaceClient {
    var searchResults: [HFModel] = []
    var isSearching = false
    var error: String?

    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 15
            config.timeoutIntervalForResource = 30
            self.session = URLSession(configuration: config)
        }
    }

    func search(query: String, limit: Int = 20) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        error = nil
        searchResults = []

        let isFullPath = trimmed.contains("/")

        let baseURL = "https://huggingface.co/api/models"

        var components = URLComponents(string: baseURL)!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "sort", value: "downloads"),
            URLQueryItem(name: "direction", value: "-1"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]

        if isFullPath {
            queryItems.append(URLQueryItem(name: "search", value: trimmed))
        } else {
            queryItems.append(URLQueryItem(name: "search", value: "mlx-community \(trimmed)"))
        }

        queryItems.append(URLQueryItem(name: "filter", value: "mlx"))
        components.queryItems = queryItems

        guard let url = components.url else {
            error = "Invalid search URL"
            isSearching = false
            return
        }

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                throw HFError.searchFailed("HTTP \(statusCode)")
            }

            let models = try JSONDecoder().decode([HFModel].self, from: data)
            searchResults = models
        } catch {
            self.error = error.localizedDescription
        }

        isSearching = false
    }

    func searchPopularMLX() async {
        isSearching = true
        error = nil

        var components = URLComponents(string: "https://huggingface.co/api/models")!
        components.queryItems = [
            URLQueryItem(name: "author", value: "mlx-community"),
            URLQueryItem(name: "sort", value: "downloads"),
            URLQueryItem(name: "direction", value: "-1"),
            URLQueryItem(name: "limit", value: "20")
        ]

        guard let url = components.url else {
            error = "Invalid URL"
            isSearching = false
            return
        }

        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw HFError.searchFailed("HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            }

            searchResults = try JSONDecoder().decode([HFModel].self, from: data)
        } catch {
            self.error = error.localizedDescription
        }

        isSearching = false
    }

    enum HFError: LocalizedError {
        case searchFailed(String)

        var errorDescription: String? {
            switch self {
            case .searchFailed(let msg): return "Search failed: \(msg)"
            }
        }
    }
}
