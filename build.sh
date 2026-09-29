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

export ZEPHYR_TOOLCHAIN_VARIANT="${ZEPHYR_TOOLCHAIN_VARIANT:-zephyr}"
export ZEPHYR_SDK_INSTALL_DIR="${ZEPHYR_SDK_INSTALL_DIR:-/home/user/zephyr-sdk-0.16.8}"


# Locate workspace and ZMK app directory
WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
if [ -d "${WORKSPACE_DIR}/zmk/app" ]; then
    ZMK_APP_DIR="${WORKSPACE_DIR}/zmk/app"
elif [ -d "${SCRIPT_DIR}/zmk/app" ]; then
    ZMK_APP_DIR="${SCRIPT_DIR}/zmk/app"
else
    echo "Error: Cannot find zmk/app directory" >&2
    exit 1
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

MODE="${1:-dongle}"

# ISO timestamp for output folder (including milliseconds)
ISO_TIME="$(date +"%Y-%m-%dT%H-%M-%S.%3N")"
OUTPUT_DIR="${SCRIPT_DIR}/builds/${ISO_TIME}"
mkdir -p "${OUTPUT_DIR}"

echo "========================================="
echo " Building Skinner47 Firmware (Mode: ${MODE})"
echo " Output Directory: ${OUTPUT_DIR}"
echo "========================================="

