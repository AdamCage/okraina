#!/usr/bin/env bash
# Cloud Agent install: provision headless Godot and prime the import cache.
set -euo pipefail

GODOT_VERSION="4.7.2-stable"
GODOT_BIN_NAME="Godot_v${GODOT_VERSION}_linux.x86_64"
GODOT_ZIP="${GODOT_BIN_NAME}.zip"
GODOT_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/${GODOT_ZIP}"
GODOT_EXPECTED_VERSION="4.7.2.stable"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

install_godot() {
  local dest="$1"
  local tmpdir
  tmpdir="$(mktemp -d)"
  echo "Downloading ${GODOT_URL}"
  curl -fSL -o "${tmpdir}/godot.zip" "${GODOT_URL}"
  unzip -o "${tmpdir}/godot.zip" -d "${tmpdir}" >/dev/null
  chmod +x "${tmpdir}/${GODOT_BIN_NAME}"
  install -D -m 0755 "${tmpdir}/${GODOT_BIN_NAME}" "${dest}"
  rm -rf "${tmpdir}"
}

# Idempotent: only (re)install when the pinned Godot is not already on PATH.
if command -v godot >/dev/null 2>&1 && godot --version 2>/dev/null | grep -q "${GODOT_EXPECTED_VERSION}"; then
  echo "Godot ${GODOT_EXPECTED_VERSION} already installed: $(command -v godot)"
else
  if sudo -n true 2>/dev/null; then
    tmpdir="$(mktemp -d)"
    curl -fSL -o "${tmpdir}/godot.zip" "${GODOT_URL}"
    unzip -o "${tmpdir}/godot.zip" -d "${tmpdir}" >/dev/null
    chmod +x "${tmpdir}/${GODOT_BIN_NAME}"
    sudo install -m 0755 "${tmpdir}/${GODOT_BIN_NAME}" /usr/local/bin/godot
    rm -rf "${tmpdir}"
  else
    install_godot "${HOME}/.local/bin/godot"
    case ":${PATH}:" in
      *":${HOME}/.local/bin:"*) : ;;
      *) export PATH="${HOME}/.local/bin:${PATH}" ;;
    esac
  fi
fi

godot --version

# Prime the Godot import cache (.godot/ is gitignored) so headless smoke runs
# are deterministic and fast. Safe to re-run.
godot --headless --path "${repo_root}/game" --import

echo "Cloud Agent install complete."
