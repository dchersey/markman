// SPDX-License-Identifier: GPL-3.0-only
import Foundation

@main
struct WatcherTests {
    @MainActor static func main() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:directory, withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:directory) }
        let file = directory.appendingPathComponent("document.md")
        try "first".write(to:file, atomically:false, encoding:.utf8)
        var changes: [String] = []
        let watcher = DocumentWatcher(file:file, initialText:"first") { changes.append($0) }
        func waitFor(_ expected: String) async throws {
            for _ in 0..<40 {
                if changes.last == expected { return }
                try await Task.sleep(for:.milliseconds(100))
            }
            fatalError("Did not reload \(expected); received \(changes)")
        }
        try "other".write(to:file, atomically:false, encoding:.utf8)
        try await waitFor("other")
        try "atomic replacement".write(to:file, atomically:true, encoding:.utf8)
        try await waitFor("atomic replacement")
        try FileManager.default.removeItem(at:file)
        try await Task.sleep(for:.milliseconds(1200))
        precondition(changes.last == "atomic replacement")
        try Data([0xff,0xfe,0xff]).write(to:file)
        try await Task.sleep(for:.milliseconds(1200))
        precondition(changes.last == "atomic replacement")
        try "recreated".write(to:file, atomically:true, encoding:.utf8)
        try await waitFor("recreated")
        let count = changes.count
        try "recreated".write(to:file, atomically:true, encoding:.utf8)
        try await Task.sleep(for:.milliseconds(1200))
        precondition(changes.count == count, "Unchanged content caused a reload")
        watcher.stop()
        try "closed".write(to:file, atomically:true, encoding:.utf8)
        try await Task.sleep(for:.milliseconds(1200))
        precondition(changes.count == count, "Watcher fired after stop")
        print("Watcher checks passed: in-place, atomic save, missing/invalid file recovery, unchanged content, and stop.")
    }
}
