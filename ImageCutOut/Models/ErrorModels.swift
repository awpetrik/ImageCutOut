import Foundation

enum ErrorCategory: String, Codable, CaseIterable {
    case input
    case processing
    case ai
    case export
}

struct CategorizedError: Error {
    let category: ErrorCategory
    let message: String
}
