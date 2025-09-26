#!/bin/bash

# Generate release notes from changelog and git history
# Usage: ./generate-release-notes.sh <version> [previous_version]

set -e

VERSION=${1:-"latest"}
PREVIOUS_VERSION=${2:-""}

echo "Generating release notes for version: $VERSION"

# Function to extract changelog section
extract_changelog_section() {
    local version=$1
    local changelog_file="CHANGELOG.md"
    
    if [ ! -f "$changelog_file" ]; then
        echo "Changelog file not found: $changelog_file"
        return 1
    fi
    
    # Try different version formats
    local patterns=(
        "^## \\[$version\\]"
        "^## \\[v$version\\]"
        "^## \\[$version\\]"
    )
    
    for pattern in "${patterns[@]}"; do
        if awk "/$pattern/,/^## \\[/ {if(/$pattern/) next; if(/^## \\[/) exit; print}" "$changelog_file" | head -n -1; then
            return 0
        fi
    done
    
    echo "No changelog entry found for version: $version"
    return 1
}

# Function to generate release notes from git commits
generate_git_notes() {
    local version=$1
    local previous=$2
    
    echo "## What's Changed"
    echo ""
    
    if [ -n "$previous" ]; then
        echo "### Full Changelog"
        echo ""
        echo "**Full Changelog**: https://github.com/$GITHUB_REPOSITORY/compare/$previous...$version"
        echo ""
    fi
    
    # Get merged pull requests since last release
    if [ -n "$previous" ]; then
        echo "### Merged Pull Requests"
        echo ""
        git log --merges --pretty=format:"- %s (%h)" "$previous..HEAD" | head -20
        echo ""
    fi
    
    # Get commits since last release
    if [ -n "$previous" ]; then
        echo "### Commits"
        echo ""
        git log --pretty=format:"- %s (%h) by %an" "$previous..HEAD" | head -20
        echo ""
    fi
}

# Main logic
if [ "$VERSION" = "latest" ]; then
    # Get the latest tag
    VERSION=$(git describe --tags --abbrev=0)
fi

# Remove 'v' prefix if present
CLEAN_VERSION=${VERSION#v}

# Get previous version if not specified
if [ -z "$PREVIOUS_VERSION" ]; then
    PREVIOUS_VERSION=$(git describe --tags --abbrev=0 "$VERSION^" 2>/dev/null || echo "")
fi

echo "Current version: $VERSION"
echo "Previous version: $PREVIOUS_VERSION"

# Try to extract from changelog first
if changelog_content=$(extract_changelog_section "$CLEAN_VERSION"); then
    echo "Found changelog entry for $CLEAN_VERSION"
    echo "$changelog_content"
else
    echo "No changelog entry found, generating from git history"
    generate_git_notes "$VERSION" "$PREVIOUS_VERSION"
fi
