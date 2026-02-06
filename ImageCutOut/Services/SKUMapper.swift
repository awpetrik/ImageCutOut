import Foundation

struct SKUMapper {
    static func match(for filename: String, mapping: [SKUMapEntry]) -> SKUMapEntry? {
        for entry in mapping {
            if matches(filename: filename, pattern: entry.filenamePattern) {
                return entry
            }
        }
        return nil
    }

    private static func matches(filename: String, pattern: String) -> Bool {
        if pattern.contains("*") {
            let regex = NSRegularExpression.escapedPattern(for: pattern).replacingOccurrences(of: "\\*", with: ".*")
            return filename.range(of: "^\(regex)$", options: .regularExpression) != nil
        }
        if pattern.hasPrefix("/") && pattern.hasSuffix("/") {
            let trimmed = String(pattern.dropFirst().dropLast())
            return filename.range(of: trimmed, options: .regularExpression) != nil
        }
        return filename.localizedCaseInsensitiveContains(pattern)
    }
}
