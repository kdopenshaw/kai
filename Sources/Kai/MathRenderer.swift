import Foundation

/// Converts LaTeX-ish math notation into readable Unicode text.
/// Designed as a safety net — the model is instructed to emit Unicode directly,
/// but handles fallbacks when it slips back into LaTeX habits.
enum MathRenderer {
    static func render(_ text: String) -> String {
        var s = text

        // 1. Strip display/inline math delimiters, keeping the content.
        s = s.replacingOccurrences(of: #"\\\[\s*"#, with: "\n", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\s*\\\]"#, with: "\n", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\\\(\s*"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\s*\\\)"#, with: "", options: .regularExpression)
        // $$...$$ and $...$ (leave lone $ alone — only strip paired)
        s = s.replacingOccurrences(of: #"\$\$\s*([\s\S]*?)\s*\$\$"#,
                                   with: "\n$1\n", options: .regularExpression)

        // 2. \frac{a}{b} -> a/b  (repeat to handle nested)
        for _ in 0..<3 {
            s = s.replacingOccurrences(
                of: #"\\frac\s*\{([^{}]*)\}\s*\{([^{}]*)\}"#,
                with: "($1)/($2)",
                options: .regularExpression
            )
        }

        // 3. \sqrt{x} -> √(x), \sqrt[n]{x} -> ⁿ√(x)
        s = s.replacingOccurrences(of: #"\\sqrt\s*\{([^{}]*)\}"#,
                                   with: "√($1)", options: .regularExpression)

        // 4. \text{foo} -> foo
        s = s.replacingOccurrences(of: #"\\text\s*\{([^{}]*)\}"#,
                                   with: "$1", options: .regularExpression)

        // 5. \left( \right) etc. — drop the \left / \right modifiers
        s = s.replacingOccurrences(of: #"\\left"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\\right"#, with: "", options: .regularExpression)

        // 6. Symbol & greek replacements
        for (cmd, sym) in symbolMap {
            s = s.replacingOccurrences(of: cmd, with: sym)
        }

        // 7. Spacing macros
        s = s.replacingOccurrences(of: #"\\[,;!:]"#, with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\\quad"#, with: "  ", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\\qquad"#, with: "    ", options: .regularExpression)

        // 8. Superscripts: x^{abc} -> x^abc with unicode where possible; x^a single char
        s = convertScripts(s, marker: "^", map: superscriptMap)
        s = convertScripts(s, marker: "_", map: subscriptMap)

        // 9. Collapse runs of 3+ newlines
        s = s.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)

        return s
    }

    /// Convert `x^{abc}` / `x^a` (and `_{...}` / `_a`) sequences into unicode
    /// equivalents when all characters are mappable, else keep a fallback form.
    private static func convertScripts(_ text: String, marker: Character,
                                       map: [Character: Character]) -> String {
        var result = ""
        var i = text.startIndex
        while i < text.endIndex {
            let ch = text[i]
            if ch == marker, let next = text.index(i, offsetBy: 1, limitedBy: text.endIndex),
               next < text.endIndex {
                let nextChar = text[next]
                if nextChar == "{" {
                    // find matching brace
                    var depth = 1
                    var j = text.index(after: next)
                    let contentStart = j
                    while j < text.endIndex && depth > 0 {
                        if text[j] == "{" { depth += 1 }
                        else if text[j] == "}" { depth -= 1 }
                        if depth > 0 { j = text.index(after: j) }
                    }
                    if depth == 0 {
                        let content = String(text[contentStart..<j])
                        if let mapped = mapAll(content, map: map) {
                            result += mapped
                        } else {
                            result += "\(marker)\(content)"
                        }
                        i = text.index(after: j)
                        continue
                    }
                } else if !nextChar.isWhitespace {
                    // Single-char form: x^a
                    if let m = map[nextChar] {
                        result.append(m)
                    } else {
                        result.append(ch)
                        result.append(nextChar)
                    }
                    i = text.index(after: next)
                    continue
                }
            }
            result.append(ch)
            i = text.index(after: i)
        }
        return result
    }

    private static func mapAll(_ s: String, map: [Character: Character]) -> String? {
        var out = ""
        for c in s {
            guard let m = map[c] else { return nil }
            out.append(m)
        }
        return out
    }

    private static let superscriptMap: [Character: Character] = [
        "0":"⁰","1":"¹","2":"²","3":"³","4":"⁴","5":"⁵","6":"⁶","7":"⁷","8":"⁸","9":"⁹",
        "+":"⁺","-":"⁻","=":"⁼","(":"⁽",")":"⁾",
        "a":"ᵃ","b":"ᵇ","c":"ᶜ","d":"ᵈ","e":"ᵉ","f":"ᶠ","g":"ᵍ","h":"ʰ","i":"ⁱ","j":"ʲ",
        "k":"ᵏ","l":"ˡ","m":"ᵐ","n":"ⁿ","o":"ᵒ","p":"ᵖ","r":"ʳ","s":"ˢ","t":"ᵗ","u":"ᵘ",
        "v":"ᵛ","w":"ʷ","x":"ˣ","y":"ʸ","z":"ᶻ"
    ]

    private static let subscriptMap: [Character: Character] = [
        "0":"₀","1":"₁","2":"₂","3":"₃","4":"₄","5":"₅","6":"₆","7":"₇","8":"₈","9":"₉",
        "+":"₊","-":"₋","=":"₌","(":"₍",")":"₎",
        "a":"ₐ","e":"ₑ","h":"ₕ","i":"ᵢ","j":"ⱼ","k":"ₖ","l":"ₗ","m":"ₘ","n":"ₙ","o":"ₒ",
        "p":"ₚ","r":"ᵣ","s":"ₛ","t":"ₜ","u":"ᵤ","v":"ᵥ","x":"ₓ"
    ]

    private static let symbolMap: [String: String] = [
        // Operators / relations
        "\\int": "∫", "\\iint": "∬", "\\iiint": "∭", "\\oint": "∮",
        "\\sum": "∑", "\\prod": "∏", "\\coprod": "∐",
        "\\infty": "∞", "\\partial": "∂", "\\nabla": "∇",
        "\\pm": "±", "\\mp": "∓", "\\cdot": "·", "\\times": "×", "\\div": "÷",
        "\\le": "≤", "\\leq": "≤", "\\ge": "≥", "\\geq": "≥",
        "\\ne": "≠", "\\neq": "≠", "\\approx": "≈", "\\equiv": "≡", "\\sim": "∼",
        "\\to": "→", "\\rightarrow": "→", "\\leftarrow": "←",
        "\\Rightarrow": "⇒", "\\Leftarrow": "⇐", "\\Leftrightarrow": "⇔",
        "\\mapsto": "↦",
        "\\in": "∈", "\\notin": "∉", "\\subset": "⊂", "\\supset": "⊃",
        "\\subseteq": "⊆", "\\supseteq": "⊇", "\\cap": "∩", "\\cup": "∪",
        "\\forall": "∀", "\\exists": "∃", "\\emptyset": "∅",
        "\\neg": "¬", "\\land": "∧", "\\lor": "∨",
        "\\ldots": "…", "\\cdots": "⋯", "\\dots": "…",
        // Greek lower
        "\\alpha": "α", "\\beta": "β", "\\gamma": "γ", "\\delta": "δ",
        "\\epsilon": "ε", "\\varepsilon": "ε", "\\zeta": "ζ", "\\eta": "η",
        "\\theta": "θ", "\\vartheta": "ϑ", "\\iota": "ι", "\\kappa": "κ",
        "\\lambda": "λ", "\\mu": "μ", "\\nu": "ν", "\\xi": "ξ", "\\pi": "π",
        "\\varpi": "ϖ", "\\rho": "ρ", "\\varrho": "ϱ", "\\sigma": "σ",
        "\\varsigma": "ς", "\\tau": "τ", "\\upsilon": "υ", "\\phi": "φ",
        "\\varphi": "ϕ", "\\chi": "χ", "\\psi": "ψ", "\\omega": "ω",
        // Greek upper
        "\\Gamma": "Γ", "\\Delta": "Δ", "\\Theta": "Θ", "\\Lambda": "Λ",
        "\\Xi": "Ξ", "\\Pi": "Π", "\\Sigma": "Σ", "\\Upsilon": "Υ",
        "\\Phi": "Φ", "\\Psi": "Ψ", "\\Omega": "Ω"
    ]
}
