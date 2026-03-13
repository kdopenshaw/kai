import AppKit
import ApplicationServices

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var hotkeyManager: HotkeyManager!
    private let reader = AccessibilityReader()
    private let ollama = OllamaClient()
    private var panel: ExplanationPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        ensureOllamaRunning()
        ensureAccessibility()
        setupMenuBar()

        hotkeyManager = HotkeyManager { [weak self] in
            DispatchQueue.main.async {
                self?.handleHotkey()
            }
        }
        hotkeyManager.start()
    }

    private func ensureOllamaRunning() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/brew")
        task.arguments = ["services", "start", "ollama"]
        task.standardOutput = nil
        task.standardError = nil
        try? task.run()
        task.waitUntilExit()
    }

    private func ensureAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) {
            print("Kai needs Accessibility permission. A system prompt should appear.")
        }
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.title = "K"
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Kai — Highlight Explainer", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func handleHotkey() {
        let text = reader.getSelectedText()
        print("[Kai] Selected text: \(text ?? "<nil>")")
        guard let text, !text.isEmpty else { return }

        panel?.close()
        let p = ExplanationPanel()
        panel = p
        p.show(text: "Thinking...")

        Task {
            let explanation = await self.ollama.explain(text)
            await MainActor.run {
                p.update(text: explanation)
            }
        }
    }
}
