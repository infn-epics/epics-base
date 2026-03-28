# Release Notes

## 2026-03-28 - Multi-arch build and pvxs fixes

### Highlights
- Enabled linux-aarch64 builds in GitHub Actions.
- Added QEMU setup in CI to support non-native platform builds.
- Updated EPICS aarch64 toolchain configuration to avoid the upstream Xilinx SDK default path.
- Improved pvxs build robustness by auto-detecting the actual EPICS host architecture tools path.
- Kept EPICS host tools available during image build so pvxs can generate makefiles correctly.

### CI / Workflow
- Matrix now includes:
  - linux-x86_64 (platform linux/amd64)
  - linux-aarch64 (platform linux/arm64)

### Build scripts
- Added aarch64 config file at:
  - epics/scripts/aarch64/CONFIG_SITE.local
- Updated patch script to apply linux-aarch64-specific overrides.
- Updated pvxs install script to detect EPICS host architecture dynamically.

### Validation
- Verified local arm64 runtime image build succeeds using Buildx:
  - `docker buildx build --platform linux/arm64 --target runtime --build-arg EPICS_TARGET_ARCH=linux-aarch64 --build-arg EPICS_HOST_ARCH=linux-aarch64 --load .`
