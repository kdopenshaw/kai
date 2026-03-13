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
        let text = reader.getSelectedText()
        print("[Kai] Selected text: \(text ?? "<nil>")")
        guard let text, !text.isEmpty else { return }

        panel?.close()
        let p = ExplanationPanel()
        panel = p

        p.onFollowUp = { [weak self] question in
            self?.handleFollowUp(question: question, panel: p)
        }

        p.show(text: "Thinking...")

        Task {
            let explanation = await self.ollama.explain(text)
            await MainActor.run {
                p.update(text: explanation)
            }
        }
    }

    private func handleFollowUp(question: String, panel: ExplanationPanel) {
        panel.appendToThread(question: question, answer: "Thinking...")

        Task {
            let answer = await self.ollama.followUp(question)
            await MainActor.run {
                // Rebuild the full thread display
                let messages = self.ollama.messages
                var display = ""
                for msg in messages {
                    guard let role = msg["role"], let content = msg["content"] else { continue }
                    if role == "system" { continue }
                    if role == "user" {
                        if !display.isEmpty { display += "\n\n" }
                        display += "▶ \(content)\n\n"
                    } else if role == "assistant" {
                        display += content
                    }
                }
                panel.update(text: display)
            }
        }
    }
}
