# App icon

`Markman.png` is the approved master artwork. `scripts/build-icon.sh` uses macOS
`sips` and `iconutil` to produce the standard and Retina representations in
`.build/Markman.icns`. The app build installs that file before code signing and
registers it with `CFBundleIconFile` for Finder, the Dock, and application launchers.

The artwork was created with built-in OpenAI image generation, then edited to
add the cap. The approved design is a broad ivory M on a dark slate rounded
square, a muted blue down arrow, and a matching baseball cap perched on the M's
upper-left corner. The cap has a left-facing visor; the lettering and tile
remain unchanged from the original concept. This project artwork is provided
under the same GPLv3 terms as Markman.
