#!/usr/bin/env bash
# Applies bundle ID from ios/LocalBundleId.txt to the Xcode project.
# Run after git pull so your local signing survives. Used by the post-merge hook.

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOCAL_ID_FILE="$REPO_ROOT/ios/LocalBundleId.txt"
PBXPROJ="$REPO_ROOT/ios/Runner.xcodeproj/project.pbxproj"

if [ ! -f "$LOCAL_ID_FILE" ]; then
  exit 0
fi

BUNDLE_ID=$(cat "$LOCAL_ID_FILE" | sed -n '1p' | tr -d '[:space:]')
if [ -z "$BUNDLE_ID" ]; then
  exit 0
fi

# Replace longer suffix first so RunnerTests gets correct ID
sed -i '' "s/com\.tpeo\.newfellow\.RunnerTests/${BUNDLE_ID}.RunnerTests/g" "$PBXPROJ"
sed -i '' "s/com\.tpeo\.newfellow/${BUNDLE_ID}/g" "$PBXPROJ"

echo "Applied local bundle ID: $BUNDLE_ID"
