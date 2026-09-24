#!/bin/bash

# Smoke tests for RTEMS-pc686: boot softIoc in qemu-system-i386 with an Intel
# 82559ER NIC (the fxp driver used on the VMIVME-7750).
#
#   1. BOOTP: the legacy network stack is configured by qemu's DHCP server
#   2. static: network config on the multiboot command line (as written by
#      pxelinux/iPXE on real boards), then log in to the telnet iocsh
#
# There is no NFS server, so the IOC stops before running a startup script.
#
# usage: tests/qemu-softioc.sh <developer image tag>
# requires: docker (or podman), qemu-system-i386 and python3 on the host

set -euo pipefail

IMAGE=${1:?usage: $0 <developer image tag>}
BOOT=/epics/epics-base/bin/RTEMS-pc686/softIoc.boot
TELNET_PORT=${TELNET_PORT:-2323}

if ! docker version &>/dev/null; then docker=podman; else docker=docker; fi

workdir=$(mktemp -d)
trap 'kill $(jobs -p) 2>/dev/null; rm -rf ${workdir}' EXIT

$docker run --rm --entrypoint cat ${IMAGE} ${BOOT} > ${workdir}/softIoc.boot

echo "=== test 1: network configuration via BOOTP"
timeout 60 qemu-system-i386 -m 256 -no-reboot -nographic \
    -nic user,model=i82559er \
    -append "--video=off --console=/dev/com1" \
    -kernel ${workdir}/softIoc.boot > ${workdir}/bootp.log || true
cat ${workdir}/bootp.log
grep -q "RTEMS Version" ${workdir}/bootp.log
grep -q "bootpc_init: using network interface 'fxp1'" ${workdir}/bootp.log
grep -q "Address:10.0.2.15" ${workdir}/bootp.log

echo "=== test 2: static network configuration and telnet iocsh"
# console to a file (not -nographic) since qemu runs in the background
timeout 90 qemu-system-i386 -m 256 -no-reboot -display none -monitor none \
    -serial file:${workdir}/static.log \
    -nic user,model=i82559er,hostfwd=tcp:127.0.0.1:${TELNET_PORT}-:23 \
    -append "--console=/dev/com1 IPADDR0=10.0.2.15 NETMASK=255.255.255.0 GATEWAY=10.0.2.2 SERVER=10.0.2.2 HOSTNAME=qemuioc" \
    -kernel ${workdir}/softIoc.boot &

# connecting to the qemu port forward before the guest has booted stops the
# boot in qemu user networking, so wait for telnetd on the console first
for i in $(seq 60); do
    grep -q "telnetd start" ${workdir}/static.log 2>/dev/null && break
    sleep 1
done

python3 - ${TELNET_PORT} > ${workdir}/telnet.log <<'PYEOF'
import socket, sys, time
port = int(sys.argv[1])
deadline = time.time() + 30
data = b""
while time.time() < deadline:
    try:
        s = socket.create_connection(("127.0.0.1", port), timeout=5)
        s.settimeout(5)
        time.sleep(2)
        s.sendall(b"help\r\n")
        time.sleep(3)
        try:
            while True:
                chunk = s.recv(4096)
                if not chunk:
                    break
                data += chunk
        except socket.timeout:
            pass
        if b"Type 'help <glob>'" in data:
            break
    except OSError:
        time.sleep(3)
sys.stdout.write(data.decode("latin-1"))
PYEOF
kill %1 2>/dev/null || true
wait || true
tr -d '\r' < ${workdir}/static.log
echo "--- telnet session:"
cat ${workdir}/telnet.log
grep -q "Address:10.0.2.15" ${workdir}/static.log
grep -q "telnetd start: RTEMS_SUCCESSFUL" ${workdir}/static.log
grep -q "tIocSh>" ${workdir}/telnet.log
grep -q "Type 'help <glob>'" ${workdir}/telnet.log

echo "RTEMS-pc686 softIoc: BOOTP, static config and telnet iocsh OK"
