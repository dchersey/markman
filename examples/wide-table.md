# Room to read

Markman uses the **whole window**. Resize it: tables grow with the window, long text wraps, and every column remains accessible.

## Project inventory

| Component | Purpose | Reads → updates | Lifetime | Restored on startup? | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `document_index` (`Sources/Library/DocumentIndex.swift`) | Keep track of Markdown files in the current workspace, including documents with long names. | Reads file metadata → updates the document list and recent-file shortcuts. | Rebuilt when the workspace changes; individual entries refresh on demand. | Yes — saved locations are checked before reopening. | **Ready** — local files remain the source of truth. |
| `theme_preferences` | Follow system appearance or choose an explicit light or dark theme for the current session. | Reads the selected theme → updates background, text, borders, and table shading. | Current session; custom CSS can provide additional styling. | No — this example describes session preferences. | **Ready** — all table columns remain readable in both appearances. |
| `preview_cache` → `rendered_document_cache` | Avoid repeated work when returning to an unchanged document. | Reads the file modification time → rebuilds the preview after an edit. | Cleared when the document changes or the application closes. | No — generated content can be rebuilt from the original file. | **Planned** — this row is illustrative sample content. |
| `relative_image_loader` | Display nearby images without requiring an internet connection. | Resolves image paths relative to the Markdown file → loads image data. | Images belong to the source document and remain on disk. | Loaded again when a document opens. | **Ready** — images scale to fit the available width. |

## Ordinary Markdown, too

- [x] Full-width tables with subtle alternating rows
- [x] Light, dark, and system appearance
- [x] Local files and relative images
- [x] Reload with **⌘R**

> A viewer, with no editing controls in the way.

```swift
let message = "A code block keeps its formatting."
print(message)
```

[Jump to the inventory](#project-inventory)
