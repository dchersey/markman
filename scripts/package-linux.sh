#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/release-assets
# Python and renderer assets require no compilation. Include the matching
# editable sources and licenses in the downloadable installation archive.
git archive --format=tar.gz --prefix=Markman-linux/ \
  -o .build/release-assets/Markman-linux.tar.gz HEAD
./scripts/validate-linux-release.sh .build/release-assets/Markman-linux.tar.gz
