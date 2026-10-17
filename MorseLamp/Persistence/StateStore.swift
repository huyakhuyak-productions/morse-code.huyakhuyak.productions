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

    /// Nil when nothing is saved. A file that cannot be decoded is renamed
    /// `state.unreadable-<timestamp>.json` before the error is thrown, so the next save
    /// never overwrites it.
    func load() throws -> AppState? {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return nil }
        let data = try Data(contentsOf: url)
        do {
            return try JSONDecoder().decode(AppState.self, from: data)
        } catch {
            setAside()
            throw error
        }
    }

    private func setAside() {
        let stamp = Int(Date.now.timeIntervalSince1970)
        let base = url.deletingPathExtension().lastPathComponent
        let aside = url.deletingLastPathComponent().appending(path: "\(base).unreadable-\(stamp).json")
        try? FileManager.default.moveItem(at: url, to: aside)
    }

    func save(_ state: AppState) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(state).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
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
