import Foundation

struct AppProcessInfo: Identifiable {
    let id: Int32
    let pid: Int32
    let name: String
    let command: String
    let memoryMB: Double
    let cpuPercent: Double
    let isMLX: Bool

    var formattedMemory: String {
        if memoryMB >= 1024 {
            return String(format: "%.1f GB", memoryMB / 1024.0)
        }
        return String(format: "%.0f MB", memoryMB)
    }

    var displayName: String {
        let maxLen = 20
        if name.count <= maxLen { return name }
        return String(name.prefix(maxLen - 1)) + "..."
    }
}
