#!/usr/bin/env bash
# Bumps the build number, archives Morse Lamp for iOS and uploads it to App Store Connect
# (TestFlight) in one command. Refuses to run with uncommitted changes so every uploaded
# build matches a commit.
#
#   scripts/release.sh            bump, archive, upload
#   scripts/release.sh --dry-run  print the commands instead of running them
#
# Authentication uses the Apple ID signed into Xcode. To use an App Store Connect API key
# instead, export ASC_KEY_PATH (the .p8, kept outside the repo), ASC_KEY_ID and ASC_ISSUER_ID.
set -Eeuo pipefail   # -E: the ERR trap below must fire inside run()
cd "$(dirname "$0")/.."

DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    *) echo "Unknown argument: $arg" >&2; exit 64 ;;
  esac
done

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree has uncommitted changes; commit or stash them before releasing." >&2
  exit 1
fi

CURRENT=$(xcrun agvtool what-version -terse)
NEXT=$((CURRENT + 1))
ARCHIVE="${TMPDIR:-/tmp}/MorseLamp-$NEXT.xcarchive"

AUTH=()
if [[ -n "${ASC_KEY_PATH:-}" ]]; then
  AUTH=(
    -authenticationKeyPath "$ASC_KEY_PATH"
    -authenticationKeyID "${ASC_KEY_ID:?ASC_KEY_ID must be set together with ASC_KEY_PATH}"
    -authenticationKeyIssuerID "${ASC_ISSUER_ID:?ASC_ISSUER_ID must be set together with ASC_KEY_PATH}"
  )
fi

run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    printf '%q ' "$@"; printf '\n'
  else
    "$@"
  fi
}

# The bump is committed only after the upload succeeds, so a failed archive or upload leaves
# no stray build commit; the trap puts the project file back.
restore_bump() { git checkout --quiet -- MorseLamp.xcodeproj/project.pbxproj; }
if [[ $DRY_RUN -eq 0 ]]; then trap restore_bump ERR; fi

run xcrun agvtool next-version -all
run xcodebuild archive -project MorseLamp.xcodeproj -scheme MorseLamp \
  -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" -allowProvisioningUpdates ${AUTH[@]+"${AUTH[@]}"}
run xcodebuild -exportArchive -archivePath "$ARCHIVE" \
  -exportOptionsPlist scripts/ExportOptions.plist -exportPath "$ARCHIVE.export" \
  -allowProvisioningUpdates ${AUTH[@]+"${AUTH[@]}"}

trap - ERR
run git add MorseLamp.xcodeproj/project.pbxproj
run git commit --quiet --message "🔖 Build $NEXT" \
  --message "Build number bumped by scripts/release.sh after uploading build $NEXT to TestFlight."

if [[ $DRY_RUN -eq 0 ]]; then echo "Build $NEXT uploaded; archive at $ARCHIVE"; fi
