import Foundation

enum CSVError: Error {
    case invalidFormat
}

struct CSVParser {
    static func parse(_ text: String) throws -> [[String: String]] {
        let rows = parseRows(text)
        guard let header = rows.first else { return [] }
        let headers = header
        var results: [[String: String]] = []
        for row in rows.dropFirst() {
            var dict: [String: String] = [:]
            for (index, value) in row.enumerated() {
                if index < headers.count {
                    dict[headers[index].trimmingCharacters(in: .whitespacesAndNewlines)] = value.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            results.append(dict)
        }
        return results
    }

    private static func parseRows(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotes = false

        var iterator = text.makeIterator()
        while let char = iterator.next() {
            if char == "\"" {
                if inQuotes {
                    if let next = iterator.next() {
                        if next == "\"" {
                            currentField.append("\"")
                        } else if next == "," {
                            inQuotes = false
                            currentRow.append(currentField)
                            currentField = ""
                        } else if next == "\n" {
                            inQuotes = false
                            currentRow.append(currentField)
                            rows.append(currentRow)
                            currentRow = []
                            currentField = ""
                        } else {
                            currentField.append(next)
                        }
                    } else {
                        inQuotes = false
                        currentRow.append(currentField)
                        currentField = ""
                    }
                } else {
                    inQuotes = true
                }
                continue
            }

            if char == "," && !inQuotes {
                currentRow.append(currentField)
                currentField = ""
            } else if char == "\n" && !inQuotes {
                currentRow.append(currentField)
                rows.append(currentRow)
                currentRow = []
                currentField = ""
            } else {
                currentField.append(char)
            }
        }

        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append(currentRow)
        }

        return rows
    }
}

struct CSVExporter {
    static func export(rows: [CSVExportRow]) -> String {
        var lines: [String] = ["filename,sku,name,brand,category,tags,generated_at"]
        for row in rows {
            let values = [row.filename, row.sku, row.name, row.brand, row.category, row.tags, row.generatedAt]
            let escaped = values.map { value -> String in
                if value.contains(",") || value.contains("\"") {
                    let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
                    return "\"\(escaped)\""
                }
                return value
            }
            lines.append(escaped.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }
}
