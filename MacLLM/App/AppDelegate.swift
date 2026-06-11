import SwiftUI
import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    let serverManager = ServerManager()
    let modelManager = ModelManager()
    let hfClient = HuggingFaceClient()
    let pythonEnvManager = PythonEnvManager()
    let memoryMonitor = SystemMemoryMonitor()
    let memoryNotifier = MemoryWarningNotifier()
    lazy var downloadManager = DownloadManager(modelManager: modelManager, serverManager: serverManager)
    lazy var chatManager = ChatManager(serverManager: serverManager)

    private var eventMonitor: Any?
    private var memoryCheckTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            let iconImage = NSImage(named: "StatusBarIcon") ?? NSImage(systemSymbolName: "brain", accessibilityDescription: "MacLLM")!
            iconImage.size = NSSize(width: 18, height: 18)
            button.image = iconImage
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 380, height: 560)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(
                serverManager: serverManager,
                modelManager: modelManager,
                hfClient: hfClient,
                pythonEnvManager: pythonEnvManager,
                memoryMonitor: memoryMonitor,
                downloadManager: downloadManager,
                chatManager: chatManager
            )
        )

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if let self, self.popover.isShown {
                self.closePopover()
            }
        }

        Task {
            memoryNotifier.requestPermission()
            memoryMonitor.startMonitoring()
            startMemoryWarningCheck()
            await pythonEnvManager.setupIfNeeded()
            await modelManager.refreshModels()
            modelManager.cleanStaleDownloads()
            downloadManager.detectInterruptedDownloads()
            await autoStartIfConfigured()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        memoryMonitor.stopMonitoring()
        memoryCheckTimer?.invalidate()
        serverManager.stop()
        serverManager.killOrphanedMLXProcesses()
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    @objc private func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closePopover() {
        popover.performClose(nil)
    }

    private func autoStartIfConfigured() async {
        let autoStart = UserDefaults.standard.bool(forKey: "autoStartServer")
        guard autoStart else { return }

        let lastModel = UserDefaults.standard.string(forKey: "lastActiveModel")
        guard let model = lastModel else { return }

        if !modelManager.installedModels.isEmpty {
            await serverManager.start(model: model)
        }
    }

    private func startMemoryWarningCheck() {
        memoryCheckTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.memoryNotifier.checkAndNotify(
                    warningLevel: self.memoryMonitor.warningLevel,
                    isServerRunning: self.serverManager.isRunning
                )
            }
        }
    }
}
