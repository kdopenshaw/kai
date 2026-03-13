# Kai — macOS Highlight Explainer

Menu bar app that explains highlighted text using a local LLM. Select text in any app, press **Ctrl+Shift**, and get a concise explanation in a floating panel.

## How it works

1. Reads selected text via macOS Accessibility APIs (clipboard fallback for Chrome/Electron apps)
2. Sends it to a local [Ollama](https://ollama.com) instance (`llama3.2:3b`)
3. Shows the explanation in a floating panel near your cursor

## Setup

```bash
# Install Ollama and pull the model
brew install ollama
brew services start ollama
ollama pull llama3.2:3b

# Install Swift (if not already available)
curl -O https://download.swift.org/swiftly/darwin/swiftly.pkg && \
installer -pkg swiftly.pkg -target CurrentUserHomeDirectory && \
~/.swiftly/bin/swiftly init --quiet-shell-followup && \
. "${SWIFTLY_HOME_DIR:-$HOME/.swiftly}/env.sh"

# Build
cd ~/dev/repos/kai
swift build
```

## Run

### As an app (no terminal needed)

```bash
./build-app.sh
cp -r Kai.app /Applications/Kai.app
```

Then launch from Spotlight or Finder. Grant **Accessibility** and **Input Monitoring** permissions in System Settings → Privacy & Security.

### From terminal

```bash
# Add to ~/.zshrc:
alias kai="~/dev/repos/kai/.build/debug/Kai"

# Then just:
kai
```

## Usage

- **Ctrl+Shift** — explain highlighted text
- **Escape** — dismiss the panel
- **Menu bar "K" → Quit** — exit Kai

## Requirements

- macOS 14+
- Ollama with `llama3.2:3b`
