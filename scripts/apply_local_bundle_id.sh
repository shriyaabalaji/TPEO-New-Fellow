#!/usr/bin/env bash
# Applies bundle ID from ios/LocalBundleId.txt to the Xcode project.
# Run after git pull so your local signing survives. Used by the post-merge hook.
#
# The committed default matches Firebase iOS app "com.example.tpeoNewFellow"
# (see ios/Runner/GoogleService-Info.plist). This script swaps that default
# for the first non-comment line in LocalBundleId.txt when you need another
# registered app (e.g. com.shriyaabalaji.tpeonf.dev).

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOCAL_ID_FILE="$REPO_ROOT/ios/LocalBundleId.txt"
PBXPROJ="$REPO_ROOT/ios/Runner.xcodeproj/project.pbxproj"

if [ ! -f "$LOCAL_ID_FILE" ]; then
  exit 0
fi

BUNDLE_ID=$(grep -v '^[[:space:]]*#' "$LOCAL_ID_FILE" | sed -n '1p' | tr -d '[:space:]')
if [ -z "$BUNDLE_ID" ]; then
  exit 0
fi

# Committed default (Firebase plist + firebase_options.dart). Longest first.
CANONICAL_TESTS="com.example.tpeoNewFellow.RunnerTests"
CANONICAL_APP="com.example.tpeoNewFellow"
# Historical / alternate IDs still seen in older branches or local trees.
LEGACY1_TESTS="com.shriyaabalaji.tpeonf.dev.RunnerTests"
LEGACY1_APP="com.shriyaabalaji.tpeonf.dev"
LEGACY2_TESTS="com.tpeo.newfellow.RunnerTests"
LEGACY2_APP="com.tpeo.newfellow"
LEGACY3_TESTS="com.tpeo.tpeoNewFellow.RunnerTests"
LEGACY3_APP="com.tpeo.tpeoNewFellow"

sed -i '' "s/${CANONICAL_TESTS}/${BUNDLE_ID}.RunnerTests/g" "$PBXPROJ"
sed -i '' "s/${CANONICAL_APP}/${BUNDLE_ID}/g" "$PBXPROJ"
sed -i '' "s/${LEGACY1_TESTS}/${BUNDLE_ID}.RunnerTests/g" "$PBXPROJ"
sed -i '' "s/${LEGACY1_APP}/${BUNDLE_ID}/g" "$PBXPROJ"
sed -i '' "s/${LEGACY2_TESTS}/${BUNDLE_ID}.RunnerTests/g" "$PBXPROJ"
sed -i '' "s/${LEGACY2_APP}/${BUNDLE_ID}/g" "$PBXPROJ"
sed -i '' "s/${LEGACY3_TESTS}/${BUNDLE_ID}.RunnerTests/g" "$PBXPROJ"
sed -i '' "s/${LEGACY3_APP}/${BUNDLE_ID}/g" "$PBXPROJ"

echo "Applied local bundle ID: $BUNDLE_ID"
