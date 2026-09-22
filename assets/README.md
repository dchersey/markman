# App icon

`Markman.png` is the approved master artwork. `icon-composer.json` describes its
native Icon Composer layout: a slate background with the artwork slightly
expanded to fill the system's mask, with glass and translucency disabled for
the artwork layer. The design itself is unchanged.

`scripts/build-icon.sh` assembles `.build/Markman.icon` and uses Xcode 26+'s
asset compiler to produce `Assets.car` and a legacy `Markman.icns` fallback.
Both are bundled before signing. `CFBundleIconName` selects the native icon;
`CFBundleIconFile` supports earlier macOS versions.

A plain ICNS export was shown inside a pale compatibility frame on newer
macOS. Tests now inspect the system-rendered icon from a fresh bundle path,
including in the downloaded release, rather than only inspecting the artwork.

The artwork was created with built-in OpenAI image generation, then edited to
add the cap. The approved design is a broad ivory M on a dark slate rounded
square, a muted blue down arrow, and a matching baseball cap perched on the M's
upper-left corner. The cap has a left-facing visor. This project artwork is
provided under the same GPLv3 terms as Markman.