case "${MODE}" in
    dongle|dongle-all)
        # 1. Build Dongle Central
        echo ""
        echo "--> Building Dongle Central (nrf52840dongle_nrf52840 + skinner47_dongle)..."
        west build -s "${ZMK_APP_DIR}" -d "${SCRIPT_DIR}/build" -b nrf52840dongle_nrf52840 -p always -- \
          -DSHIELD=skinner47_dongle \
          -DSNIPPET=studio-rpc-usb-uart \
          -DZMK_CONFIG="${SCRIPT_DIR}/config"

        cp "${SCRIPT_DIR}/build/zephyr/zmk.hex" "${OUTPUT_DIR}/skinner47_dongle.hex"
        [ -f "${SCRIPT_DIR}/build/zephyr/zmk.uf2" ] && cp "${SCRIPT_DIR}/build/zephyr/zmk.uf2" "${OUTPUT_DIR}/skinner47_dongle.uf2"
        echo "✔ Saved: ${OUTPUT_DIR}/skinner47_dongle.hex"
        [ -f "${OUTPUT_DIR}/skinner47_dongle.uf2" ] && echo "✔ Saved: ${OUTPUT_DIR}/skinner47_dongle.uf2"

        # 2. Build Left Half Peripheral
        echo ""
        echo "--> Building Left Half Peripheral (skinner47_left + skinner47_peripheral)..."
        west build -s "${ZMK_APP_DIR}" -d "${SCRIPT_DIR}/build" -b skinner47_left -p always -- \
          -DSHIELD="nice_view skinner47_peripheral" \
          -DZMK_CONFIG="${SCRIPT_DIR}/config"

        cp "${SCRIPT_DIR}/build/zephyr/zmk.uf2" "${OUTPUT_DIR}/skinner47_left_peripheral.uf2"
        echo "✔ Saved: ${OUTPUT_DIR}/skinner47_left_peripheral.uf2"

        # 3. Build Right Half Peripheral
        echo ""
        echo "--> Building Right Half (skinner47_right)..."
        west build -s "${ZMK_APP_DIR}" -d "${SCRIPT_DIR}/build" -b skinner47_right -p always -- \
          -DSHIELD=nice_view \
          -DZMK_CONFIG="${SCRIPT_DIR}/config"

        cp "${SCRIPT_DIR}/build/zephyr/zmk.uf2" "${OUTPUT_DIR}/skinner47_right.uf2"
        echo "✔ Saved: ${OUTPUT_DIR}/skinner47_right.uf2"

        # 4. Build Settings Reset for Halves
        echo ""
        echo "--> Building Settings Reset for Halves (skinner47_left)..."
        west build -s "${ZMK_APP_DIR}" -d "${SCRIPT_DIR}/build" -b skinner47_left -p always -- \
          -DSHIELD=settings_reset \
          -DZMK_CONFIG="${SCRIPT_DIR}/config"

        cp "${SCRIPT_DIR}/build/zephyr/zmk.uf2" "${OUTPUT_DIR}/settings_reset.uf2"
        echo "✔ Saved: ${OUTPUT_DIR}/settings_reset.uf2"

        # 5. Build Settings Reset for Dongle
        echo ""
        echo "--> Building Settings Reset for Dongle (nrf52840dongle_nrf52840)..."
        west build -s "${ZMK_APP_DIR}" -d "${SCRIPT_DIR}/build" -b nrf52840dongle_nrf52840 -p always -- \
          -DSHIELD=settings_reset \
          -DZMK_CONFIG="${SCRIPT_DIR}/config"

        cp "${SCRIPT_DIR}/build/zephyr/zmk.hex" "${OUTPUT_DIR}/settings_reset_dongle.hex"
        [ -f "${SCRIPT_DIR}/build/zephyr/zmk.uf2" ] && cp "${SCRIPT_DIR}/build/zephyr/zmk.uf2" "${OUTPUT_DIR}/settings_reset_dongle.uf2"
        echo "✔ Saved: ${OUTPUT_DIR}/settings_reset_dongle.hex"
        [ -f "${OUTPUT_DIR}/settings_reset_dongle.uf2" ] && echo "✔ Saved: ${OUTPUT_DIR}/settings_reset_dongle.uf2"
        ;;

    standalone)
        # 1. Build Left Half Central
        echo ""
        echo "--> Building Left Half (skinner47_left)..."
        west build -s "${ZMK_APP_DIR}" -d "${SCRIPT_DIR}/build" -b skinner47_left -p always -- \
          -DSHIELD=nice_view \
          -DSNIPPET=studio-rpc-usb-uart \
          -DZMK_CONFIG="${SCRIPT_DIR}/config"

        cp "${SCRIPT_DIR}/build/zephyr/zmk.uf2" "${OUTPUT_DIR}/skinner47_left.uf2"
        echo "✔ Saved: ${OUTPUT_DIR}/skinner47_left.uf2"

        # 2. Build Right Half Peripheral
        echo ""
        echo "--> Building Right Half (skinner47_right)..."
        west build -s "${ZMK_APP_DIR}" -d "${SCRIPT_DIR}/build" -b skinner47_right -p always -- \
          -DSHIELD=nice_view \
          -DZMK_CONFIG="${SCRIPT_DIR}/config"

        cp "${SCRIPT_DIR}/build/zephyr/zmk.uf2" "${OUTPUT_DIR}/skinner47_right.uf2"
        echo "✔ Saved: ${OUTPUT_DIR}/skinner47_right.uf2"

        # 3. Build Settings Reset
        echo ""
        echo "--> Building Settings Reset (settings_reset)..."
        west build -s "${ZMK_APP_DIR}" -d "${SCRIPT_DIR}/build" -b skinner47_left -p always -- \
          -DSHIELD=settings_reset \
          -DZMK_CONFIG="${SCRIPT_DIR}/config"

        cp "${SCRIPT_DIR}/build/zephyr/zmk.uf2" "${OUTPUT_DIR}/settings_reset.uf2"
        echo "✔ Saved: ${OUTPUT_DIR}/settings_reset.uf2"
        ;;

    *)
        echo "Unknown mode: ${MODE}. Available modes: dongle, standalone"
        exit 1
        ;;
esac

ln -sfn "${ISO_TIME}" "${SCRIPT_DIR}/builds/latest"

echo ""
echo "========================================="
echo " Build Completed Successfully!"
echo " Firmware files saved to ${OUTPUT_DIR}"
echo " Latest symlink updated at builds/latest"
echo "========================================="

