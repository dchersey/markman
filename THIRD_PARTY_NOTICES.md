# Third-party notices and GPLv3 compatibility

Reviewed for the initial source publication on 2026-09-22. Markman's original
code is GPL-3.0-only; the upstream LICENSE already in this repository is
preserved. Third-party copyright and license grants remain in force.

## Bundled runtime dependencies

| Component | Version | Upstream license | GPLv3 compatibility and obligations |
| --- | --- | --- | --- |
| [Marked](https://github.com/markedjs/marked/tree/v18.0.13) | 18.0.13 | MIT; upstream LICENSE also carries the original Markdown BSD-style three-clause notice | Compatible. Retain both copyright notices, permission terms, and disclaimers; do not use upstream names to endorse this project. |
| [DOMPurify](https://github.com/cure53/DOMPurify/tree/3.2.7) | 3.2.7 | Apache-2.0 OR MPL-2.0 | Markman uses the Apache-2.0 option, which is compatible with GPLv3. Retain the license and attribution. The bundled upstream code is unmodified. |

Marked copyright: © 2018+, MarkedJS; © 2011–2018 Christopher Jeffrey.
The additional Markdown notice credits © 2004 John Gruber.
DOMPurify copyright: © 2025 Dr.-Ing. Mario Heiderich, Cure53.

Full upstream license texts are preserved at:

- `Sources/Markman/Resources/marked-LICENSE`
- `Sources/Markman/Resources/DOMPurify-LICENSE`

The exact upstream release sources were inspected for separate NOTICE files;
none were present. Original license headers in the bundled JavaScript are
retained. Renaming the distributed JavaScript files does not alter their code.

## Basis for compatibility

The Free Software Foundation lists the [Expat/MIT license](https://www.gnu.org/licenses/license-list.html#Expat)
and [modified BSD license](https://www.gnu.org/licenses/license-list.html#ModifiedBSD)
as GPL-compatible. The Apache Software Foundation explicitly confirms that
[Apache-2.0 code can be included in GPLv3 projects](https://www.apache.org/licenses/GPL-compatibility).
This review selects DOMPurify's Apache option; it does not depend on the MPL
secondary-license mechanism.

## Platform and development tools

AppKit, Foundation, WebKit, and UniformTypeIdentifiers are provided by macOS;
Markman links to those system frameworks and does not redistribute their
implementations. The Swift compiler, Swift standard library supplied by the
platform, Xcode/Command Line Tools, and operating-system tools are not vendored.
The system-library and general-purpose-tool exclusions are described in
[GPLv3 section 1](https://www.gnu.org/licenses/gpl-3.0.html#section1).

There are no third-party Swift package dependencies. Upstream npm manifests
under `vendor/` describe development tools needed only to rebuild the two
JavaScript distributions. Their `node_modules` directories are not included in
Markman or in this source publication. This inventory covers redistributed
runtime code, not every package a developer may install locally.

## Source and binary distribution

The `vendor/` directories contain the matching editable TypeScript sources,
upstream licenses, package manifests, lockfiles, and build configuration for
both bundled libraries. See `vendor/README.md` for provenance and commands.

The app packaging script includes Markman's GPLv3 LICENSE, this notice, and
both third-party licenses in the application resources. When distributing a
compiled application, also provide the matching complete source and build
scripts under GPLv3 section 6—for example, a source archive beside the binary
for the exact same commit. An upstream link alone is not a replacement for
providing corresponding source. The GitHub release workflow publishes a matching source archive beside every
compiled application archive.
