// SPDX-License-Identifier: GPL-3.0-only
import Foundation

/// Watch the path rather than an open file descriptor, so atomic saves and
/// delete/recreate operations keep working. Reads happen off the UI thread.
@MainActor
final class DocumentWatcher {
    private var task: Task<Void, Never>?

    init(file: URL, initialText: String, onChange: @escaping @MainActor @Sendable (String) -> Void) {
        task = Task.detached(priority:.utility) {
            var published = initialText
            var candidate: String?
            while !Task.isCancelled {
                do { try await Task.sleep(for:.milliseconds(500)) }
                catch { return }
                // Keep the last good preview while the path is absent, unreadable,
                // or temporarily contains incomplete UTF-8 during a save.
                guard let text = try? String(contentsOf:file, encoding:.utf8) else {
                    candidate = nil
                    continue
                }
                guard !Task.isCancelled else { return }
                // Two matching reads debounce a burst of writes. Compare actual
                // content, including same-size edits and preserved timestamps.
                if text == candidate && text != published {
                    await MainActor.run {
                        guard !Task.isCancelled else { return }
                        onChange(text)
                    }
                    published = text
                }
                candidate = text
            }
        }
    }

    func stop() { task?.cancel(); task = nil }
    deinit { task?.cancel() }
}
