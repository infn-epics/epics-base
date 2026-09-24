#!/usr/bin/env bash

THIS_DIR=$(dirname $(readlink -f $0))

# comment out the test directories from the Makefile
sed -i -E 's/(^[^#].*+= test.*$)/# \1/' \
    /epics/epics-base/Makefile
    # No longer adding submodules to the build
    # /epics/epics-base/modules/*/Makefile

if [[ ${EPICS_TARGET_ARCH} == "RTEMS-beatnik" ]]; then
    echo "Configuring epics-base to build RTEMS beatnik"

    cp ${THIS_DIR}/rtems/CONFIG_SITE.local ${EPICS_BASE}/configure/CONFIG_SITE.local
elif [[ ${EPICS_TARGET_ARCH} == "RTEMS-pc686" ]]; then
    echo "Configuring epics-base to build RTEMS pc686"

    cp ${THIS_DIR}/rtems-pc686/CONFIG_SITE.local ${EPICS_BASE}/configure/CONFIG_SITE.local
    cp ${THIS_DIR}/rtems-pc686/CONFIG_SITE.Common.RTEMS-pc686 \
       ${EPICS_BASE}/configure/os/CONFIG_SITE.Common.RTEMS-pc686
elif [[ ${EPICS_TARGET_ARCH} == "linux-aarch64" ]]; then
    echo "Configuring epics-base to build linux-aarch64"

    if [[ ${EPICS_HOST_ARCH} == "linux-aarch64" ]]; then
        # Native arm64 build: do not enable cross-compiler target archs.
        # Ensure commandline backend matches runtime image expectations.
        cat > ${EPICS_BASE}/configure/CONFIG_SITE.local <<'EOF'
COMMANDLINE_LIBRARY=EPICS
EOF
    else
        # Cross-compile to linux-aarch64 from non-arm64 host.
        cp ${THIS_DIR}/aarch64/CONFIG_SITE.local ${EPICS_BASE}/configure/CONFIG_SITE.local

        cat > ${EPICS_BASE}/configure/os/CONFIG_SITE.linux-x86_64.linux-aarch64 <<'EOF'
# Override upstream Xilinx SDK defaults and use distro cross toolchain.
GNU_TARGET = aarch64-linux-gnu
GNU_DIR = /usr
COMMANDLINE_LIBRARY = EPICS
EOF
    fi
elif [[ ${EPICS_TARGET_ARCH} != "linux-x86_64" ]]; then
    echo "Configuring epics-base for target ${EPICS_TARGET_ARCH}"

    touch ${EPICS_BASE}/configure/CONFIG_SITE.local
    echo CROSS_COMPILER_TARGET_ARCHS=${EPICS_TARGET_ARCH} >> \
      ${EPICS_BASE}/configure/CONFIG_SITE.local
fi