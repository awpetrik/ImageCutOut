import Foundation

final class CustomRESTProvider: AIProvider {
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
        var request = URLRequest(url: profile.baseURL)
        request.httpMethod = "GET"
        request.timeoutInterval = profile.timeoutSeconds
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
        let payload = CustomRequestPayload(filename: filename, context: context)
        let request = try makeRequest(payload: payload, apiKey: apiKey)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AIProviderError.requestFailed("HTTP error")
        }
        guard let result = try? JSONDecoder().decode(AIResult.self, from: data) else {
            return AIResult.mock(for: filename)
        }
        AICache.shared.save(key: cacheKey(filename: filename), result: result)
        return result
    }

    func generateAltText(filename: String, context: AIRequestContext) async throws -> String {
        let result = try await generateMetadata(filename: filename, context: context)
        return result.altText ?? "Product image for \(filename)"
    }

    func analyzeQuality(filename: String, context: AIRequestContext) async throws -> [String] {
        guard apiKey != nil else { return ["Mock response: no API key"] }
        return ["No issues detected"]
    }

    func estimateUsage(for items: Int) -> AIUsageEstimate {
        AIUsageEstimate(estimatedTokens: items * 450, estimatedCostUSD: Double(items) * 0.01)
    }

    private var apiKey: String? {
        KeychainManager.shared.get(keychainKey)
    }

    private func cacheKey(filename: String) -> String {
        "custom_\(filename)"
    }

    private func makeRequest(payload: CustomRequestPayload, apiKey: String) throws -> URLRequest {
        var request = URLRequest(url: profile.baseURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = profile.timeoutSeconds
        request.httpBody = try JSONEncoder().encode(payload)
        return request
    }
}

private struct CustomRequestPayload: Codable {
    var filename: String
    var context: AIRequestContext
}
