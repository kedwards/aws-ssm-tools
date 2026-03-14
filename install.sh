#!/usr/bin/env bash
set -euo pipefail

REPO_NAME="aws-tools"
REPO="kedwards/${REPO_NAME}"
INSTALL_DIR="${HOME}/.local/share/${REPO_NAME}"
BIN_DIR="${HOME}/.local/bin"
REPO_URL="https://github.com/${REPO}"

# Parse version argument (defaults to latest release or main if no releases exist)
VERSION="${1:-latest}"

echo "[INFO] Installing ${REPO_NAME} to ${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}"
mkdir -p "${BIN_DIR}"

# Determine download URL based on version
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

if [[ "$VERSION" == "latest" ]]; then
  # Try to get latest release tag, fallback to main
  echo "[INFO] Fetching latest release..."
  LATEST_TAG=$(curl -sSL "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' || echo "")
  
  if [[ -n "$LATEST_TAG" ]]; then
    echo "[INFO] Downloading ${REPO_NAME} ${LATEST_TAG}..."
    DOWNLOAD_URL="${REPO_URL}/archive/refs/tags/${LATEST_TAG}.tar.gz"
    EXTRACTED_DIR="${tmpdir}/${REPO_NAME}-${LATEST_TAG#v}"
  else
    echo "[INFO] No releases found, downloading from main branch..."
    DOWNLOAD_URL="${REPO_URL}/archive/refs/heads/main.tar.gz"
    EXTRACTED_DIR="${tmpdir}/${REPO_NAME}-main"
  fi
elif [[ "$VERSION" == "main" ]] || [[ "$VERSION" == "dev" ]]; then
  echo "[INFO] Downloading ${REPO_NAME} from main branch..."
  DOWNLOAD_URL="${REPO_URL}/archive/refs/heads/main.tar.gz"
  EXTRACTED_DIR="${tmpdir}/${REPO_NAME}-main"
else
  # Install specific version (tag)
  echo "[INFO] Downloading ${REPO_NAME} ${VERSION}..."
  DOWNLOAD_URL="${REPO_URL}/archive/refs/tags/${VERSION}.tar.gz"
  EXTRACTED_DIR="${tmpdir}/${REPO_NAME}-${VERSION#v}"
fi

curl -sSL "$DOWNLOAD_URL" | tar xz -C "$tmpdir"

# Sync files into installation directory
echo "[INFO] Copying files..."
rsync -a --delete "${EXTRACTED_DIR}/" "${INSTALL_DIR}/"

# Copy default connections from examples/connections.config to connections.config
if [[ -f "${INSTALL_DIR}/examples/connections.config" ]]; then
  echo "[INFO] Installing default connections..."
  cp "${INSTALL_DIR}/examples/connections.config" "${INSTALL_DIR}/connections.config"
else
  echo "[WARN] examples/connections.config not found, skipping default connections"
fi

# Deploy default commands to user config directory
CONFIG_DIR="${HOME}/.config/${REPO_NAME}"
if [[ -d "${INSTALL_DIR}/examples/commands" ]]; then
  echo "[INFO] Installing default commands to ${CONFIG_DIR}/commands/..."
  mkdir -p "${CONFIG_DIR}/commands/aws" "${CONFIG_DIR}/commands/ssm"
  rsync -a "${INSTALL_DIR}/examples/commands/aws/" "${CONFIG_DIR}/commands/aws/"
  rsync -a "${INSTALL_DIR}/examples/commands/ssm/" "${CONFIG_DIR}/commands/ssm/"
else
  echo "[WARN] examples/commands not found, skipping default commands"
fi

# Symlink the bin/ commands
echo "[INFO] Creating symlinks in ${BIN_DIR}"
for f in "${INSTALL_DIR}/bin/"*; do
  cmd="$(basename "$f")"
  ln -sf "${f}" "${BIN_DIR}/${cmd}"
done

# Note: Commands are in ~/.config/aws-tools/commands/ — users manage them there
echo "[INFO] Commands installed to ${CONFIG_DIR}/commands/"
echo "[INFO] Default connections available in ${INSTALL_DIR}/connections.config"
echo "[INFO] Create custom connections in ~/.config/${REPO_NAME}/connections.user.config"

# Show installed version
INSTALLED_VERSION="$(cat "${INSTALL_DIR}/VERSION" 2>/dev/null || echo 'unknown')"

echo ""
echo "[SUCCESS] ${REPO_NAME} v${INSTALLED_VERSION} installed!"
echo ""
echo "Run 'awst --help' to get started."
echo ""

