#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output=$(mktemp -d "${TMPDIR:-/tmp}/mdopener-pdf-check.XXXXXX")
swiftc -parse-as-library \
  "$root/ios/MDOpener/Model/Models.swift" \
  "$root/ios/MDOpener/Model/AppModel.swift" \
  "$root/ios/MDOpener/Core/DocumentLoader.swift" \
  "$root/ios/MDOpener/Core/ImageSchemeHandler.swift" \
  "$root/ios/MDOpener/Core/PdfExporter.swift" \
  "$root/test/PdfExportCheck.swift" -o "$output/check"
"$output/check" "$root" "$output"
printf 'Review PDFs: %s\n' "$output"
