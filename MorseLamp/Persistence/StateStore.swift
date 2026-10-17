import Foundation
import Synchronization

nonisolated protocol StateStore: Sendable {
    /// Nil when nothing has been saved yet.
    func load() throws -> AppState?
    func save(_ state: AppState) throws
}

/// One JSON file in Application Support, written atomically.
nonisolated struct FileStateStore: StateStore {
    let url: URL

    init(url: URL) {
        self.url = url
    }

    static func defaultURL() -> URL {
        URL.applicationSupportDirectory
            .appending(path: "MorseLamp", directoryHint: .isDirectory)
            .appending(path: "state.json")
    }

    func load() throws -> AppState? {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(AppState.self, from: data)
    }

    func save(_ state: AppState) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(state).write(to: url, options: [.atomic, .completeFileProtection])
    }
}

/// For tests and previews: remembers every save.
nonisolated final class MemoryStateStore: StateStore {
    private let storage = Mutex<[AppState]>([])

    init() {}

    var saved: [AppState] { storage.withLock { $0 } }

    func load() throws -> AppState? {
        storage.withLock { $0.last }
    }

    func save(_ state: AppState) throws {
        storage.withLock { $0.append(state) }
    }
}
