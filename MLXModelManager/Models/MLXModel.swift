import Foundation

struct MLXModel: Identifiable, Hashable {
    let id: String
    let name: String
    let organization: String
    let fullName: String
    var sizeOnDisk: Int64?
    var quantization: String?
    var parameterCount: String?
    var parameterCountNumeric: Double?
    var isDownloaded: Bool = false
    var architecture: String?
    var lastRunAt: Date? {
        get {
            let key = "lastRun_\(fullName)"
            let ts = UserDefaults.standard.double(forKey: key)
            return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
        }
        set {
            let key = "lastRun_\(fullName)"
            UserDefaults.standard.set(newValue?.timeIntervalSince1970 ?? 0, forKey: key)
        }
    }

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
        if lower.contains("123b") {
            self.parameterCount = "123B"; self.parameterCountNumeric = 123
        } else if lower.contains("70b") {
            self.parameterCount = "70B"; self.parameterCountNumeric = 70
        } else if lower.contains("35b") {
            self.parameterCount = "35B"; self.parameterCountNumeric = 35
        } else if lower.contains("27b") {
            self.parameterCount = "27B"; self.parameterCountNumeric = 27
        } else if lower.contains("14b") {
            self.parameterCount = "14B"; self.parameterCountNumeric = 14
        } else if lower.contains("12b") {
            self.parameterCount = "12B"; self.parameterCountNumeric = 12
        } else if lower.contains("8b") {
            self.parameterCount = "8B"; self.parameterCountNumeric = 8
        } else if lower.contains("7b") {
            self.parameterCount = "7B"; self.parameterCountNumeric = 7
        } else if lower.contains("4b") {
            self.parameterCount = "4B"; self.parameterCountNumeric = 4
        } else if lower.contains("3b") {
            self.parameterCount = "3B"; self.parameterCountNumeric = 3
        } else if lower.contains("1.5b") {
            self.parameterCount = "1.5B"; self.parameterCountNumeric = 1.5
        } else if lower.contains("0.5b") {
            self.parameterCount = "0.5B"; self.parameterCountNumeric = 0.5
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

    var estimatedRAMGB: Double? {
        guard let params = parameterCountNumeric else { return nil }
        let bytesPerParam: Double
        switch quantization {
        case "4-bit":
            bytesPerParam = 0.5
        case "8-bit":
            bytesPerParam = 1.0
        default:
            bytesPerParam = 2.0
        }
        let modelGB = (params * 1_000_000_000 * bytesPerParam) / 1_073_741_824.0
        let kvCacheOverhead = modelGB * 0.2
        return modelGB + kvCacheOverhead
    }

    var formattedEstimatedRAM: String? {
        guard let ram = estimatedRAMGB else { return nil }
        if ram < 1 {
            return String(format: "~%.0f MB", ram * 1024)
        }
        return String(format: "~%.1f GB", ram)
    }

    var relativeLastRun: String? {
        guard let date = lastRunAt else { return nil }
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))h ago"
        } else {
            return "\(Int(interval / 86400))d ago"
        }
    }
}
