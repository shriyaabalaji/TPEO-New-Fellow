#!/usr/bin/env bash
# Install git hooks so 'git pull' automatically applies your local iOS bundle ID.
# Run once: ./scripts/install-git-hooks.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GIT_DIR="$REPO_ROOT/.git"
HOOKS_DIR="$GIT_DIR/hooks"

if [ ! -d "$GIT_DIR" ]; then
  echo "Not a git repo."
  exit 1
fi

mkdir -p "$HOOKS_DIR"
cp "$SCRIPT_DIR/post-merge" "$HOOKS_DIR/post-merge"
chmod +x "$HOOKS_DIR/post-merge"
chmod +x "$SCRIPT_DIR/apply_local_bundle_id.sh"

if [ ! -f "$REPO_ROOT/ios/LocalBundleId.txt" ]; then
  echo "Create ios/LocalBundleId.txt with your bundle ID (e.g. com.yourteam.tpeo.newfellow)"
  echo "See ios/LocalBundleId.txt.example"
fi

echo "Git hooks installed. After 'git pull', your local bundle ID will be applied automatically."
