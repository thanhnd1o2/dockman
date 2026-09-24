#!/usr/bin/env bash
# install.sh — Install Dockman by copying files to the system.
# Source directory is copied to INSTALL_LIB; a launcher is placed in INSTALL_BIN.
set -e

INSTALL_BIN="/usr/local/bin"
INSTALL_LIB="/usr/local/lib/dockman"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing Dockman..."

# Copy project files to install lib directory.
rm -rf "$INSTALL_LIB"
mkdir -p "$INSTALL_LIB"
cp -r "$SCRIPT_DIR/lib"         "$INSTALL_LIB/lib"
cp    "$SCRIPT_DIR/VERSION"     "$INSTALL_LIB/VERSION"

# Create a launcher script with the hardcoded install path.
cat > "$INSTALL_BIN/dockman" << EOF
#!/usr/bin/env bash
DOCKMAN_ROOT="$INSTALL_LIB"
export DOCKMAN_ROOT
source "\$DOCKMAN_ROOT/lib/app.sh"
main "\$@"
EOF
chmod +x "$INSTALL_BIN/dockman"

echo "Installed to: $INSTALL_LIB"
echo "Launcher:     $INSTALL_BIN/dockman"
echo "Run 'dockman' to start."
