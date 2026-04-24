# Kai — macOS Highlight Explainer

Menu bar app that explains highlighted text using a local LLM. Select text in any app, press **F2**, and get a concise explanation in a floating panel.

## How it works

1. Reads selected text via macOS Accessibility APIs (clipboard fallback for Chrome/Electron apps)
2. Sends it to a local [Ollama](https://ollama.com) instance (`qwen2.5:7b`)
3. Shows the explanation in a floating panel near your cursor

## Requirements

- macOS 14+
- [Ollama](https://ollama.com) running locally
- Swift toolchain (included with Xcode, or installable standalone)

## Setup

### 1. Install Ollama and pull the model

```bash
brew install ollama
brew services start ollama
ollama pull qwen2.5:7b
```

### 2. Install Swift (skip if you have Xcode)

```bash
curl -O https://download.swift.org/swiftly/darwin/swiftly.pkg && \
  installer -pkg swiftly.pkg -target CurrentUserHomeDirectory && \
  ~/.swiftly/bin/swiftly init --quiet-shell-followup && \
  . "${SWIFTLY_HOME_DIR:-$HOME/.swiftly}/env.sh"
```

### 3. Clone and build

```bash
git clone https://github.com/kdopenshaw/kai.git
cd kai
swift build
```

## Run

### As an app

```bash
./build-app.sh
cp -r Kai.app /Applications/
```

Then launch from Spotlight or Finder. Grant **Accessibility** and **Input Monitoring** permissions in System Settings → Privacy & Security.

### From terminal

```bash
.build/debug/Kai
```

Or add an alias for convenience:

```bash
echo 'alias kai="/path/to/kai/.build/debug/Kai"' >> ~/.zshrc
```

## Usage

- **F2** — explain highlighted text
- **Escape** — dismiss the panel
- **Menu bar "K" → Quit** — exit Kai
