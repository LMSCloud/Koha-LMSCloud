#!/bin/bash
set -e

echo "=== Building Koha Main Package ==="
cd /tmp/koha-common

# Fix debian/clean file permissions (remove executable bit)
echo "Fixing debian/clean file permissions..."
chmod 644 debian/clean

# Fix git ownership issue
git config --global --add safe.directory "$(pwd)"

# For shallow clones, we're already on the correct branch
echo "Current branch: $(git branch | grep '\*' | cut -d' ' -f2)"
echo "Latest commit: $(git log --oneline -1)"

echo "Building main Koha package with version: $KOHA_VERSION"

# Instead of using the pbuilder-based build-git-snapshot script,
# we'll do a direct dpkg-buildpackage build since we're already in a container

echo "Preparing package build..."

# Update the changelog with our version
echo "Updating changelog..."
deb_version="${KOHA_VERSION}-1"

# Set environment variables for dch to avoid interactive prompts
export DEBEMAIL="$BUILD_EMAIL"
export DEBFULLNAME="Koha Build System"
export EMAIL="$BUILD_EMAIL"

dch --force-distribution -D "stable" -v "$deb_version" "Building git snapshot for version $KOHA_VERSION"
dch -r "Building git snapshot for version $KOHA_VERSION"

# Create the source tarball
echo "Creating source tarball..."
git archive --format=tar --prefix="koha-$KOHA_VERSION/" HEAD | gzip -9 > "../koha_$KOHA_VERSION.orig.tar.gz"

# Build the package using dpkg-buildpackage directly
echo "Building package with dpkg-buildpackage..."
export DEB_BUILD_OPTIONS=nocheck
export EMAIL=$BUILD_EMAIL

# Show current directory contents before build
echo "Directory contents before build:"
ls -la

# Export build environment variables
export DEB_BUILD_OPTIONS="nocheck parallel=1"
export EMAIL=$BUILD_EMAIL
export TMPDIR=/tmp
export DH_COMPAT=11

# Run dpkg-buildpackage with TMPDIR set to writable location
echo "Running dpkg-buildpackage with TMPDIR=/tmp..."
dpkg-buildpackage -us -uc -d
BUILD_STATUS=$?

echo "Build completed with status: $BUILD_STATUS"

# Show what was created
echo "Contents of parent directory after build:"
ls -la ..

# Create debian directory and move built packages
echo "Moving built packages to debian directory..."
mkdir -p /tmp/debian
MOVED_FILES=0
while read -r file; do
    if [ -f "$file" ]; then
        mv "$file" /tmp/debian/
        echo "Moved: $(basename "$file")"
        MOVED_FILES=$((MOVED_FILES + 1))
    fi
done < <(find .. -maxdepth 1 \( -name "*.deb" -o -name "*.dsc" -o -name "*.tar.*" -o -name "*.changes" \) -not -name "*l10n*")

echo "Total files moved: $MOVED_FILES"
echo "Final debian directory contents:"
ls -la /tmp/debian/

echo "=== Koha Main Package Build Complete ===" 