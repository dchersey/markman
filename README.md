# Markman

A small macOS Markdown viewer. Open a file from your terminal in a native Swift/AppKit window, with the entire window available for reading. No editor, print-width column, or account.

## Install a release

The release workflow produces an Apple Silicon build for macOS 13 or newer,
signed with Developer ID and notarized by Apple. Download
`Markman-macos-arm64.zip` from [Releases](https://github.com/dchersey/markman/releases)
once a release has been published, unzip it, and move `Markman.app` to
`/Applications` (or `~/Applications`).

The archive also includes `bin/markman`. To install that launcher, run from the
unzipped folder:

```sh
mkdir -p "$HOME/.local/bin"
install -m 755 bin/markman "$HOME/.local/bin/markman"
export PATH="$HOME/.local/bin:$PATH"
markman /path/to/document.md
```

Add that PATH setting to your shell profile to keep it across terminal sessions.
The launcher finds the app in Applications, or beside its `bin` folder before
installation. Set `MARKMAN_APP=/path/to/Markman.app` to use another location.
Intel Macs can build from source with the instructions below.

## Build from source

Requires macOS 13+ and the Swift 6 toolchain (Xcode or Command Line Tools).

```sh
git clone https://github.com/dchersey/markman.git
cd markman
./scripts/build.sh
./bin/markman examples/wide-table.md
./bin/markman --theme light /path/to/document.md
./bin/markman --theme dark first.md second.md
```

The launcher builds on first use if needed, opens the app, and immediately returns your terminal prompt. Paths with spaces work when quoted. With no file, it shows a file picker. Add this checkout's `bin` directory to your PATH to run `markman` anywhere:

```sh
export PATH="$(pwd)/bin:$PATH"
```

Run that command from the checkout; add the resulting absolute path to your shell profile to keep it across terminal sessions.

The packaged app is `.build/Markman.app`. It can also be opened in Finder or copied to Applications. Re-run the build script after changing source files.

## Reading

- Content and tables use the available window width, with small edge padding.
- Table cells wrap long text and code. Alternating rows have subtle shading. Tables too wide for a small window scroll within the document instead of clipping columns.
- GitHub-style tables, task lists, fenced code, blockquotes, links, and images render offline. Remote images still need network access.
- Relative local images and links to other Markdown files work. Web links open in your browser.
- **⌘O** opens files, **⌘R** reloads after edits, **⌘W** closes the window.
- **⌘=** zooms in, **⌘-** zooms out, **⌘0** resets zoom.
- Choose **View → System / Light / Dark** to change appearance. The default follows macOS.

## Themes

Three built-in appearances need no configuration. For personal styling:

```sh
markman --theme light --css /path/to/theme.css document.md
```

Custom CSS is applied after the default styles. For example:

```css
:root { --stripe: #f3f5f8; --link: #3566a0; }
body { font-size: 17px; }
th, td { padding: 12px 16px; }
```

The stylesheet is `Sources/Markman/Resources/viewer.css`. Theme selection applies to the current launch; it is not saved between launches.

## Verification

```sh
./scripts/test.sh
```

This builds the app, checks command-line errors, and opens temporary native WebKit windows to verify table width, alternating rows, local images, and HTML sanitization at 1160, 720, and 420 pixels, in light and dark themes. The final screenshot is written to `/tmp/markman-smoke.png`.

You can run the same layout checks on a document containing a table with at least two body rows:

```sh
.build/Markman.app/Contents/MacOS/markman --smoke-test --theme light /path/to/document.md
```

## Scope and dependencies

The first iteration is a reader: reload is manual; search, editing, syntax coloring, Mermaid, and math rendering are not implemented.

Rendering uses bundled [Marked 18.0.13](https://github.com/markedjs/marked) and [DOMPurify 3.2.7](https://github.com/cure53/DOMPurify), with their licenses included beside the vendored code. Document HTML is sanitized and document scripts are blocked. There are no runtime CDN or package-manager requests. The app uses native AppKit and WebKit, not Electron.

## License

Markman is licensed under the [GNU General Public License, version 3](LICENSE)
(SPDX: `GPL-3.0-only`). It comes without warranty.

Third-party components retain their original licenses. Marked is MIT-licensed
and retains an additional BSD-style Markdown notice; DOMPurify is used under
its Apache-2.0 option. Both are compatible with GPLv3. See
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for the review, attribution,
and distribution details, and [vendor/README.md](vendor/README.md) for matching
upstream sources and rebuild instructions.

## Signed GitHub releases

See [docs/RELEASING.md](docs/RELEASING.md) for the signing secrets, release
commands, and verification procedure. `.github/workflows/ci.yml` builds and
tests changes to `main` and pull requests. `.github/workflows/release.yml`
builds, signs, notarizes, and publishes stable `vMAJOR.MINOR.PATCH` tags.
