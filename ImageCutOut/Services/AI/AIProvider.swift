import Foundation

protocol AIProvider {
    var id: UUID { get }
    var profile: AIProviderProfile { get }
    var capabilities: AIProviderCapabilities { get }
    func testConnection() async -> Bool
    func generateMetadata(filename: String, context: AIRequestContext) async throws -> AIResult
    func generateAltText(filename: String, context: AIRequestContext) async throws -> String
    func analyzeQuality(filename: String, context: AIRequestContext) async throws -> [String]
    func estimateUsage(for items: Int) -> AIUsageEstimate
}

enum AIProviderError: Error {
    case missingAPIKey
    case invalidResponse
    case requestFailed(String)
}
