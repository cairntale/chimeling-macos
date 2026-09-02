#!/bin/sh
set -eu
set -o pipefail

root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cd "$root"

if command -v xcbeautify >/dev/null 2>&1; then
	if [ "${GITHUB_ACTIONS:-}" = true ]; then
		beautify() {
			xcbeautify --renderer github-actions
		}
	else
		beautify() {
			xcbeautify
		}
	fi
else
	beautify() {
		cat
	}
fi

xcodebuild build \
	-project Chimeling.xcodeproj \
	-scheme Chimeling \
	-configuration Debug \
	-destination 'platform=macOS' \
	-clonedSourcePackagesDirPath SourcePackages \
	-skipPackagePluginValidation \
	CODE_SIGNING_ALLOWED=NO \
	| beautify
