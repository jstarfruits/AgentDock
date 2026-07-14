import Foundation

/// ローカルのデータソースから AgentSession の一覧を収集する
protocol Collector {
    func collect() -> [AgentSession]
}

/// プロセスが生存しているか(EPERM は「存在するが権限なし」なので生存扱い)
func isProcessAlive(_ pid: Int32) -> Bool {
    guard pid > 0 else { return false }
    if kill(pid, 0) == 0 { return true }
    return errno == EPERM
}

enum JSONLFile {
    /// ファイル末尾 maxBytes 分から完全な行だけを取り出す(巨大トランスクリプト対策)
    static func tailLines(of url: URL, maxBytes: Int = 65536) -> [String] {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return [] }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd() else { return [] }
        let offset = size > UInt64(maxBytes) ? size - UInt64(maxBytes) : 0
        guard (try? handle.seek(toOffset: offset)) != nil,
              let data = try? handle.readToEnd() else { return [] }
        var lines = data.split(separator: UInt8(ascii: "\n"))
            .compactMap { String(data: Data($0), encoding: .utf8) }
        // 途中から読んだ場合、先頭の行は欠けている可能性があるので捨てる
        if offset > 0, !lines.isEmpty {
            lines.removeFirst()
        }
        return lines
    }

    /// ファイル先頭の1行目を返す(セッションメタデータ用)
    static func firstLine(of url: URL, maxBytes: Int = 32768) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: maxBytes) else { return nil }
        guard let newline = data.firstIndex(of: UInt8(ascii: "\n")) else {
            return String(data: data, encoding: .utf8)
        }
        return String(data: data[data.startIndex..<newline], encoding: .utf8)
    }

    static func parse(_ line: String) -> [String: Any]? {
        guard let data = line.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}

func fileModificationDate(_ url: URL) -> Date? {
    (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
}
