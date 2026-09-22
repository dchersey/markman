Markman now runs on Linux as well as macOS. The Linux prototype uses GTK4 and
WebKitGTK with the same Markdown renderer, full-width tables, themes, and
sanitization as the Mac app. Both versions automatically reload documents after
saves while preserving scroll position, zoom, and appearance.

## Linux — Arch / Omarchy

Download **Markman-linux.tar.gz** below, then run from your download directory:

```sh
sudo pacman -S --needed gtk4 python-gobject webkitgtk-6.0
tar -xzf Markman-linux.tar.gz
cd Markman-linux
./scripts/install-linux.sh
~/.local/bin/markman examples/wide-table.md
```

The installer adds Markman to your application launcher and “Open With” menu.
Add `~/.local/bin` to your PATH to use `markman file.md` from any directory.
Run `markman` with no file for the file picker. Use Ctrl+O to open, Ctrl+R to
reload, Ctrl+W to close, and Ctrl++ / Ctrl+- / Ctrl+0 for zoom. The window menu
offers System, Light, and Dark appearance. The command stays in the foreground;
append `&` to keep using the terminal.

This archive contains Python and web assets, so no compilation is required.
It uses your distribution's GTK4/WebKitGTK packages and includes all corresponding
source and licenses. A local Arch PKGBUILD is included under `packaging/arch`.
The Linux version is an initial prototype; rendering and reload are tested
automatically, and native Wayland launch has been verified on Omarchy.

## macOS — Apple Silicon

Download **Markman-macos-arm64.zip** below, unzip it, and move `Markman.app` to
`/Applications` or `~/Applications`. Requires macOS 13 or newer. The app is
Developer ID signed and Apple notarized. The archive includes the optional
`bin/markman` terminal launcher.

## Verification and source

`SHA256SUMS` contains the checksums for all three archives.
`markman-VERSION-source.tar.gz` contains the matching source for both frontends,
including vendored dependency sources and build scripts.
