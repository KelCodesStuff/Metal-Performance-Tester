#!/bin/bash

# Update changelog with proper version links and navigation
# Usage: ./update-changelog-links.sh [repository_url]

set -e

REPO_URL=${1:-"https://github.com/yourusername/Metal-Performance-Tester"}
CHANGELOG_FILE="CHANGELOG.md"

echo "Updating changelog links for repository: $REPO_URL"

# Function to get all git tags
get_all_tags() {
    git tag --sort=-version:refname | head -20
}

# Function to update version history section
update_version_history() {
    local temp_file=$(mktemp)
    
    echo "## Version History" > "$temp_file"
    echo "" >> "$temp_file"
    
    # Get all tags and create links
    while IFS= read -r tag; do
        if [ -n "$tag" ]; then
            echo "- [\`$tag\`]($REPO_URL/releases/tag/$tag) - $(git log -1 --pretty=format:'%s' "$tag")" >> "$temp_file"
        fi
    done < <(get_all_tags)
    
    echo "" >> "$temp_file"
    echo "## Quick Navigation" >> "$temp_file"
    echo "" >> "$temp_file"
    echo "- [Latest Release]($REPO_URL/releases/latest)" >> "$temp_file"
    echo "- [All Releases]($REPO_URL/releases)" >> "$temp_file"
    echo "- [Compare Versions]($REPO_URL/compare)" >> "$temp_file"
    
    # Replace the version history section in the changelog
    awk '
    /^## Version History/ { 
        in_section = 1
        print
        next
    }
    /^## [^V]/ && in_section { 
        in_section = 0
    }
    in_section { 
        next
    }
    { 
        print 
    }
    ' "$CHANGELOG_FILE" > "${CHANGELOG_FILE}.tmp"
    
    # Insert the new version history
    awk -v new_content="$(cat "$temp_file")" '
    /^## Version History/ {
        print new_content
        next
    }
    { print }
    ' "${CHANGELOG_FILE}.tmp" > "$CHANGELOG_FILE"
    
    rm -f "$temp_file" "${CHANGELOG_FILE}.tmp"
}

# Function to update compare links in version entries
update_compare_links() {
    local temp_file=$(mktemp)
    
    # Process each version entry
    awk -v repo_url="$REPO_URL" '
    /^## \[.*\] -/ {
        current_version = $0
        gsub(/^## \[/, "", current_version)
        gsub(/\] - .*$/, "", current_version)
        gsub(/^v/, "", current_version)
        
        # Get previous version
        cmd = "git describe --tags --abbrev=0 " current_version "^ 2>/dev/null || echo \"\""
        cmd | getline prev_version
        close(cmd)
        
        if (prev_version != "") {
            gsub(/^v/, "", prev_version)
            print $0
            print ""
            print "[Full Changelog](" repo_url "/compare/v" prev_version "...v" current_version ")"
            print ""
        } else {
            print $0
            print ""
        }
        next
    }
    { print }
    ' "$CHANGELOG_FILE" > "$temp_file"
    
    mv "$temp_file" "$CHANGELOG_FILE"
}

# Main execution
if [ ! -f "$CHANGELOG_FILE" ]; then
    echo "Changelog file not found: $CHANGELOG_FILE"
    exit 1
fi

echo "Updating version history section..."
update_version_history

echo "Updating compare links..."
update_compare_links

echo "Changelog links updated successfully!"
echo ""
echo "Changes made:"
echo "- Updated version history with release links"
echo "- Added quick navigation section"
echo "- Updated compare links between versions"
echo ""
echo "Please review the changes and commit if satisfied."
