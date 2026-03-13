import Foundation

final class OllamaClient {
    private let endpoint = URL(string: "http://localhost:11434/api/generate")!
    private let model = "llama3.2:3b"

    func explain(_ text: String) async -> String {
        let body: [String: Any] = [
            "model": model,
            "system": "You are a concise explainer. Given highlighted text, explain what it means in 2-4 sentences. Be clear and direct.",
            "prompt": text,
            "stream": false,
            "options": [
                "temperature": 0.3,
                "num_predict": 200
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
               let response = json["response"] as? String {
                return response.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return "Could not parse Ollama response."
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
}
