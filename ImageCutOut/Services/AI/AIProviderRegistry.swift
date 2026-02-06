import Foundation

final class AIProviderRegistry {
    static let shared = AIProviderRegistry()
    private init() {}

    func provider(for profile: AIProviderProfile) -> AIProvider {
        switch profile.type {
        case .openAI:
            return OpenAIProvider(profile: profile)
        case .customREST:
            return CustomRESTProvider(profile: profile)
        default:
            return CustomRESTProvider(profile: profile)
        }
    }
}
