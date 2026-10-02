#!/bin/bash

# Smoke tests for RTEMS-pc686: boot softIoc in qemu-system-i386 with the PCI
# layout of a VMIVME-7750: an Intel 82559ER (fxp driver, the cabled port) and
# an ICH2 82562 (unconnected), both behind a PCI-to-PCI bridge on bus 1.
#
#   1. BOOTP: the legacy network stack is configured by qemu's DHCP server
#   2. static: network config on the multiboot command line (as written by
#      pxelinux/iPXE on real boards), then connect to the network console and
#      check that it serves the console history
#
# There is no NFS server, so the IOC stops before running a startup script.
#
# usage: tests/qemu-softioc.sh <developer image tag | softIoc.boot file>
# requires: docker (or podman), qemu-system-i386 and python3 on the host

set -euo pipefail

IMAGE=${1:?usage: $0 <developer image tag | softIoc.boot file>}
BOOT=/epics/epics-base/bin/RTEMS-pc686/softIoc.boot
CONSOLE_PORT=${CONSOLE_PORT:-2323}

if ! docker version &>/dev/null; then docker=podman; else docker=docker; fi

workdir=$(mktemp -d)
trap 'kill $(jobs -p) 2>/dev/null; rm -rf ${workdir}' EXIT

if [ -f "${IMAGE}" ]; then
    cp "${IMAGE}" ${workdir}/softIoc.boot
else
    $docker run --rm --entrypoint cat ${IMAGE} ${BOOT} > ${workdir}/softIoc.boot
fi

# NICs behind a PCI bridge (bus 1), unconnected 82562 (0x2449) first
board_nics() {
    echo -device pci-bridge,id=br1,chassis_nr=1 \
         -netdev socket,id=dead,mcast=230.0.0.1:12345 \
         -device i82801,netdev=dead,bus=br1,addr=0x4 \
         -device i82559er,netdev=lan,bus=br1,addr=0x6
}

echo "=== test 1: network configuration via BOOTP"
timeout 60 qemu-system-i386 -m 512 -no-reboot -display none -monitor none \
    -serial file:${workdir}/bootp.log \
    -netdev user,id=lan $(board_nics) \
    -append "--console=/dev/com1" \
    -kernel ${workdir}/softIoc.boot || true
tr -d '\r' < ${workdir}/bootp.log
grep -q "RTEMS Version" ${workdir}/bootp.log
grep -q "PCI IDs: 0x8086 0x1209" ${workdir}/bootp.log
grep -q "bootpc_init: using network interface 'fxp1'" ${workdir}/bootp.log
grep -q "Address:10.0.2.15" ${workdir}/bootp.log

echo "=== test 2: static network configuration and network console"
timeout 90 qemu-system-i386 -m 512 -no-reboot -display none -monitor none \
    -serial file:${workdir}/static.log \
    -netdev user,id=lan,hostfwd=tcp:127.0.0.1:${CONSOLE_PORT}-:23 $(board_nics) \
    -append "--console=/dev/com1 IPADDR0=10.0.2.15 NETMASK=255.255.255.0 GATEWAY=10.0.2.2 SERVER=10.0.2.2 HOSTNAME=qemuioc" \
    -kernel ${workdir}/softIoc.boot &

# connecting to the qemu port forward before the guest has booted stops the
# boot in qemu user networking, so wait for the server on the console first
for i in $(seq 60); do
    grep -q "netconsole on TCP port" ${workdir}/static.log 2>/dev/null && break
    sleep 1
done

python3 - ${CONSOLE_PORT} > ${workdir}/netconsole.log <<'PYEOF'
import socket, sys, time
s = socket.create_connection(("127.0.0.1", int(sys.argv[1])), timeout=5)
s.settimeout(1)
data = b""
t0 = time.time()
while time.time() - t0 < 8:
    try:
        chunk = s.recv(65536)
        if not chunk:
            break
        data += chunk
    except socket.timeout:
        pass
sys.stdout.write(data.decode("latin-1").replace("\r", ""))
PYEOF
kill %1 2>/dev/null || true
wait || true
tr -d '\r' < ${workdir}/static.log
echo "--- network console:"
cat ${workdir}/netconsole.log
grep -q "Address:10.0.2.15" ${workdir}/static.log
grep -q "RTEMS netconsole: history follows" ${workdir}/netconsole.log
grep -q "RTEMS Version" ${workdir}/netconsole.log
grep -q "PCI IDs: 0x8086 0x1209" ${workdir}/netconsole.log
grep -q "netconsole on TCP port 23" ${workdir}/netconsole.log

echo "RTEMS-pc686 softIoc: BOOTP, static config and network console OK"
