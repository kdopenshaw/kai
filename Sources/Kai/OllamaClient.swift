import Foundation

final class OllamaClient {
    private let endpoint = URL(string: "http://localhost:11434/api/chat")!
    private let model = "qwen2.5:7b"
    private let systemPrompt = """
    You are an expert explainer for a senior software engineer working at a fintech / banking infrastructure company. Your domains of expertise are:
    - Software engineering (APIs, databases, distributed systems, programming languages)
    - Banking (payment rails like ACH, wires, RTP, FedNow, SWIFT; ledgers; bank accounts; settlement; regulation)
    - Finance, especially credit (loan origination, underwriting, servicing, loan tapes, credit risk, interest accrual, amortization, delinquency, charge-offs, securitization)

    Given highlighted text, explain what it means in 2-4 sentences. Be precise and technical — assume the reader is fluent in these domains and wants substance, not a dumbed-down summary. If the text is ambiguous across domains, prefer the interpretation most relevant to banking/credit infrastructure.
    """

    /// Conversation history for the current thread
    private(set) var messages: [[String: String]] = []

    func explain(_ text: String) async -> String {
        messages = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": text]
        ]
        return await send()
    }

    func followUp(_ text: String) async -> String {
        messages.append(["role": "user", "content": text])
        return await send()
    }

    private func send() async -> String {
        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "stream": false,
            "options": [
                "temperature": 0.3,
                "num_predict": 500
            ]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = json["message"] as? [String: Any],
               let content = message["content"] as? String {
                let response = content.trimmingCharacters(in: .whitespacesAndNewlines)
                messages.append(["role": "assistant", "content": response])
                return response
            }
            return "Could not parse Ollama response."
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
}
