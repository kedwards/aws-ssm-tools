#!/usr/bin/env bash
set -euo pipefail

REPO_NAME="aws-ssm-tools"
REPO="kedwards/${REPO_NAME}"
INSTALL_DIR="${HOME}/.local/share/${REPO_NAME}"
REPO_URL="https://github.com/${REPO}"

if [[ ! -d "${INSTALL_DIR}" ]]; then
  echo "[ERROR] ${REPO_NAME} is not installed in ${INSTALL_DIR}"
  echo "Install it with:"
  echo "  curl -sSL https://raw.githubusercontent.com/${REPO}/main/install.sh | bash"
  exit 1
fi

echo "[INFO] Updating ${REPO_NAME} in ${INSTALL_DIR}"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

echo "[INFO] Downloading latest version..."
curl -sSL "${REPO_URL}/archive/refs/heads/main.tar.gz" |
  tar xz -C "$tmpdir"

EXTRACTED_DIR="${tmpdir}/${REPO_NAME}-main"

echo "[INFO] Syncing files..."
rsync -a --delete "${EXTRACTED_DIR}/" "${INSTALL_DIR}/"

# Default commands.config is automatically updated in INSTALL_DIR
# User custom commands in ~/.config/aws-ssm-tools/commands.user.config are preserved
echo "[INFO] Default commands updated in ${INSTALL_DIR}/commands.config"
echo "[INFO] User custom commands preserved in ~/.config/${REPO_NAME}/commands.user.config"

echo ""
echo "[SUCCESS] ${REPO_NAME} updated!"
echo ""
