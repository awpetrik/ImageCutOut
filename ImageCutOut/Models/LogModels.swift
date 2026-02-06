import Foundation

enum LogLevel: String, Codable, CaseIterable, Identifiable {
    case debug
    case info
    case warning
    case error

    var id: String { rawValue }
}

struct LogEntry: Identifiable, Codable, Hashable {
    var id: UUID
    var timestamp: Date
    var level: LogLevel
    var message: String
    var context: String?

    init(id: UUID = UUID(), timestamp: Date = Date(), level: LogLevel, message: String, context: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.message = message
        self.context = context
    }
}
