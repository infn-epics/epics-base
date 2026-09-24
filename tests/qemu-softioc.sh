#!/bin/bash

# Smoke test for RTEMS-pc686: boot softIoc in qemu-system-i386 with an Intel
# 82559ER NIC (the fxp driver used on the VMIVME-7750) and check that the
# legacy network stack comes up via BOOTP from qemu's user-mode network.
# There is no NFS server, so the IOC stops at the file system stage.
#
# usage: tests/qemu-softioc.sh <developer image tag>
# requires: docker (or podman) and qemu-system-i386 on the host

set -euo pipefail

IMAGE=${1:?usage: $0 <developer image tag>}
BOOT=/epics/epics-base/bin/RTEMS-pc686/softIoc.boot

if ! docker version &>/dev/null; then docker=podman; else docker=docker; fi

workdir=$(mktemp -d)
trap 'rm -rf ${workdir}' EXIT

$docker run --rm --entrypoint cat ${IMAGE} ${BOOT} > ${workdir}/softIoc.boot

timeout 90 qemu-system-i386 -m 256 -no-reboot -nographic \
    -nic user,model=i82559er \
    -append "--video=off --console=/dev/com1" \
    -kernel ${workdir}/softIoc.boot | tee ${workdir}/console.log || true

grep -q "RTEMS Version" ${workdir}/console.log
grep -q "Network Status" ${workdir}/console.log
grep -q "10.0.2.15" ${workdir}/console.log
echo "RTEMS-pc686 softIoc booted and configured fxp networking via BOOTP"
