import Foundation

public final class DebugLog: Sendable {
    public static let shared = DebugLog()

    private let fileURL: URL

    private init() {
        let logsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs")
        fileURL = logsDir.appendingPathComponent("QuotaTimer.log")
    }

    public var logFileURL: URL { fileURL }

    public func log(_ message: String, source: String = "") {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let prefix = source.isEmpty ? "" : "[\(source)] "
        let line = "\(timestamp) \(prefix)\(message)\n"
        append(line)
    }

    public func logError(_ error: Error, source: String = "", context: String = "") {
        let detail = (error as CustomStringConvertible).description
        let ctx = context.isEmpty ? "" : " (\(context))"
        log("ERROR\(ctx): \(detail)", source: source)
    }

    private func append(_ line: String) {
        guard let data = line.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: fileURL.path) {
            guard let handle = try? FileHandle(forWritingTo: fileURL) else { return }
            handle.seekToEndOfFile()
            handle.write(data)
            handle.closeFile()
            trimIfNeeded()
        } else {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private func trimIfNeeded() {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attrs[.size] as? UInt64,
              size > 512 * 1024 else { return }
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return }
        let lines = content.components(separatedBy: "\n")
        let keep = lines.suffix(500).joined(separator: "\n")
        try? keep.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
