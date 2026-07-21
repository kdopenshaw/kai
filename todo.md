# Kai — Autocomplete Feature Sketch

Goal: press a hotkey while writing in any text field → Kai reads the surrounding text, predicts the next sentence/paragraph, and shows it as a suggestion that can be accepted (insert inline) or dismissed.

## Architecture

```
  ┌──────────────────────────────────────────────────────────┐
  │                       User presses hotkey                │
  │                       (e.g. ⌃⇧Space)                     │
  └─────────────────────────┬────────────────────────────────┘
                            │
                            ▼
  ┌──────────────────────────────────────────────────────────┐
  │ 1. ContextReader                                          │
  │    • AXUIElementCopyAttributeValue on focused element     │
  │    • Grab AXValue (full text) + AXSelectedTextRange       │
  │    • Split into "before cursor" / "after cursor"          │
  │    • Truncate to last N chars before cursor (~2000)       │
  └─────────────────────────┬────────────────────────────────┘
                            │
                            ▼
  ┌──────────────────────────────────────────────────────────┐
  │ 2. CompletionClient                                       │
  │    • Sends {prefix, suffix} to Ollama                     │
  │    • System prompt: "Continue the text naturally. Output  │
  │      ONLY the continuation. Match tone and register."     │
  │    • num_predict ~80, temperature ~0.4, stop: ["\n\n"]    │
  └─────────────────────────┬────────────────────────────────┘
                            │
                            ▼
  ┌──────────────────────────────────────────────────────────┐
  │ 3. SuggestionOverlay                                      │
  │    • Borderless NSWindow, non-activating, click-through   │
  │    • Anchored near the text insertion point (from AX)     │
  │    • Renders suggestion in dim gray italic                │
  │    • Listens for Tab (accept) / Esc (dismiss)             │
  └─────────────────────────┬────────────────────────────────┘
                            │
                            ▼
  ┌──────────────────────────────────────────────────────────┐
  │ 4. Inserter (on accept)                                   │
  │    • AXUIElementSetAttributeValue on AXSelectedText       │
  │    • Falls back to CGEvent keystroke injection if AX      │
  │      write is rejected by the app                         │
  └──────────────────────────────────────────────────────────┘
```

## New files

- `Sources/Kai/ContextReader.swift` — pulls text + cursor position via AX
- `Sources/Kai/CompletionClient.swift` — autocomplete-flavored Ollama call (separate from `OllamaClient` which is for explanations)
- `Sources/Kai/SuggestionOverlay.swift` — floating ghost-text window
- `Sources/Kai/Inserter.swift` — writes accepted text into the focused field

## Existing files to touch

- `HotkeyManager.swift` — add a second hotkey (e.g. ⌃⇧Space) routed to an autocomplete handler
- `AppDelegate.swift` — wire up the new flow alongside the existing explain flow

## Milestones

1. **Read-only spike**
   - Press hotkey → print focused field's text + cursor position to console
   - Validates AX access works in Mail, Notes, Messages, TextEdit

2. **Completion request**
   - Add `CompletionClient`, call Ollama with prefix/suffix
   - Print completion to console (no UI yet)

3. **Floating suggestion bubble**
   - Borderless NSWindow anchored to cursor position
   - Styled ghost text, fades in on completion arrival
   - Esc key dismisses

4. **Accept flow**
   - Tab key inserts completion at cursor via AX write
   - Fallback to CGEvent keystroke injection for apps where AX write fails

5. **Polish**
   - Debounce + cancel in-flight request if user keeps typing
   - Hide bubble if focus leaves the original field
   - Smarter context window (include earlier paragraphs, not just last N chars)

6. **Stretch: web text fields**
   - Detect when focused app is a browser and AX value is empty
   - Fallback to `CGWindowListCreateImage` + Vision framework OCR for a screenshot-based read
   - Same overlay + accept flow, but accept is always keystroke injection (no AX write)

## Open questions

- **Hotkey collision**: ⌃⇧Space is taken by macOS input source switching on some setups. Candidates: ⌃⇧. (period), ⌃⇧' (quote), or a single-key like F13.
- **Tab conflict**: Tab already does something in most text fields. May need a different accept key (e.g. ⌃Space) or only intercept Tab while suggestion is visible.
- **Latency target**: qwen2.5:7b on 18GB RAM does ~20 tok/s. ~80 tokens = ~4s from hotkey to visible suggestion. Acceptable for "considered" writing, too slow for typing-speed autocomplete. If snappier is needed, consider `qwen2.5:3b` or `qwen2.5-coder:1.5b` for this specific flow.
- **Privacy scope**: AX read pulls the *entire* text field. For long emails that's fine, but worth a toggle for sensitive apps (e.g. Password Manager entries).

## Non-goals for v1

- Multi-suggestion cycling (Cursor's up/down through alternatives)
- Mid-line completions (only end-of-text for now)
- Streaming tokens into the overlay (render once when full response arrives)
