import Foundation

/// Collects open workspaces from ~/.claude/ide/*.lock for VS Code
/// (or VS Code-family IDEs) with a running Claude Code integration
struct VSCodeCollector: Collector {
    private struct LockFile: Decodable {
        let pid: Int32
        let workspaceFolders: [String]
        let ideName: String?
    }

    private var ideDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/ide")
    }

    func collect() -> [AgentSession] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: ideDir, includingPropertiesForKeys: nil
        ) else { return [] }

        var byFolder: [String: AgentSession] = [:]
        let decoder = JSONDecoder()

        for file in files where file.pathExtension == "lock" {
            guard let data = try? Data(contentsOf: file),
                  let lock = try? decoder.decode(LockFile.self, from: data),
                  isProcessAlive(lock.pid) else { continue }

            let mtime = fileModificationDate(file) ?? Date()
            for folder in lock.workspaceFolders where byFolder[folder] == nil {
                byFolder[folder] = AgentSession(
                    id: "vscode:\(folder)",
                    source: .vscode,
                    name: URL(fileURLWithPath: folder).lastPathComponent,
                    cwd: folder,
                    status: .idle,
                    lastActivity: mtime,
                    entrypoint: lock.ideName
                )
            }
        }
        return Array(byFolder.values)
    }
}
