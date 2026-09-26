# Markman

<img src="assets/Markman.png" width="128" alt="Markman: an ivory M wearing a blue baseball cap, beside a blue down arrow">

A small Markdown viewer for macOS, with a Linux prototype. Open a file from your terminal in a native window, with the entire window available for reading. No editor, print-width column, or account.

## Linux prototype (Arch / Omarchy)

Download **Markman-linux.tar.gz** from [Releases](https://github.com/dchersey/markman/releases/latest),
extract it, and run the included installer:

```sh
sudo pacman -S --needed gtk4 python-gobject webkitgtk-6.0
tar -xzf Markman-linux.tar.gz
cd Markman-linux
./scripts/install-linux.sh
~/.local/bin/markman examples/wide-table.md
```

The download includes the application and corresponding source. No compilation
is needed. The installer adds a launcher and “Open With” entry for your user.

The Linux frontend uses Python, GTK4 and WebKitGTK 6.0. It shares the Mac app's
bundled renderer, styles and sanitization; no JavaScript package installation is
needed. On Arch:

```sh
sudo pacman -S --needed gtk4 python-gobject webkitgtk-6.0
./bin/markman examples/wide-table.md
./bin/markman --theme dark tests/fixtures/rendering.md
./bin/markman --css /path/to/theme.css document.md
```

With no file, Markman shows a file picker. Multiple paths open separate windows.
The Linux command stays in the foreground; append `&` to keep using the terminal.
Relative images, heading links and links to other Markdown files work. Web and
email links open in the system's default application. Files reload after saves,
including atomic replacement and deletion/recreation, preserving scroll, zoom
and appearance. Missing or temporarily unreadable files keep their last preview.

Use **Ctrl+O** to open, **Ctrl+R** to reload, **Ctrl+W** to close,
**Ctrl++ / Ctrl+-** to zoom and **Ctrl+0** to reset. Arrow keys, Page Up/Down,
Space, Home and End scroll; **Alt+Up / Alt+Down** page, like Option+arrow on a
Mac. **Alt+Shift+L** or **Ctrl+Shift+C** copies the document's path. If an
executable named `markman-copy-path` is on `PATH`, Markman passes it the
absolute path and copies what it prints instead, so the path can be rewritten,
for example relative to a project. The window menu offers Copy path and
System / Light / Dark appearance. System follows the appearance WebKit receives
from the desktop; it does not import an Omarchy theme's custom palette.

Install the command, icon, application launcher and “Open With” entry for your user:

```sh
./scripts/install-linux.sh
```

The default prefix is `~/.local`; put `~/.local/bin` on your PATH to run `markman`
anywhere. Re-run the installer after changing the checkout. It does not change
the default application for Markdown files. `PREFIX` and `DESTDIR` are supported
for packaging. A local Arch package can be built from this checkout:

```sh
cd packaging/arch
makepkg
sudo pacman -U markman-*.pkg.tar.*
```

This PKGBUILD packages the current checkout and is a prototype recipe, not an
AUR source package. GTK4 uses the available Wayland display on Omarchy; no
Hyprland configuration is required.

For automated Linux checks:

```sh
sudo pacman -S --needed xorg-server-xvfb desktop-file-utils
./scripts/test-linux.sh
```

The test uses a temporary X display and the real WebKit engine to check light
and dark rendering at three widths, sanitization, local images, heading and
Markdown links, automatic reload, and scroll/zoom/theme retention. Linux CI runs
the same test. Native Wayland behavior and the desktop file picker also need
interactive testing on the target desktop.

## Install a macOS release

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

## Build the macOS app from source

Running Markman requires macOS 13+. Building requires Xcode 26 or newer
(including its Icon Composer compiler) and its Swift toolchain. Select that
Xcode installation with `xcode-select` before building.

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
- Open documents reload automatically about a second after a save, preserving scroll position, zoom, and theme. Atomic saves and deleting/recreating the file are supported; an unavailable file keeps its last readable preview.
- **⌘O** opens files, **⌘R** forces a reload, **⌘W** closes the window.
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

The first iteration is a reader: search, editing, syntax coloring, Mermaid, and math rendering are not implemented.

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
