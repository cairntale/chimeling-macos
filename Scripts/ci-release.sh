#!/bin/sh
set -eu
set -o pipefail

# Release signing and notarization. Credentials come from the environment.
# BUILD_CERTIFICATE_BASE64  Developer ID Application .p12, base64
# P12_PASSWORD
# KEYCHAIN_PASSWORD         throwaway keychain only
# APP_STORE_CONNECT_API_KEY_ID
# APP_STORE_CONNECT_API_ISSUER_ID
# APP_STORE_CONNECT_API_KEY_P8
# SPARKLE_PRIVATE_KEY       generate_keys -x output
# RELEASE_TAG               v0.1.0

root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cd "$root"

: "${BUILD_CERTIFICATE_BASE64:?}"
: "${P12_PASSWORD:?}"
: "${KEYCHAIN_PASSWORD:?}"
: "${APP_STORE_CONNECT_API_KEY_ID:?}"
: "${APP_STORE_CONNECT_API_ISSUER_ID:?}"
: "${APP_STORE_CONNECT_API_KEY_P8:?}"
: "${SPARKLE_PRIVATE_KEY:?}"
: "${RELEASE_TAG:?}"

work="$(mktemp -d)"
keychain="$work/release.keychain-db"
p12="$work/developer-id.p12"
api_key="$work/AuthKey.p8"
archive="$work/Chimeling.xcarchive"
export_dir="$work/export"
identity="Developer ID Application: Cairntale LLC (2VW2ZL88HK)"

cleanup() {
	security delete-keychain "$keychain" >/dev/null 2>&1 || true
	rm -rf "$work"
}
trap cleanup EXIT

base64 -D >"$p12" <<EOF
$BUILD_CERTIFICATE_BASE64
EOF
printf '%s\n' "$APP_STORE_CONNECT_API_KEY_P8" >"$api_key"
chmod 600 "$p12" "$api_key"

security create-keychain -p "$KEYCHAIN_PASSWORD" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$keychain"
security import "$p12" -k "$keychain" -P "$P12_PASSWORD" -T /usr/bin/codesign -T /usr/bin/security
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$keychain"
security list-keychains -d user -s "$keychain" $(security list-keychains -d user | sed -e 's/"//g')
security default-keychain -s "$keychain"

xcodebuild archive \
	-project Chimeling.xcodeproj \
	-scheme Chimeling \
	-configuration Release \
	-destination 'generic/platform=macOS' \
	-archivePath "$archive" \
	-clonedSourcePackagesDirPath "$work/SourcePackages" \
	-allowProvisioningUpdates \
	-authenticationKeyPath "$api_key" \
	-authenticationKeyID "$APP_STORE_CONNECT_API_KEY_ID" \
	-authenticationKeyIssuerID "$APP_STORE_CONNECT_API_ISSUER_ID" \
	-skipPackagePluginValidation \
	-skipMacroValidation \
	DEVELOPMENT_TEAM=2VW2ZL88HK \
	CODE_SIGN_STYLE=Automatic \
	CODE_SIGN_IDENTITY="$identity" \
	OTHER_CODE_SIGN_FLAGS=--timestamp

xcodebuild -exportArchive \
	-archivePath "$archive" \
	-exportPath "$export_dir" \
	-exportOptionsPlist Scripts/DeveloperID.exportoptions.plist \
	-allowProvisioningUpdates \
	-authenticationKeyPath "$api_key" \
	-authenticationKeyID "$APP_STORE_CONNECT_API_KEY_ID" \
	-authenticationKeyIssuerID "$APP_STORE_CONNECT_API_ISSUER_ID"

app="$export_dir/Chimeling.app"
version="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")"
build="$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$app/Contents/Info.plist")"

notarize() {
	file="$1"
	set +e
	result="$(xcrun notarytool submit "$file" \
		--key "$api_key" \
		--key-id "$APP_STORE_CONNECT_API_KEY_ID" \
		--issuer "$APP_STORE_CONNECT_API_ISSUER_ID" \
		--wait \
		--timeout 30m \
		--output-format json 2>&1)"
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

zip="$work/Chimeling.zip"
ditto -c -k --keepParent "$app" "$zip"
notarize "$zip"
xcrun stapler staple "$app"

dmg_dir="$work/dmg"
mkdir -p "$dmg_dir"
cp -R "$app" "$dmg_dir/Chimeling.app"
ln -s /Applications "$dmg_dir/Applications"
dmg="$work/Chimeling-$version.dmg"
hdiutil create -volname Chimeling -srcfolder "$dmg_dir" -ov -format UDZO "$dmg"
codesign --timestamp --sign "$identity" "$dmg"
notarize "$dmg"
xcrun stapler staple "$dmg"

# Sparkle 2.10.1 matches Package.resolved. Each GitHub Release has its own
# download URL, so enclosures all use this tag. Deltas need one shared directory.
sparkle="$work/sparkle"
mkdir -p "$sparkle"
curl -fsSL -o "$work/sparkle.tar.xz" \
	https://github.com/sparkle-project/Sparkle/releases/download/2.10.1/Sparkle-2.10.1.tar.xz
tar -xJf "$work/sparkle.tar.xz" -C "$sparkle"
generate_appcast="$(find "$sparkle" -name generate_appcast -type f | head -n 1)"
inbox="$work/inbox"
mkdir -p "$inbox"
cp "$dmg" "$inbox/"
printf '%s' "$SPARKLE_PRIVATE_KEY" | "$generate_appcast" \
	--ed-key-file - \
	--download-url-prefix "https://github.com/cairntale/chimeling-macos/releases/download/$RELEASE_TAG/" \
	--maximum-deltas 0 \
	"$inbox"

notes="$work/notes.md"
printf 'Chimeling %s (%s)\n' "$version" "$build" >"$notes"
gh release view "$RELEASE_TAG" >/dev/null 2>&1 \
	&& gh release upload "$RELEASE_TAG" "$dmg" "$inbox/appcast.xml" --clobber \
	|| gh release create "$RELEASE_TAG" "$dmg" "$inbox/appcast.xml" \
		--title "Chimeling $version" \
		--notes-file "$notes"

# cleanup removes the keychain; published files are already on the release
trap - EXIT
cleanup
