#!/usr/bin/env bash
set -e

# Determine repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

# Add virtual environment to PATH if available
if [ -d "${SCRIPT_DIR}/../.venv/bin" ]; then
    export PATH="${SCRIPT_DIR}/../.venv/bin:${PATH}"
elif [ -d "${SCRIPT_DIR}/.venv/bin" ]; then
    export PATH="${SCRIPT_DIR}/.venv/bin:${PATH}"
fi

# Ensure protoc wrapper exists in venv if not present
VENV_BIN="$(which west 2>/dev/null | xargs dirname 2>/dev/null || true)"
if [ -n "${VENV_BIN}" ] && [ ! -f "${VENV_BIN}/protoc" ]; then
    cat << 'EOF' > "${VENV_BIN}/protoc"
#!/bin/bash
exec python3 -m grpc_tools.protoc "$@"
EOF
    chmod +x "${VENV_BIN}/protoc"
fi

# ISO timestamp for output folder (including milliseconds)
ISO_TIME="$(date +"%Y-%m-%dT%H-%M-%S.%3N")"
OUTPUT_DIR="builds/${ISO_TIME}"
mkdir -p "${OUTPUT_DIR}"

echo "========================================="
echo " Building Skinner47 Keyboard Firmware"
echo " Output Directory: ${OUTPUT_DIR}"
echo "========================================="

# 1. Build Left Half
echo ""
echo "--> Building Left Half (skinner47_left)..."
west build -s zmk/app -b skinner47_left -p always -- \
  -DSHIELD=nice_view \
  -DSNIPPET=studio-rpc-usb-uart \
  -DZMK_CONFIG="$(pwd)/config"

cp build/zephyr/zmk.uf2 "${OUTPUT_DIR}/skinner47_left.uf2"
echo "✔ Saved: ${OUTPUT_DIR}/skinner47_left.uf2"

# 2. Build Right Half
echo ""
echo "--> Building Right Half (skinner47_right)..."
west build -s zmk/app -b skinner47_right -p always -- \
  -DSHIELD=nice_view \
  -DZMK_CONFIG="$(pwd)/config"

cp build/zephyr/zmk.uf2 "${OUTPUT_DIR}/skinner47_right.uf2"
echo "✔ Saved: ${OUTPUT_DIR}/skinner47_right.uf2"

# 3. Build Settings Reset
echo ""
echo "--> Building Settings Reset (settings_reset)..."
west build -s zmk/app -b skinner47_left -p always -- \
  -DSHIELD=settings_reset \
  -DZMK_CONFIG="$(pwd)/config"

cp build/zephyr/zmk.uf2 "${OUTPUT_DIR}/settings_reset.uf2"
echo "✔ Saved: ${OUTPUT_DIR}/settings_reset.uf2"

echo ""
echo "========================================="
echo " Build Completed Successfully!"
echo " Firmware files saved to:"
echo "   - ${OUTPUT_DIR}/skinner47_left.uf2"
echo "   - ${OUTPUT_DIR}/skinner47_right.uf2"
echo "   - ${OUTPUT_DIR}/settings_reset.uf2"
echo "========================================="
