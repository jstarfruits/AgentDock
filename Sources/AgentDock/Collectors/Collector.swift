import Foundation

/// Collects a list of AgentSession from local data sources
protocol Collector {
    func collect() -> [AgentSession]
}

/// Whether a process is alive (EPERM means "exists but no permission", so counts as alive)
func isProcessAlive(_ pid: Int32) -> Bool {
    guard pid > 0 else { return false }
    if kill(pid, 0) == 0 { return true }
    return errno == EPERM
}

enum JSONLFile {
    /// Extracts only complete lines from the last maxBytes of a file (handles huge transcripts)
    static func tailLines(of url: URL, maxBytes: Int = 65536) -> [String] {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return [] }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd() else { return [] }
        let offset = size > UInt64(maxBytes) ? size - UInt64(maxBytes) : 0
        guard (try? handle.seek(toOffset: offset)) != nil,
              let data = try? handle.readToEnd() else { return [] }
        var lines = data.split(separator: UInt8(ascii: "\n"))
            .compactMap { String(data: Data($0), encoding: .utf8) }
        // When reading from the middle, the first line may be truncated, so drop it
        if offset > 0, !lines.isEmpty {
            lines.removeFirst()
        }
        return lines
    }

    /// Returns the first line of a file (used for session metadata).
    /// Reads in chunks until a newline appears — Codex Desktop session_meta lines
    /// can exceed 32KB, and truncating one made the session silently disappear.
    static func firstLine(of url: URL, maxBytes: Int = 4 * 1024 * 1024) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var data = Data()
        while data.count < maxBytes {
            guard let chunk = try? handle.read(upToCount: 65536), !chunk.isEmpty else { break }
            if let newline = chunk.firstIndex(of: UInt8(ascii: "\n")) {
                data.append(chunk.prefix(upTo: newline))
                break
            }
            data.append(chunk)
        }
        return data.isEmpty ? nil : String(data: data, encoding: .utf8)
    }

    static func parse(_ line: String) -> [String: Any]? {
        guard let data = line.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}

func fileModificationDate(_ url: URL) -> Date? {
    (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
}
