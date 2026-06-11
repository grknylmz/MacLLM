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

    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "brain", accessibilityDescription: "MLX Model Manager")
            button.image?.size = NSSize(width: 18, height: 18)
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 340, height: 520)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(
                serverManager: serverManager,
                modelManager: modelManager,
                hfClient: hfClient,
                pythonEnvManager: pythonEnvManager
            )
        )

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if let self, self.popover.isShown {
                self.closePopover()
            }
        }

        Task {
            await pythonEnvManager.setupIfNeeded()
            await modelManager.refreshModels()
            await autoStartIfConfigured()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        serverManager.stop()
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
}
