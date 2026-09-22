// SPDX-License-Identifier: GPL-3.0-only
import AppKit
import WebKit
import UniformTypeIdentifiers

struct Options {
    var files: [URL] = []
    var theme = "system"
    var css: String = ""
    var smokeTest = false
    var validateOnly = false
    var reloadTest = false
    static func parse() throws -> Options {
        var result = Options()
        var args = Array(CommandLine.arguments.dropFirst())
        var positional = false
        while !args.isEmpty {
            let arg = args.removeFirst()
            if !positional && arg == "--" { positional = true; continue }
            if !positional && ["--help", "-h"].contains(arg) {
                print("""
                Usage: markman [--theme system|light|dark] [--css path] [file.md ...]
                Opens Markdown in a native, full-width macOS viewer.
                No file: show the file picker. Use -- before paths beginning with -.
                Shortcuts: ⌘O open · ⌘R reload · ⌘+/⌘- zoom · ⌘0 reset · ⌘W close
                """)
                exit(0)
            }
            if !positional && arg == "--reload-test" { result.reloadTest = true; continue }
            if !positional && arg == "--validate-only" { result.validateOnly = true; continue }
            if !positional && arg == "--smoke-test" { result.smokeTest = true; continue }
            if !positional && ["--theme", "--css"].contains(arg) {
                guard !args.isEmpty else { throw Failure("Missing value for \(arg)") }
                let value = args.removeFirst()
                if arg == "--theme" {
                    guard ["light", "dark", "system"].contains(value) else { throw Failure("Unknown theme: \(value)") }
                    result.theme = value
                } else { result.css = try String(contentsOfFile: NSString(string:value).expandingTildeInPath, encoding:.utf8) }
            } else {
                guard positional || !arg.hasPrefix("-") else { throw Failure("Unknown option: \(arg)") }
                let url = URL(fileURLWithPath: NSString(string:arg).expandingTildeInPath).standardizedFileURL
                _ = try String(contentsOf:url, encoding:.utf8)
                result.files.append(url)
            }
        }
        return result
    }
}
struct Failure: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
func resource(_ name: String) -> String {
    let packaged = Bundle.main.resourceURL!.appendingPathComponent("Resources/\(name)")
    let url = FileManager.default.fileExists(atPath:packaged.path) ? packaged : Bundle.module.resourceURL!.appendingPathComponent("Resources/\(name)")
    return try! String(contentsOf:url, encoding:.utf8)
}

// Serve local images through WebKit's supported scheme API, without granting
// a generated HTML page blanket filesystem read access.
final class LocalImageHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url else { return }
        let file = URL(fileURLWithPath:url.path)
        guard let type = UTType(filenameExtension:file.pathExtension), type.conforms(to:.image) else {
            task.didFailWithError(Failure("Only images may be embedded from local files")); return
        }
        do {
            let data = try Data(contentsOf:file)
            task.didReceive(URLResponse(url:url, mimeType:type.preferredMIMEType ?? "application/octet-stream", expectedContentLength:data.count, textEncodingName:nil))
            task.didReceive(data)
            task.didFinish()
        } catch { task.didFailWithError(error) }
    }
    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}

