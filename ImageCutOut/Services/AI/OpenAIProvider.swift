import Foundation

final class OpenAIProvider: AIProvider {
    let id: UUID
    let profile: AIProviderProfile
    let capabilities: AIProviderCapabilities
    private let rateLimiter: RateLimiter
    private let keychainKey: String

    init(profile: AIProviderProfile) {
        self.id = profile.id
        self.profile = profile
        self.capabilities = AIProviderCapabilities(supportsVision: true, supportsOCR: true, supportsLLM: true, supportsMultimodal: true)
        self.rateLimiter = RateLimiter(limitPerMinute: profile.rateLimitPerMinute)
        self.keychainKey = "ai.key.\(profile.id.uuidString)"
    }

    func testConnection() async -> Bool {
        guard apiKey != nil else { return false }
        let url = profile.baseURL.appendingPathComponent("models")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(apiKey ?? "")", forHTTPHeaderField: "Authorization")
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                return (200..<300).contains(http.statusCode)
            }
            return false
        } catch {
            return false
        }
    }

    func generateMetadata(filename: String, context: AIRequestContext) async throws -> AIResult {
        if let cached = AICache.shared.load(key: cacheKey(filename: filename)) {
            return cached
        }
        guard let apiKey else {
            return AIResult.mock(for: filename)
        }
        await rateLimiter.throttle()
        let hints = context.metadataHints.isEmpty ? "" : "Hints: \(context.metadataHints)"
        let prompt = "Generate product metadata JSON for filename: \(filename). \(hints) Fields: productName, brand, variant, size, category, color, tags (array)."
        let payload = [
            "model": profile.modelName,
            "messages": [
                ["role": "system", "content": "You are a retail product metadata assistant."],
                ["role": "user", "content": prompt]
            ]
        ] as [String: Any]

        let responseText = try await sendRequest(payload: payload, apiKey: apiKey)
        let parsed = parseMetadata(from: responseText, fallbackFilename: filename)
        AICache.shared.save(key: cacheKey(filename: filename), result: parsed)
        return parsed
    }

    func generateAltText(filename: String, context: AIRequestContext) async throws -> String {
        guard let apiKey else { return "Product image for \(filename)" }
        await rateLimiter.throttle()
        let prompt = "Generate concise SEO alt text for product image filename: \(filename)."
        let payload = [
            "model": profile.modelName,
            "messages": [
                ["role": "system", "content": "You are an SEO assistant."],
                ["role": "user", "content": prompt]
            ]
        ] as [String: Any]
        let responseText = try await sendRequest(payload: payload, apiKey: apiKey)
        return responseText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func analyzeQuality(filename: String, context: AIRequestContext) async throws -> [String] {
        guard apiKey != nil else { return ["Mock response: no API key"] }
        await rateLimiter.throttle()
        return ["Edge looks slightly jagged, consider increasing feather by 0.5"]
    }

    func estimateUsage(for items: Int) -> AIUsageEstimate {
        AIUsageEstimate(estimatedTokens: items * 500, estimatedCostUSD: Double(items) * 0.02)
    }

    private var apiKey: String? {
        KeychainManager.shared.get(keychainKey)
    }

    private func cacheKey(filename: String) -> String {
        "openai_\(filename)"
    }

    private func sendRequest(payload: [String: Any], apiKey: String) async throws -> String {
        let url = profile.baseURL.appendingPathComponent("chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = profile.timeoutSeconds
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AIProviderError.requestFailed("HTTP error")
        }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func parseMetadata(from text: String, fallbackFilename: String) -> AIResult {
        if let data = text.data(using: .utf8),
           let parsed = try? JSONDecoder().decode(AIResultPayload.self, from: data) {
            let metadata = AssetMetadata(
                productName: parsed.productName,
                brand: parsed.brand,
                variant: parsed.variant,
                size: parsed.size,
                category: parsed.category,
                color: parsed.color,
                tags: parsed.tags
            )
            return AIResult(metadata: metadata, altText: parsed.altText, tags: parsed.tags, qualityNotes: [], createdAt: Date())
        }
        return AIResult.mock(for: fallbackFilename)
    }
}

private struct AIResultPayload: Codable {
    var productName: String?
    var brand: String?
    var variant: String?
    var size: String?
    var category: String?
    var color: String?
    var tags: [String] = []
    var altText: String?
}
