# Upstream source snapshots

These directories preserve the editable sources corresponding to Markman's
bundled JavaScript. Files are copied unchanged from the pinned upstream tags;
upstream examples, tests, documentation sites, and CI settings are omitted.
The source, license, lockfile, and configuration needed to rebuild each runtime
bundle are included. Markman's normal Swift build uses the already bundled JS
and does not run npm or download anything.

| Directory | Source release | Bundled runtime |
| --- | --- | --- |
| `marked-18.0.13` | [markedjs/marked v18.0.13](https://github.com/markedjs/marked/tree/v18.0.13) | `Sources/Markman/Resources/marked.js` (`lib/marked.umd.js` from npm) |
| `DOMPurify-3.2.7` | [cure53/DOMPurify 3.2.7](https://github.com/cure53/DOMPurify/tree/3.2.7) | `Sources/Markman/Resources/purify.js` (`dist/purify.min.js` from npm) |

`provenance.json` records download URLs and SHA-256 hashes. The source archive
hashes identify the inspected upstream downloads; the expanded subset is
committed here. Complete upstream licenses are also retained alongside the
runtime files. DOMPurify is incorporated under its Apache-2.0 licensing option.

## Rebuilding the JavaScript

Use Node.js 20 or newer and npm. These commands install upstream development
tools from the included lockfiles; network access is required for that step.
Run from the Markman repository root:

```sh
(cd vendor/marked-18.0.13 && npm ci --ignore-scripts && node esbuild.config.js)
(cd vendor/DOMPurify-3.2.7 && npm ci --ignore-scripts && npm run build)
cp vendor/marked-18.0.13/lib/marked.umd.js Sources/Markman/Resources/marked.js
cp vendor/DOMPurify-3.2.7/dist/purify.min.js Sources/Markman/Resources/purify.js
./scripts/test.sh
```

The build scripts can add timestamps/year metadata or produce different bytes
with different toolchain versions; the checked-in runtime hashes refer to the
original upstream distributions, not to a promise of byte-for-byte reproducible
builds. If changing a dependency, update its runtime, source snapshot, license,
version references, and provenance together. Keep upstream attribution and mark
any upstream source modifications as required by the dependency's license.