@MainActor
final class DocumentWindow: NSWindowController, WKNavigationDelegate, NSWindowDelegate {
    let web: WKWebView
    let file: URL
    let options: Options
    var markdown: String
    var ready = false
    var smokeStep = 0
    var watcher: DocumentWatcher?
    init(file: URL, options: Options) throws {
        self.file = file
        self.options = options
        markdown = try String(contentsOf:file, encoding:.utf8)
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(LocalImageHandler(), forURLScheme:"markman-local")
        // Only our bundled scripts execute; Markdown HTML is sanitized before insertion.
        for name in ["marked.js", "purify.js", "viewer.js"] {
            config.userContentController.addUserScript(WKUserScript(source:resource(name), injectionTime:.atDocumentEnd, forMainFrameOnly:true))
        }
        web = WKWebView(frame:.zero, configuration:config)
        let window = NSWindow(contentRect:NSRect(x:0,y:0,width:1160,height:800), styleMask:[.titled,.closable,.miniaturizable,.resizable], backing:.buffered, defer:false)
        window.minSize = NSSize(width:360,height:280)
        window.title = file.lastPathComponent
        window.representedURL = file
        window.contentView = web
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window:window)
        window.delegate = self
        watcher = DocumentWatcher(file:file, initialText:markdown) { [weak self] text in
            guard let self, self.markdown != text else { return }
            self.markdown = text
            if self.ready { self.render() }
        }
        web.navigationDelegate = self
        web.allowsBackForwardNavigationGestures = false
        web.allowsMagnification = true
        let css = (resource("viewer.css") + "\n" + options.css).replacingOccurrences(of:"</style", with:"<\\/style", options:.caseInsensitive)
        let html = """
        <!doctype html><html data-theme="\(options.theme)"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src markman-local: data: https: http:; style-src 'unsafe-inline'; script-src 'none'; base-uri 'none'; form-action 'none'">
        <style>\(css)</style></head><body><main id="content"></main></body></html>
        """
        var base = URLComponents(url:file.deletingLastPathComponent().appendingPathComponent("", isDirectory:true), resolvingAgainstBaseURL:false)!
        base.scheme = "markman-local"
        base.host = "document"
        web.loadHTMLString(html, baseURL:base.url)
    }
    required init?(coder:NSCoder) { fatalError() }
    func windowWillClose(_ notification: Notification) {
        watcher?.stop()
        watcher = nil
        (NSApp.delegate as? AppDelegate)?.documents.removeAll { $0 === self }
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !ready else { return }
        ready = true
        render()
    }
    func render() {
        web.callAsyncJavaScript("window.renderMarkdown(markdown)", arguments:["markdown":markdown], in:nil, in:.page) { [weak self] result in
            guard let self else { return }
            if case .failure(let error) = result { self.show(error); if self.options.smokeTest { exit(1) } }
            else if self.options.smokeTest {
                Task { @MainActor in
                    try? await Task.sleep(for:.milliseconds(500))
                    self.checkRendering()
                }
            }
        }
    }
    func reload() {
        do { markdown = try String(contentsOf:file, encoding:.utf8); if ready { render() } }
        catch { show(error) }
    }
    func show(_ error: Error) { NSAlert(error:error).runModal() }
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        guard action.navigationType == .linkActivated, let url = action.request.url else {
            decisionHandler(action.navigationType == .other && !ready ? .allow : .cancel); return
        }
        if url.fragment != nil && url.path == (web.url?.path ?? file.deletingLastPathComponent().path) {
            web.callAsyncJavaScript("document.getElementById(id)?.scrollIntoView()", arguments:["id":url.fragment!.removingPercentEncoding ?? url.fragment!], in:nil, in:.page)
        } else if (url.isFileURL || url.scheme == "markman-local") && ["md","markdown","mdown"].contains(url.pathExtension.lowercased()) {
            (NSApp.delegate as? AppDelegate)?.open(URL(fileURLWithPath:url.path))
        } else if ["https", "http", "mailto"].contains(url.scheme?.lowercased() ?? "") { NSWorkspace.shared.open(url) }
        decisionHandler(.cancel)
    }
    func checkRendering() {
        web.evaluateJavaScript("""
        (() => {
          const main = document.querySelector('main'), table = document.querySelector('table');
          const rows = document.querySelectorAll('tbody tr');
          return {pageWidth:document.documentElement.scrollWidth, width:innerWidth, content:main.getBoundingClientRect().width,
            table:table?.getBoundingClientRect().width ?? 0, rows:rows.length,
            striped:rows.length > 1 && getComputedStyle(rows[1]).backgroundColor !== getComputedStyle(rows[0]).backgroundColor,
            safe:!window.markmanInjected && !document.querySelector('#content script, #content iframe, #content [onerror], #content a[href^="javascript:"]'),
            image:document.querySelector('img')?.naturalWidth ?? 0, base:document.baseURI, src:document.querySelector('img')?.src ?? ""};
        })()
        """) { [weak self] result, error in
            guard let self, let values = result as? [String:Any], error == nil,
                  let width = values["width"] as? Double, let content = values["content"] as? Double,
                  let table = values["table"] as? Double,
                  content > width * 0.80, table >= content - 1,
                  (values["pageWidth"] as? Double ?? .infinity) <= width + 1,
                  values["striped"] as? Bool == true, values["safe"] as? Bool == true,
                  (!self.markdown.contains("pixel.svg") || (values["image"] as? Int ?? 0) > 0) else {
                print("Rendering check FAILED: \(String(describing:result)) \(String(describing:error))"); exit(1)
            }
            print("Rendering check passed: \(values)")
            if self.smokeStep < 2 {
                self.smokeStep += 1
                self.window?.setContentSize(NSSize(width:self.smokeStep == 1 ? 720 : 420, height:800))
                Task { @MainActor in
                    try? await Task.sleep(for:.milliseconds(200))
                    self.checkRendering()
                }
                return
            }
            self.window?.setContentSize(NSSize(width:1160,height:800))
            self.web.evaluateJavaScript("document.querySelector('table')?.scrollIntoView()")
            self.web.takeSnapshot(with:nil) { image, error in
                if let data = image?.tiffRepresentation, let bitmap = NSBitmapImageRep(data:data), let png = bitmap.representation(using:.png, properties:[:]) {
                    try? png.write(to:URL(fileURLWithPath:"/tmp/markman-smoke.png"))
                }
                exit(error == nil ? 0 : 1)
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let options: Options
    var documents: [DocumentWindow] = []
    var launched = false
    var pendingFiles: [URL] = []
    init(options: Options) { self.options = options }
    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        if options.reloadTest {
            Task { @MainActor in
                do { try await checkAutomaticReload(); exit(0) }
                catch { print("Automatic reload check failed: \(error)"); exit(1) }
            }
            return
        }
        let files = options.files.isEmpty ? pendingFiles : options.files
        launched = true
        if files.isEmpty { chooseFile() } else { files.forEach(open) }
        NSApp.activate(ignoringOtherApps:true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        // AppKit also sends positional CLI arguments as an initial open-files event.
        // Our parser already owns those arguments, including option values.
        if !launched {
            if CommandLine.arguments.count == 1 { pendingFiles = filenames.map { URL(fileURLWithPath:$0) } }
        } else {
            filenames.forEach { open(URL(fileURLWithPath:$0)) }
        }
        sender.reply(toOpenOrPrint:.success)
    }
    func open(_ url: URL) {
        do {
            let document = try DocumentWindow(file:url, options:options)
            documents.append(document)
            document.showWindow(nil)
        } catch { NSAlert(error:error).runModal() }
    }
    @objc func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, UTType(filenameExtension:"md") ?? .plainText]
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK { panel.urls.forEach(open) }
        else if documents.isEmpty { NSApp.terminate(nil) }
    }
    var current: DocumentWindow? { documents.first { $0.window == NSApp.keyWindow } }
    @objc func reload() { current?.reload() }
    @objc func zoomIn() { if let web = current?.web { web.pageZoom = min(3,web.pageZoom + 0.1) } }
    @objc func zoomOut() { if let web = current?.web { web.pageZoom = max(0.5,web.pageZoom - 0.1) } }
    @objc func zoomReset() { current?.web.pageZoom = 1 }
    @objc func theme(_ item: NSMenuItem) {
        guard let theme = item.representedObject as? String else { return }
        for doc in documents { doc.web.callAsyncJavaScript("document.documentElement.dataset.theme = theme", arguments:["theme":theme], in:nil, in:.page) }
    }
    func buildMenu() {
        let bar = NSMenu()
        func menu(_ title: String) -> NSMenu {
            let item = NSMenuItem(); let sub = NSMenu(title:title); item.submenu = sub; bar.addItem(item); return sub
        }
        func add(_ menu:NSMenu, _ title:String, _ action:Selector, _ key:String, target:AnyObject? = nil) {
            let item = menu.addItem(withTitle:title, action:action, keyEquivalent:key); item.target = target
        }
        let app = menu("Markman")
        add(app,"Quit Markman",#selector(NSApplication.terminate(_:)),"q")
        let file = menu("File")
        add(file,"Open…",#selector(chooseFile),"o",target:self)
        add(file,"Reload",#selector(reload),"r",target:self)
        add(file,"Close",#selector(NSWindow.performClose(_:)),"w")
        let edit = menu("Edit")
        add(edit,"Copy",#selector(NSText.copy(_:)),"c")
        add(edit,"Select All",#selector(NSText.selectAll(_:)),"a")
        let view = menu("View")
        add(view,"Zoom In",#selector(zoomIn),"=",target:self)
        add(view,"Zoom Out",#selector(zoomOut),"-",target:self)
        add(view,"Actual Size",#selector(zoomReset),"0",target:self)
        view.addItem(.separator())
        for name in ["system","light","dark"] {
            let item = view.addItem(withTitle:name.capitalized, action:#selector(theme(_:)), keyEquivalent:"")
            item.representedObject = name; item.target = self
        }
        NSApp.mainMenu = bar
    }
}

do {
    let options = try Options.parse()
    if options.validateOnly { exit(0) }
    let application = NSApplication.shared
    application.setActivationPolicy(.regular)
    let delegate = AppDelegate(options:options)
    application.delegate = delegate
    application.run()
} catch {
    FileHandle.standardError.write(Data("markman: \(error.localizedDescription)\n".utf8))
    exit(1)
}
