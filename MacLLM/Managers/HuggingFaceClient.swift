import Foundation
import Observation

enum HFSortOption: String, CaseIterable {
    case trending = "Trending"
    case mostDownloads = "Most Downloads"
    case mostLikes = "Most Likes"
    case recentlyCreated = "Recently Created"
    case recentlyUpdated = "Recently Updated"

    var apiSortValue: String {
        switch self {
        case .trending: return "trendingScore"
        case .mostDownloads: return "downloads"
        case .mostLikes: return "likes"
        case .recentlyCreated: return "createdAt"
        case .recentlyUpdated: return "lastModified"
        }
    }
}

enum HFTaskFilter: String, CaseIterable {
    case all = "All Tasks"
    case textGeneration = "Text Generation"
    case anyToAny = "Any-to-Any"
    case imageTextToText = "Image-Text-to-Text"
    case imageToText = "Image-to-Text"
    case imageToImage = "Image-to-Image"
    case textToImage = "Text-to-Image"
    case textToVideo = "Text-to-Video"
    case textToSpeech = "Text-to-Speech"
    case textToAudio = "Text-to-Audio"
    case automaticSpeechRecognition = "Automatic Speech Recognition"
    case featureExtraction = "Feature Extraction"
    case summarization = "Summarization"
    case translation = "Translation"
    case fillMask = "Fill Mask"
    case tokenClassification = "Token Classification"

    var apiTagValue: String? {
        switch self {
        case .all: return nil
        case .textGeneration: return "text-generation"
        case .anyToAny: return "any-to-any"
        case .imageTextToText: return "image-text-to-text"
        case .imageToText: return "image-to-text"
        case .imageToImage: return "image-to-image"
        case .textToImage: return "text-to-image"
        case .textToVideo: return "text-to-video"
        case .textToSpeech: return "text-to-speech"
        case .textToAudio: return "text-to-audio"
        case .automaticSpeechRecognition: return "automatic-speech-recognition"
        case .featureExtraction: return "feature-extraction"
        case .summarization: return "summarization"
        case .translation: return "translation"
        case .fillMask: return "fill-mask"
        case .tokenClassification: return "token-classification"
        }
    }
}

enum HFLibraryFilter: String, CaseIterable {
    case all = "All Libraries"
    case mlx = "MLX"
    case gguf = "GGUF"
    case pytorch = "PyTorch"
    case transformers = "Transformers"
    case safetensors = "Safetensors"
    case diffusers = "Diffusers"
    case onnx = "ONNX"
    case sentenceTransformers = "sentence-transformers"
    case jax = "JAX"
    case tensorflow = "TensorFlow"

    var apiFilterValue: String? {
        switch self {
        case .all: return nil
        case .mlx: return "mlx"
        case .gguf: return "gguf"
        case .pytorch: return "pytorch"
        case .transformers: return "transformers"
        case .safetensors: return "safetensors"
        case .diffusers: return "diffusers"
        case .onnx: return "onnx"
        case .sentenceTransformers: return "sentence-transformers"
        case .jax: return "jax"
        case .tensorflow: return "tensorflow"
        }
    }
}

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

    func search(
        query: String = "",
        sort: HFSortOption = .trending,
        task: HFTaskFilter = .all,
        library: HFLibraryFilter = .all,
        limit: Int = 30
    ) async {
        isSearching = true
        error = nil
        searchResults = []

        let baseURL = "https://huggingface.co/api/models"
        var components = URLComponents(string: baseURL)!

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "sort", value: sort.apiSortValue),
            URLQueryItem(name: "direction", value: "-1"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmed.isEmpty {
            if trimmed.contains("/") {
                queryItems.append(URLQueryItem(name: "search", value: trimmed))
            } else {
                if library == .all {
                    queryItems.append(URLQueryItem(name: "search", value: "mlx-community \(trimmed)"))
                } else {
                    queryItems.append(URLQueryItem(name: "search", value: trimmed))
                }
            }
        }

        if let taskTag = task.apiTagValue {
            queryItems.append(URLQueryItem(name: "pipeline_tag", value: taskTag))
        }

        if let libFilter = library.apiFilterValue {
            queryItems.append(URLQueryItem(name: "filter", value: libFilter))
        }

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
        await search(
            sort: .mostDownloads,
            library: .mlx
        )
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
