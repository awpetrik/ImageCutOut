import Foundation

enum AIProviderType: String, Codable, CaseIterable, Identifiable {
    case openAI
    case customREST
    case anthropic
    case googleGemini
    case azureOpenAI
    case ollama

    var id: String { rawValue }
}

struct AIProviderCapabilities: Codable, Hashable {
    var supportsVision: Bool
    var supportsOCR: Bool
    var supportsLLM: Bool
    var supportsMultimodal: Bool
}

struct AIProviderProfile: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var type: AIProviderType
    var baseURL: URL
    var modelName: String
    var timeoutSeconds: Double
    var rateLimitPerMinute: Int
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        type: AIProviderType,
        baseURL: URL,
        modelName: String,
        timeoutSeconds: Double = 30,
        rateLimitPerMinute: Int = 30,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.baseURL = baseURL
        self.modelName = modelName
        self.timeoutSeconds = timeoutSeconds
        self.rateLimitPerMinute = rateLimitPerMinute
        self.isEnabled = isEnabled
    }
}

struct AIRequestContext: Codable, Hashable {
    var filename: String
    var metadataHints: [String: String]
    var locale: String
}

struct AIResult: Codable, Hashable {
    var metadata: AssetMetadata
    var altText: String?
    var tags: [String]
    var qualityNotes: [String]
    var createdAt: Date

    static func mock(for filename: String) -> AIResult {
        AIResult(
            metadata: AssetMetadata(productName: filename.replacingOccurrences(of: "_", with: " ").capitalized),
            altText: "Product image for \(filename)",
            tags: ["product", "catalog"],
            qualityNotes: ["Mock response used (no API key)."],
            createdAt: Date()
        )
    }
}

struct AIUsageEstimate: Codable, Hashable {
    var estimatedTokens: Int
    var estimatedCostUSD: Double
}
