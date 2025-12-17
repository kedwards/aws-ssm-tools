#!/usr/bin/env bash
set -euo pipefail

REPO_NAME="aws-ssm-tools"
REPO="kedwards/${REPO_NAME}"
INSTALL_DIR="${HOME}/.local/share/${REPO_NAME}"
BIN_DIR="${HOME}/.local/bin"

# Determine the repo root for downloads
REPO_URL="https://github.com/${REPO}"

echo "[INFO] Installing ${REPO_NAME} to ${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}"
mkdir -p "${BIN_DIR}"

# Download latest main branch archive
echo "[INFO] Downloading ${REPO_NAME} from GitHub..."
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

curl -sSL "${REPO_URL}/archive/refs/heads/main.tar.gz" |
  tar xz -C "$tmpdir"

# Extracted directory will be "aws-tools-main"
EXTRACTED_DIR="${tmpdir}/${REPO_NAME}-main"

# Sync files into installation directory
echo "[INFO] Copying files..."
rsync -a --delete "${EXTRACTED_DIR}/" "${INSTALL_DIR}/"

# Symlink the bin/ commands
echo "[INFO] Creating symlinks in ${BIN_DIR}"
for f in "${INSTALL_DIR}/bin/"*; do
  cmd="$(basename "$f")"
  ln -sf "${f}" "${BIN_DIR}/${cmd}"
done

# Note: Default commands.config is in INSTALL_DIR and will be loaded automatically
# Users can create custom commands in ~/.config/aws-ssm-tools/commands.user.config
echo "[INFO] Default commands available in ${INSTALL_DIR}/commands.config"
echo "[INFO] Create custom commands in ~/.config/${REPO_NAME}/commands.user.config"

echo ""
echo "[SUCCESS] ${REPO_NAME} installed!"
echo ""
echo "Ensure ~/.local/bin is in your PATH:"
echo ""
# shellcheck disable=SC2016
echo '  export PATH="$HOME/.local/bin:$PATH"'
echo ""
echo "Available commands:"
echo ""
echo "  ssm connect        # Connect to instances"
echo "  ssm exec           # Execute commands"
echo "  ssm list           # List active sessions"
echo "  ssm kill           # Kill active sessions"
echo ""
echo "Try:"
echo "  ssm exec --help"
echo ""

