import Foundation

struct HFModelSearchResponse: Decodable {
    let models: [HFModel]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawModels = (try? container.decode([FailableDecodable<HFModel>].self)) ?? []
        self.models = rawModels.compactMap(\.value)
    }
}

private struct FailableDecodable<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws {
        value = try? T(from: decoder)
    }
}

struct HFModel: Decodable, Identifiable {
    var id: String { modelId }
    let internalId: String
    let modelId: String
    let author: String?
    let downloads: Int?
    let likes: Int?
    let trendingScore: Int?
    let tags: [String]?
    let pipelineTag: String?
    let createdAt: String?
    let lastModified: String?
    let libraryName: String?
    let siblings: [HFSibling]?
    let cardData: HFCardData?

    var displayName: String {
        modelId
    }

    var formattedDownloads: String {
        guard let d = downloads else { return "" }
        if d >= 1_000_000 {
            return String(format: "%.1fM", Double(d) / 1_000_000)
        } else if d >= 1_000 {
            return String(format: "%.1fK", Double(d) / 1_000)
        }
        return "\(d)"
    }

    var formattedLikes: String {
        guard let l = likes else { return "" }
        if l >= 1_000_000 {
            return String(format: "%.1fM", Double(l) / 1_000_000)
        } else if l >= 1_000 {
            return String(format: "%.1fK", Double(l) / 1_000)
        }
        return "\(l)"
    }

    enum CodingKeys: String, CodingKey {
        case internalId = "_id"
        case modelId
        case author
        case downloads
        case likes
        case trendingScore
        case tags
        case pipelineTag = "pipeline_tag"
        case createdAt
        case lastModified
        case libraryName = "library_name"
        case siblings
        case cardData
    }
}

struct HFSibling: Decodable {
    let rfilename: String
    let size: Int?
}

struct HFCardData: Decodable {
    let license: String?
    let language: [String]?
    let tags: [String]?
}
