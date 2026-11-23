# Skinner47 ZMK Firmware Configuration

ZMK firmware configuration for the **Skinner47** keyboard using **ZMK (`v0.3-branch`)** and **Zephyr (`3.5.0`)**.

---

## Workspace Architecture

This setup places the repository inside a West workspace directory alongside `zmk`, `zephyr`, and external driver modules:

```text
~/zmk-workspace/
├── .venv/                      # Python virtual environment (west, Zephyr deps, grpcio-tools, setuptools)
├── .west/                      # West workspace metadata (created by `west init`)
├── zmk-config-Skinner47/       # This repository (Makefile, config/, README.md, builds/)
├── zmk/                        # Cloned by `west update` (`v0.3-branch`)
├── zephyr/                     # Cloned by `west update` (Zephyr 3.5.0 via `zmk/app/west.yml`)
├── zmk-pmw3610-driver/         # External driver (`badjeff`, `zmk-0.3`)
├── zmk-lpm009m360a-driver/      # External driver (`yangxing844`, `master`)
└── modules/                    # Additional Zephyr/West modules pulled by `zmk/app/west.yml`

```

> **WSL Note:** Keep the workspace on the native Linux filesystem (such as `~/zmk-workspace`) rather than `/mnt/c/...` to avoid slow cross-filesystem I/O and path/permission issues during CMake and Ninja builds.

---

## Prerequisites (Ubuntu WSL)

1. **Zephyr 3.5.0 System Dependencies:** Install the OS build packages (`cmake`, `ninja`, `dtc`, `gperf`, `python3-venv`, etc.) per the Zephyr getting-started guide for Ubuntu.
2. **Zephyr SDK (`0.16.x`):** Because `zmk` is pinned to `v0.3-branch` (Zephyr `3.5.0`), install a compatible SDK such as `0.16.8` with the `arm-zephyr-eabi` toolchain for nRF52840 targets:
```bash
cd ~
wget [https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v0.16.8/zephyr-sdk-0.16.8_linux-x86_64_minimal.tar.xz](https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v0.16.8/zephyr-sdk-0.16.8_linux-x86_64_minimal.tar.xz)
tar xf zephyr-sdk-0.16.8_linux-x86_64_minimal.tar.xz
cd ~/zephyr-sdk-0.16.8
./setup.sh -t arm-zephyr-eabi -c

```



---

## Setup From Scratch

### 1. Create the Workspace and Virtual Environment

Place or clone `zmk-config-Skinner47` inside your workspace directory (for example, `~/zmk-workspace/zmk-config-Skinner47`), then create and activate `.venv` at the workspace root:

```bash
mkdir -p ~/zmk-workspace
cd ~/zmk-workspace
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install --upgrade pip

```

### 2. Install West and Required Python Packages

Install `west`, `grpcio-tools` (invoked by the `protoc` wrapper in `Makefile`'s `check-env` target for ZMK Studio builds), and `setuptools==81.0.0` (which provides `pkg_resources` required by `nanopb`'s protobuf generator):

```bash
python3 -m pip install west grpcio-tools "setuptools==81.0.0"

```

### 3. Initialize West and Fetch Dependencies

From `~/zmk-workspace`, initialize West using `zmk-config-Skinner47` as the manifest repository and `config/west.yml` as the manifest file so `.west/` is created in `~/zmk-workspace/.west`:

```bash
cd ~/zmk-workspace
west init -l zmk-config-Skinner47 --mf config/west.yml
west update
west zephyr-export

```

### 4. Install Zephyr Python Requirements

With `.venv` active in `~/zmk-workspace`, install the Python packages expected by the checked-out Zephyr tree:

```bash
cd ~/zmk-workspace
python3 -m pip install -r zephyr/scripts/requirements.txt

```

---

## Building Firmware

Switch into the repository directory (`~/zmk-workspace/zmk-config-Skinner47`) and run `make`. The `Makefile` automatically adds `$(WORKSPACE_DIR)/.venv/bin` (or `$(ROOT_DIR)/.venv/bin`) to `PATH` and locates `zmk/app`.

### Standalone Split Mode (Left Central, Right Peripheral)

```bash
make all        # Builds left, right, and reset
make left       # skinner47_left + nice_view + studio-rpc-usb-uart (.uf2)
make right      # skinner47_right + nice_view (.uf2)
make reset      # settings_reset for halves (.uf2)

```

### Dongle Mode

```bash
make dongle-all    # Builds dongle, left-peri, right, reset, and dongle-reset
make dongle        # nrf52840dongle_nrf52840 + skinner47_dongle + studio-rpc-usb-uart (.hex and .uf2 if present)
make left-peri     # skinner47_left + nice_view skinner47_peripheral (.uf2)
make dongle-reset  # settings_reset for nrf52840dongle_nrf52840 (.hex and .uf2 if present)

```

### Build Options and Cleanup

```bash
make right PRISTINE=auto                     # PRISTINE: always (default), auto, or never
make left OUTPUT_DIR=/tmp/skinner47-out      # Custom output directory (default: builds/<timestamp>)
make BUILD_DIR=/tmp/skinner47-build right    # Custom intermediate build directory (default: build)
make clean                                   # Remove intermediate BUILD_DIR
make distclean                               # Remove BUILD_DIR and all builds/ outputs
make help                                    # Print Makefile usage

```

---

## Troubleshooting

* **`ModuleNotFoundError: No module named 'pkg_resources'` during `nanopb` proto generation:** Ensure `setuptools==81.0.0` is installed in `.venv` (`python3 -m pip install "setuptools==81.0.0"`).
* **Missing `protoc` during Studio builds:** The `Makefile`'s `check-env` target creates a `protoc` wrapper in the directory containing `west` that calls `python3 -m grpc_tools.protoc`. Verify `grpcio-tools` is installed in `.venv`.
* **Board or shield not found (`skinner47_left`, `skinner47_right`, `skinner47_dongle`, `skinner47_peripheral`):** Confirm your repository exposes a valid Zephyr module configuration (`zephyr/module.yml`) referencing your `boards/` and shield directories so CMake discovers them automatically without `-DBOARD_ROOT`.
