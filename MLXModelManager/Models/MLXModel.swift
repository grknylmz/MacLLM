import Foundation

struct MLXModel: Identifiable, Hashable {
    let id: String
    let name: String
    let organization: String
    let fullName: String
    var sizeOnDisk: Int64?
    var quantization: String?
    var parameterCount: String?
    var isDownloaded: Bool = false

    init(fullName: String, sizeOnDisk: Int64? = nil) {
        self.fullName = fullName
        let parts = fullName.split(separator: "/", maxSplits: 1).map(String.init)
        self.organization = parts.count > 0 ? parts[0] : ""
        self.name = parts.count > 1 ? parts[1] : fullName
        self.id = fullName
        self.sizeOnDisk = sizeOnDisk

        if name.contains("4bit") || name.contains("4-bit") || name.contains("-4bit") {
            self.quantization = "4-bit"
        } else if name.contains("8bit") || name.contains("8-bit") || name.contains("-8bit") {
            self.quantization = "8-bit"
        } else if name.contains("fp16") || name.contains("FP16") {
            self.quantization = "FP16"
        } else if name.contains("bf16") || name.contains("BF16") {
            self.quantization = "BF16"
        }

        let lower = name.lowercased()
        if lower.contains("35b") {
            self.parameterCount = "35B"
        } else if lower.contains("27b") {
            self.parameterCount = "27B"
        } else if lower.contains("14b") {
            self.parameterCount = "14B"
        } else if lower.contains("12b") {
            self.parameterCount = "12B"
        } else if lower.contains("8b") {
            self.parameterCount = "8B"
        } else if lower.contains("7b") {
            self.parameterCount = "7B"
        } else if lower.contains("4b") {
            self.parameterCount = "4B"
        } else if lower.contains("3b") {
            self.parameterCount = "3B"
        } else if lower.contains("1.5b") {
            self.parameterCount = "1.5B"
        } else if lower.contains("0.5b") {
            self.parameterCount = "0.5B"
        }
    }

    var displayName: String {
        let parts = [parameterCount, quantization].compactMap { $0 }
        if parts.isEmpty {
            return name
        }
        return "\(name) (\(parts.joined(separator: ", ")))"
    }

    var formattedSize: String {
        guard let size = sizeOnDisk else { return "Unknown" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
