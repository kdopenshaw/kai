import AppKit
import ApplicationServices

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var hotkeyManager: HotkeyManager!
    private let reader = AccessibilityReader()
    private let ollama = OllamaClient()
    private var panel: ExplanationPanel?
    private var needsInitialPrompt = false

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
        statusItem = NSStatusBar.system.statusItem(withLength: 28)
        if let button = statusItem.button {
            let font = NSFont(name: "Apple Chancery", size: 18)
                ?? NSFont(name: "Snell Roundhand", size: 18)
                ?? NSFont.systemFont(ofSize: 16, weight: .medium)
            let blue = NSColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 1.0)
            button.attributedTitle = NSAttributedString(
                string: "x",
                attributes: [.font: font, .foregroundColor: blue, .baselineOffset: -1]
            )
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Kai — Highlight Explainer", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func handleHotkey() {
        NSLog("[Kai] handleHotkey entered")

        // Toggle: if panel is visible, pressing F2 again closes it.
        if let existing = panel, existing.isVisible {
            existing.close()
            return
        }

        let text = reader.getSelectedText()
        NSLog("[Kai] Selected text length: \(text?.count ?? -1)")

        // New selection always starts a fresh conversation.
        if let text, !text.isEmpty {
            panel?.close()
            let p = ExplanationPanel()
            panel = p
            p.onFollowUp = { [weak self] question in
                self?.handleSubmit(question: question, panel: p)
            }
            needsInitialPrompt = false
            p.showThinking()
            Task {
                let explanation = await self.ollama.explain(text)
                await MainActor.run {
                    p.update(text: explanation)
                }
            }
            return
        }

        // No new selection. If we have a prior (hidden) panel, reopen it with
        // conversation state intact.
        if let existing = panel {
            existing.reopen()
            return
        }

        // First-time open with no selection — empty panel, cursor focused.
        let p = ExplanationPanel()
        panel = p
        p.onFollowUp = { [weak self] question in
            self?.handleSubmit(question: question, panel: p)
        }
        needsInitialPrompt = true
        p.showEmpty()
    }

    private func handleSubmit(question: String, panel: ExplanationPanel) {
        let firstMessage = needsInitialPrompt
        needsInitialPrompt = false
        panel.showThinking(question: question)

        Task {
            let answer: String
            if firstMessage {
                answer = await self.ollama.explain(question)
            } else {
                answer = await self.ollama.followUp(question)
            }
            await MainActor.run {
                panel.show(text: answer)
            }
        }
    }
}
