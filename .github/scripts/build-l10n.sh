#!/bin/bash
set -e

echo "=== Building Koha L10N Package ==="

# Check if L10N repository exists
if [ ! -d "/tmp/koha-l10n" ]; then
    echo "L10N repository not found, skipping L10N package build"
    echo "This is optional and the main Koha package will still be built"
    exit 0
fi

cd /tmp/koha-l10n

# For shallow clones, we're already on the correct branch
echo "Current branch: $(git branch | grep '\*' | cut -d' ' -f2)"
echo "Latest commit: $(git log --oneline -1)"

echo "Building translation package..."
dpkg-buildpackage -us -uc

# Move built packages
echo "Moving L10N packages to debian directory..."
find .. -name "koha-l10n_*" -exec mv {} /tmp/debian/ \; || echo "No L10N packages found"

echo "=== L10N Package Build Complete ===" 