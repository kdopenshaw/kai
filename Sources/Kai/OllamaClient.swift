import Foundation

final class OllamaClient {
    private let endpoint = URL(string: "http://localhost:11434/api/chat")!
    private let model = "qwen2.5:7b"
    private let systemPrompt = """
    You are Kai, an extremely sharp technical tutor. You explain things clearly and precisely across any subject — science, math, engineering, software, history, language, philosophy, whatever comes up. Assume the reader is intelligent and curious; give substance, not a dumbed-down summary. Default to 2-4 sentences unless more detail is clearly warranted.
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
