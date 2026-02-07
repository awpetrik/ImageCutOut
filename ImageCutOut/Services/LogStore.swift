import Foundation
import Combine

final class LogStore: ObservableObject, @unchecked Sendable {
    @Published private(set) var entries: [LogEntry] = []

    private let queue = DispatchQueue(label: "ImageCutOut.LogStore", qos: .utility)
    private let fileManager = FileManager.default
    private let maxFileSize: Int64 = 10 * 1024 * 1024
    private let maxFiles = 5
    private let logDirectory: URL
    private var currentLogURL: URL

    init() {
        let base = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.logDirectory = base.appendingPathComponent("Logs/ImageCutOut", isDirectory: true)
        if !fileManager.fileExists(atPath: logDirectory.path) {
            try? fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        }
        self.currentLogURL = logDirectory.appendingPathComponent("log-0.txt")
    }

    func log(_ level: LogLevel, _ message: String, context: String? = nil) {
        let entry = LogEntry(level: level, message: message, context: context)
        queue.async { [weak self] in
            guard let self = self else { return }
            self.write(entry)
        }
        DispatchQueue.main.async {
            self.entries.append(entry)
            if self.entries.count > 2000 {
                self.entries.removeFirst(self.entries.count - 2000)
            }
        }
    }

    func exportLogs(to url: URL) throws {
        let logs = try fileManager.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: nil)
        let exportURL = url.appendingPathComponent("ImageCutOut-Logs")
        if fileManager.fileExists(atPath: exportURL.path) {
            try fileManager.removeItem(at: exportURL)
        }
        try fileManager.createDirectory(at: exportURL, withIntermediateDirectories: true)
        for log in logs {
            let dest = exportURL.appendingPathComponent(log.lastPathComponent)
            try fileManager.copyItem(at: log, to: dest)
        }
    }

    private func write(_ entry: LogEntry) {
        rotateIfNeeded()
        let line = "\(entry.timestamp.iso8601) [\(entry.level.rawValue.uppercased())] \(entry.message)\(entry.context.map { " (\($0))" } ?? "")\n"
        if !fileManager.fileExists(atPath: currentLogURL.path) {
            fileManager.createFile(atPath: currentLogURL.path, contents: nil)
        }
            if let data = line.data(using: .utf8) {
            if let handle = try? FileHandle(forWritingTo: currentLogURL) {
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
                try? handle.close()
            }
        }
    }

    private func rotateIfNeeded() {
        guard let attrs = try? fileManager.attributesOfItem(atPath: currentLogURL.path),
              let size = attrs[.size] as? NSNumber,
              size.int64Value >= maxFileSize else { return }

        for index in stride(from: maxFiles - 1, through: 1, by: -1) {
            let src = logDirectory.appendingPathComponent("log-\(index - 1).txt")
            let dst = logDirectory.appendingPathComponent("log-\(index).txt")
            if fileManager.fileExists(atPath: dst.path) {
                try? fileManager.removeItem(at: dst)
            }
            if fileManager.fileExists(atPath: src.path) {
                try? fileManager.moveItem(at: src, to: dst)
            }
        }

        currentLogURL = logDirectory.appendingPathComponent("log-0.txt")
        fileManager.createFile(atPath: currentLogURL.path, contents: nil)
    }
}

private extension Date {
    var iso8601: String {
        ISO8601DateFormatter().string(from: self)
    }
}
