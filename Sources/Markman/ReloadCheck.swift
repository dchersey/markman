// SPDX-License-Identifier: GPL-3.0-only
import AppKit

@MainActor
func checkAutomaticReload() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at:directory, withIntermediateDirectories:true)
    defer { try? FileManager.default.removeItem(at:directory) }
    let file = directory.appendingPathComponent("reload-check.md")
    let body = String(repeating:"\n\nA paragraph that keeps this document tall enough to test the reading position.", count:100)
    try ("# Before" + body).write(to:file, atomically:true, encoding:.utf8)
    let document = try DocumentWindow(file:file, options:Options())
    document.showWindow(nil)
    defer { document.close() }
    func waitForHeading(_ text: String) async throws {
        for _ in 0..<60 {
            if document.ready,
               let heading = try? await document.web.evaluateJavaScript("document.querySelector('h1')?.textContent"),
               heading as? String == text { return }
            try await Task.sleep(for:.milliseconds(100))
        }
        throw Failure("Automatic reload did not render heading: \(text)")
    }
    try await waitForHeading("Before")
    document.web.pageZoom = 1.2
    _ = try await document.web.evaluateJavaScript("document.documentElement.dataset.theme = 'dark'; window.scrollTo(0,500)")
    let initialY = try await document.web.evaluateJavaScript("window.scrollY") as? Double ?? 0
    try ("# After in-place save" + body).write(to:file, atomically:false, encoding:.utf8)
    try await waitForHeading("After in-place save")
    try ("# After atomic save" + body).write(to:file, atomically:true, encoding:.utf8)
    try await waitForHeading("After atomic save")
    let y = try await document.web.evaluateJavaScript("window.scrollY") as? Double ?? 0
    let theme = try await document.web.evaluateJavaScript("document.documentElement.dataset.theme") as? String
    guard initialY > 400, abs(y - initialY) < 2, theme == "dark", document.web.pageZoom == 1.2 else {
        throw Failure("Automatic reload changed reading state: scroll=\(y), theme=\(theme ?? "missing")")
    }
    document.close()
    guard document.watcher == nil else { throw Failure("Closed document retained its watcher") }
    print("Native automatic reload passed: in-place and atomic saves, scroll, zoom, theme, and close cleanup.")
}
