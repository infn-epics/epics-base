#!/bin/bash
##########################################################################
##### install script for pvxs support module #############################
##########################################################################

VERSION=1.5.1
NAME=pvxs
THIS_DIR=$(dirname $(readlink -f $0))

detect_epics_host_arch() {
	local configured_arch="${EPICS_HOST_ARCH:-}"
	local configured_tool="${EPICS_BASE}/bin/${configured_arch}/makeMakefile.pl"

	if [[ -n "${configured_arch}" && -x "${configured_tool}" ]]; then
		echo "${configured_arch}"
		return 0
	fi

	# Fall back to the first host toolchain actually present in EPICS base.
	local detected_tool
	detected_tool=$(find "${EPICS_BASE}/bin" -maxdepth 2 -type f -name makeMakefile.pl | head -n 1)
	if [[ -z "${detected_tool}" ]]; then
		echo "ERROR: unable to find makeMakefile.pl under ${EPICS_BASE}/bin" >&2
		return 1
	fi

	basename "$(dirname "${detected_tool}")"
}

# Can't build for RTEMS because we need libevent-dev - how do we get that?
# scripts exist in linux-x86_64 folders

# log output and abort on failure
set -xe

EPICS_HOST_ARCH=$(detect_epics_host_arch)
export EPICS_HOST_ARCH
echo "Using EPICS_HOST_ARCH=${EPICS_HOST_ARCH}"

cd ${SUPPORT}
git clone https://github.com/epics-base/pvxs.git -b ${VERSION} --depth 1 ${NAME}
cd ${NAME}

# don't build test folders
sed -i -E 's/(^[^#].*example)/# \1/' Makefile
sed -i -E 's/(^[^#].*test)/# \1/' Makefile

# add in the global RELEASE file as
ln -s ${SUPPORT}/configure/RELEASE ./configure/RELEASE.local

echo pvxsIoc.dbd >> ${THIS_DIR}/../support/configure/dbd_list
echo pvxs >> ${THIS_DIR}/../support/configure/lib_list
echo pvxsIoc >> ${THIS_DIR}/../support/configure/lib_list

make -j $(nproc)
make clean

