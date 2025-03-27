#!/bin/bash

set -e  # Exit on error

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <path-to-deb-file>"
    exit 1
fi

DEB_FILE="$1"

if [[ ! -f "$DEB_FILE" ]]; then
    echo "❌ Error: File '$DEB_FILE' not found!"
    exit 1
fi

# Construct new deb filename before doing any work
if [[ "$DEB_FILE" == *"Ubuntux64"* ]]; then
    # Replace "Ubuntux64" with "Debianx64"
    NEW_DEB_FILE="${DEB_FILE//Ubuntux64/Debianx64}"
else
    # Append "-debian" suffix only if "ubuntu" is not mentioned
    NEW_DEB_FILE="${DEB_FILE%.deb}-debian.deb"
fi

# Check if output file already exists
if [[ -f "$NEW_DEB_FILE" ]]; then
    echo "❌ Error: Output file '$NEW_DEB_FILE' already exists! Delete it manually before running the script."
    exit 1
fi

# Create a temporary directory
WORK_DIR=$(mktemp -d)
echo "📂 Using temporary directory: $WORK_DIR"

# Extract the deb file
dpkg-deb -R "$DEB_FILE" "$WORK_DIR"

CONTROL_FILE="$WORK_DIR/DEBIAN/control"
PREINST_FILE="$WORK_DIR/DEBIAN/preinst"

# Ensure control file exists
if [[ ! -f "$CONTROL_FILE" ]]; then
    echo "❌ Error: control file missing in the .deb package!"
    rm -rf "$WORK_DIR"
    exit 1
fi

# Check if "Version" exists in control file
if ! grep -q "^Version:" "$CONTROL_FILE"; then
    echo "❌ Error: 'Version' field missing in control file!"
    rm -rf "$WORK_DIR"
    exit 1
fi

# Extract version value
VERSION_LINE=$(grep "^Version:" "$CONTROL_FILE")
VERSION_VALUE=$(echo "$VERSION_LINE" | cut -d' ' -f2)

# Ensure +debian is not already present
if [[ "$VERSION_VALUE" == *"+debian"* ]]; then
    echo "❌ Error: Version already contains '+debian'."
    rm -rf "$WORK_DIR"
    exit 1
fi

# Append +debian to version
sed -i "s/^Version: .*/Version: ${VERSION_VALUE}+debian/" "$CONTROL_FILE"

# Ensure preinst file exists
if [[ ! -f "$PREINST_FILE" ]]; then
    echo "❌ Error: preinst file missing in the .deb package!"
    rm -rf "$WORK_DIR"
    exit 1
fi

# Modify MIN_VER_STR and CURRENT_VERSION
sed -i 's/MIN_VER_STR=.*/MIN_VER_STR="10"/' "$PREINST_FILE"
sed -i 's/CURRENT_VERSION=\${LSBS\[2\]}/CURRENT_VERSION=${LSBS[3]}/' "$PREINST_FILE"

# Rebuild the deb package
dpkg-deb -b "$WORK_DIR" "$NEW_DEB_FILE"

# Cleanup
rm -rf "$WORK_DIR"

echo "✅ Modified .deb package created: $NEW_DEB_FILE"
