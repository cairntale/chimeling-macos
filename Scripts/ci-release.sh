#!/bin/sh
set -eu
set -o pipefail

# Release signing. The Xcode project stays automatically signed for local builds.
# This script archives without signing, then signs only the app with the
# Developer ID imported below.
# BUILD_CERTIFICATE_BASE64, P12_PASSWORD, KEYCHAIN_PASSWORD
# Publishing also needs the App Store Connect API key and SPARKLE_PRIVATE_KEY.
# DRY_RUN=true signs and packages only.

root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cd "$root"

: "${BUILD_CERTIFICATE_BASE64:?}"
: "${P12_PASSWORD:?}"
: "${KEYCHAIN_PASSWORD:?}"

dry_run=false
if [ "${DRY_RUN:-}" = true ]; then
	dry_run=true
fi

if [ "$dry_run" = false ]; then
	: "${APP_STORE_CONNECT_API_KEY_ID:?}"
	: "${APP_STORE_CONNECT_API_ISSUER_ID:?}"
	: "${APP_STORE_CONNECT_API_KEY_P8:?}"
	: "${SPARKLE_PRIVATE_KEY:?}"
	: "${RELEASE_TAG:?}"
	case "$RELEASE_TAG" in
		v*) ;;
		*)
			echo "Refusing to publish $RELEASE_TAG. Push a v* tag." >&2
			exit 1
			;;
	esac
fi

identity="Developer ID Application: Cairntale LLC (2VW2ZL88HK)"
work="$(mktemp -d)"
keychain="$work/release.keychain-db"
p12="$work/developer-id.p12"
api_key="$work/AuthKey.p8"
sparkle_key="$work/sparkle.key"
archive="$work/Chimeling.xcarchive"
out="$root/build/release"

cleanup() {
	security delete-keychain "$keychain" >/dev/null 2>&1 || true
	rm -rf "$work"
}
trap cleanup EXIT

if command -v xcbeautify >/dev/null 2>&1; then
	if [ "${GITHUB_ACTIONS:-}" = true ]; then
		beautify() { xcbeautify --renderer github-actions; }
	else
		beautify() { xcbeautify; }
	fi
else
	beautify() { cat; }
fi

printf '%s\n' "$BUILD_CERTIFICATE_BASE64" | base64 -D >"$p12"
chmod 600 "$p12"

security create-keychain -p "$KEYCHAIN_PASSWORD" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$keychain"
security import "$p12" -k "$keychain" -P "$P12_PASSWORD" -T /usr/bin/codesign -T /usr/bin/security
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$keychain" >/dev/null
security list-keychains -d user -s "$keychain"
security default-keychain -s "$keychain"

if ! security find-identity -v -p codesigning "$keychain" | grep -F "$identity" >/dev/null; then
	echo "Imported keychain does not contain $identity" >&2
	security find-identity -v -p codesigning "$keychain" >&2 || true
	exit 1
fi

notarize() {
	file="$1"
	set +e
	result="$(xcrun notarytool submit "$file" \
		--key "$api_key" \
		--key-id "$APP_STORE_CONNECT_API_KEY_ID" \
		--issuer "$APP_STORE_CONNECT_API_ISSUER_ID" \
		--wait \
		--timeout 30m \
		--output-format json)"
	code=$?
	set -e
	printf '%s\n' "$result"
	submission="$(printf '%s' "$result" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("id",""))' 2>/dev/null || true)"
	status="$(printf '%s' "$result" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("status",""))' 2>/dev/null || true)"
	if [ "$code" -ne 0 ] || [ "$status" != "Accepted" ]; then
		if [ -n "$submission" ]; then
			xcrun notarytool log "$submission" \
				--key "$api_key" \
				--key-id "$APP_STORE_CONNECT_API_KEY_ID" \
				--issuer "$APP_STORE_CONNECT_API_ISSUER_ID" || true
		fi
		echo "Notarization of $file failed: ${status:-exit $code}" >&2
		exit 1
	fi
}

sign_sealed() {
	codesign --force --options runtime --timestamp --sign "$identity" "$1"
}

sign_app() {
	app="$1"
	find "$app" -depth -print >"$work/sign-list"
	while IFS= read -r path; do
		case "$path" in
			*.bundle)
				plist="$path/Contents/Info.plist"
				if [ -f "$plist" ] && /usr/libexec/PlistBuddy -c 'Print CFBundleExecutable' "$plist" >/dev/null 2>&1; then
					sign_sealed "$path"
				fi
				;;
			*.app|*.appex|*.framework|*.xpc|*.dylib)
				sign_sealed "$path"
				;;
			*)
				if [ -f "$path" ] && file -b "$path" | grep -q Mach-O; then
					sign_sealed "$path"
				fi
				;;
		esac
	done <"$work/sign-list"
}

