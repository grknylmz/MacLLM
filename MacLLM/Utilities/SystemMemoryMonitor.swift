import Foundation
import Observation
import AppKit

enum MemoryWarningLevel {
    case normal
    case warning
    case critical
}

@Observable
@MainActor
class SystemMemoryMonitor {
    var totalGB: Double = 0
    var usedGB: Double = 0
    var freeGB: Double = 0
    var usedPercentage: Double = 0
    var topProcesses: [AppProcessInfo] = []

    @ObservationIgnored private var timer: Timer?

    var warningThreshold: Double {
        let val = UserDefaults.standard.double(forKey: "memoryWarningThreshold")
        return val > 0 ? min(max(val, 0.5), 0.95) : 0.9
    }

    var warningLevel: MemoryWarningLevel {
        if usedPercentage >= warningThreshold + 0.05 {
            return .critical
        } else if usedPercentage >= warningThreshold {
            return .warning
        }
        return .normal
    }

    func startMonitoring() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    @discardableResult
    func killProcess(pid: Int32) -> Bool {
        let result = kill(pid, SIGTERM)
        if result != 0 {
            return false
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            let checkResult = kill(pid, 0)
            if checkResult == 0 {
                _ = kill(pid, SIGKILL)
            }
        }
        return true
    }

    private func refresh() {
        refreshMemory()
        refreshProcesses()
    }

    private func refreshMemory() {
        var pageSize: Int32 = 0
        var vmStats = vm_statistics64()

        let hostPort = mach_host_self()
        var size: mach_msg_type_number_t = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<natural_t>.size)

        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: natural_t.self, capacity: Int(size)) {
                host_statistics64(hostPort, HOST_VM_INFO64, $0, &size)
            }
        }

        var physMem: Int64 = 0
        var physMemSize = MemoryLayout<Int64>.size
        sysctlbyname("hw.memsize", &physMem, &physMemSize, nil, 0)

        var pageSizeVal: Int64 = 0
        var pageSizeSize = MemoryLayout<Int64>.size
        sysctlbyname("hw.pagesize", &pageSizeVal, &pageSizeSize, nil, 0)
        pageSize = Int32(pageSizeVal)

        if result == KERN_SUCCESS {
            let activePages = Int64(vmStats.active_count)
            let wiredPages = Int64(vmStats.wire_count)
            let compressedPages = Int64(vmStats.compressor_page_count)
            let usedBytes = (activePages + wiredPages + compressedPages) * Int64(pageSize)
            let totalBytes = physMem

            totalGB = Double(totalBytes) / 1_073_741_824.0
            usedGB = Double(usedBytes) / 1_073_741_824.0
            freeGB = totalGB - usedGB
            usedPercentage = totalGB > 0 ? usedGB / totalGB : 0
        }
    }

    private func refreshProcesses() {
        let mlxPID = UserDefaults.standard.integer(forKey: "_lastKnownMLXPID")
        let mlxPIDVal: Int32? = mlxPID > 0 ? Int32(mlxPID) : nil

        DispatchQueue.global(qos: .utility).async { [weak self] in
            let task = Process()
            let pipe = Pipe()
            task.executableURL = URL(fileURLWithPath: "/bin/ps")
            task.arguments = ["aux", "-m"]
            task.standardOutput = pipe
            task.standardError = FileHandle.nullDevice
            task.standardInput = FileHandle.nullDevice

            do {
                try task.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                task.waitUntilExit()
                guard let output = String(data: data, encoding: .utf8) else { return }
                let parsed = Self.parseProcessList(output, mlxPID: mlxPIDVal)
                Task { @MainActor [weak self] in
                    self?.topProcesses = parsed
                }
            } catch {}
        }
    }

    nonisolated private static func parseProcessList(_ output: String, mlxPID: Int32?) -> [AppProcessInfo] {
        var processes: [AppProcessInfo] = []
        let lines = output.split(separator: "\n", omittingEmptySubsequences: true)

        for line in lines.dropFirst() {
            let fields = line.split(separator: " ", omittingEmptySubsequences: true)
                .map { String($0) }
            guard fields.count >= 11 else { continue }

            guard let pid = Int32(fields[1]),
                  let cpu = Double(fields[2]),
                  let rssKB = Double(fields[5]) else { continue }

            let command = fields.dropFirst(10).joined(separator: " ")
            let name = extractProcessName(command: command)
            let memoryMB = rssKB / 1024.0

            let isMLX: Bool
            if let mlxPID {
                isMLX = pid == mlxPID
            } else {
                isMLX = command.contains("mlx_lm")
            }

            processes.append(AppProcessInfo(
                id: pid,
                pid: pid,
                name: name,
                command: command,
                memoryMB: memoryMB,
                cpuPercent: cpu,
                isMLX: isMLX
            ))
        }

        let mlxProcesses = processes.filter(\.isMLX).sorted { $0.memoryMB > $1.memoryMB }
        let otherProcesses = processes
            .filter { !$0.isMLX }
            .filter { !shouldFilterOut($0) }
            .sorted { $0.memoryMB > $1.memoryMB }

        var result: [AppProcessInfo] = []
        result.append(contentsOf: mlxProcesses)
        let remainingSlots = max(0, 3 - result.count)
        result.append(contentsOf: Array(otherProcesses.prefix(remainingSlots)))

        return result
    }

    nonisolated private static func shouldFilterOut(_ proc: AppProcessInfo) -> Bool {
        let filteredNames = [
            "kernel_task", "WindowServer", "loginwindow", "Dock",
            "Finder", "SystemUIServer", "launchd", "syslogd",
            "cfprefsd", "distnoted", "securityd", "coreaudiod",
            "backgroundtaskmanagement", "Terminal", "ps"
        ]
        let lower = proc.name.lowercased()
        return filteredNames.contains { lower.contains($0.lowercased()) }
            || proc.memoryMB < 10
            || proc.command.hasSuffix("/ps aux -rss")
    }

    nonisolated private static func extractProcessName(command: String) -> String {
        if let lastSlash = command.lastIndex(of: "/") {
            let afterSlash = command[lastSlash...].dropFirst()
            if !afterSlash.isEmpty {
                let firstPart = afterSlash.split(separator: " ").first
                if let part = firstPart {
                    return String(part)
                }
            }
        }
        return String(command.split(separator: " ").first ?? Substring(command))
    }

    deinit {
        timer?.invalidate()
    }
}
