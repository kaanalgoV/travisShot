#!/usr/bin/env bash
set -euo pipefail

# Usage: bump-version.sh [major|minor|patch|build]
# Reads VERSION file (major.minor.patch-build), bumps the requested component.
# Default (no argument or "build"): bump build number only.
# "patch": bump patch, reset build to 1.
# "minor": bump minor, reset patch and build.
# "major": bump major, reset minor, patch, and build.

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION_FILE="$PROJECT_ROOT/VERSION"

if [ ! -f "$VERSION_FILE" ]; then
    echo "1.0.0-1" > "$VERSION_FILE"
fi

CURRENT=$(cat "$VERSION_FILE" | tr -d '[:space:]')

# Parse major.minor.patch-build
SEMVER="${CURRENT%%-*}"
BUILD="${CURRENT##*-}"

MAJOR=$(echo "$SEMVER" | cut -d. -f1)
MINOR=$(echo "$SEMVER" | cut -d. -f2)
PATCH=$(echo "$SEMVER" | cut -d. -f3)

COMPONENT="${1:-build}"

case "$COMPONENT" in
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        BUILD=1
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        BUILD=1
        ;;
    patch)
        PATCH=$((PATCH + 1))
        BUILD=1
        ;;
    build)
        BUILD=$((BUILD + 1))
        ;;
    *)
        echo "Usage: bump-version.sh [major|minor|patch|build]" >&2
        exit 1
        ;;
esac

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}-${BUILD}"
echo "$NEW_VERSION" > "$VERSION_FILE"
echo "$NEW_VERSION"