if [ "$dry_run" = false ]; then
	printf '%s\n' "$APP_STORE_CONNECT_API_KEY_P8" >"$api_key"
	chmod 600 "$api_key"
	xcrun notarytool history \
		--key "$api_key" \
		--key-id "$APP_STORE_CONNECT_API_KEY_ID" \
		--issuer "$APP_STORE_CONNECT_API_ISSUER_ID" >/dev/null
fi

xcodebuild archive \
	-project Chimeling.xcodeproj \
	-scheme Chimeling \
	-configuration Release \
	-destination 'generic/platform=macOS' \
	-archivePath "$archive" \
	-clonedSourcePackagesDirPath "$work/SourcePackages" \
	-skipPackagePluginValidation \
	-skipMacroValidation \
	CODE_SIGNING_ALLOWED=NO \
	| beautify

app="$archive/Products/Applications/Chimeling.app"
xattr -cr "$app"
sign_app "$app"
codesign --verify --strict --verbose=2 "$app"
codesign -dv --verbose=4 "$app" 2>&1 | tee "$work/codesign.txt"
if ! grep -F "Authority=$identity" "$work/codesign.txt" >/dev/null; then
	echo "Archive is not signed by $identity" >&2
	exit 1
fi

version="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")"
build="$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$app/Contents/Info.plist")"
if [ "$dry_run" = false ]; then
	tag_version="${RELEASE_TAG#v}"
	if [ "$version" != "$tag_version" ]; then
		echo "Tag $RELEASE_TAG does not match CFBundleShortVersionString $version" >&2
		exit 1
	fi
fi

rm -rf "$out"
mkdir -p "$out"
zip="$out/Chimeling-$version.zip"
dmg="$out/Chimeling-$version.dmg"

ditto -c -k --sequesterRsrc --keepParent "$app" "$zip"

prepare_sparkle() {
	curl -fsSL -o "$work/sparkle.tar.xz" \
		https://github.com/sparkle-project/Sparkle/releases/download/2.10.1/Sparkle-2.10.1.tar.xz
	mkdir -p "$work/sparkle"
	tar -xJf "$work/sparkle.tar.xz" -C "$work/sparkle"
	generate_appcast="$(find "$work/sparkle" -name generate_appcast -type f -print -quit)"
	if [ -z "$generate_appcast" ]; then
		echo "generate_appcast was not in the Sparkle 2.10.1 archive" >&2
		exit 1
	fi
	printf '%s\n' "$SPARKLE_PRIVATE_KEY" >"$sparkle_key"
	chmod 600 "$sparkle_key"
}

sign_sparkle() {
	inbox="$1"
	appcast="$2"
	"$generate_appcast" \
		--ed-key-file "$sparkle_key" \
		--download-url-prefix "https://github.com/cairntale/chimeling-macos/releases/download/${RELEASE_TAG}/" \
		--maximum-deltas 0 \
		-o "$appcast" \
		"$inbox"
	if ! grep -F 'sparkle:edSignature="' "$appcast" >/dev/null; then
		echo "Appcast is missing sparkle:edSignature. The Sparkle private key does not match SUPublicEDKey." >&2
		exit 1
	fi
}

if [ "$dry_run" = false ]; then
	prepare_sparkle
	check_inbox="$work/sparkle-check"
	mkdir -p "$check_inbox"
	cp "$zip" "$check_inbox/"
	sign_sparkle "$check_inbox" "$work/appcast-check.xml"
	notarize "$zip"
	xcrun stapler staple "$app"
fi

stage="$work/dmg-src"
mkdir -p "$stage"
ditto "$app" "$stage/Chimeling.app"
git clone --depth 1 https://github.com/create-dmg/create-dmg.git "$work/create-dmg"
"$work/create-dmg/create-dmg" \
	--volname Chimeling \
	--window-pos 200 120 \
	--window-size 500 320 \
	--icon-size 80 \
	--icon "Chimeling.app" 125 175 \
	--hide-extension "Chimeling.app" \
	--app-drop-link 375 175 \
	--no-internet-enable \
	"$dmg" \
	"$stage"
codesign --timestamp --sign "$identity" "$dmg"

if [ "$dry_run" = false ]; then
	notarize "$dmg"
	xcrun stapler staple "$dmg"
	spctl -a -t exec -vv "$app"
	spctl -a -t open --context context:primary-signature -v "$dmg"

	publish_inbox="$work/sparkle-publish"
	mkdir -p "$publish_inbox"
	cp "$dmg" "$publish_inbox/"
	sign_sparkle "$publish_inbox" "$out/appcast.xml"

	if gh release view "$RELEASE_TAG" >/dev/null 2>&1; then
		gh release upload "$RELEASE_TAG" "$dmg" "$out/appcast.xml" --clobber
	else
		gh release create "$RELEASE_TAG" "$dmg" "$out/appcast.xml" \
			--title "$RELEASE_TAG"
	fi
fi

echo "Signed Chimeling $version ($build)"
if [ "$dry_run" = true ]; then
	echo "Dry run: skipped notarization and publishing."
fi
