#!/usr/bin/env bash
# set -x # show cmds
set -e # fail globally

# This is a simpler version of autotools.sh that's intended to be ran inside a chroot environment..

SCRIPT=$(realpath "${0}")
SCRIPTPATH=$(dirname "${SCRIPT}")

# Embed this here (we can't import stuff)
ESCAPE=$(printf "\e")
CLEAR="${ESCAPE}[0m"
BLACK="${ESCAPE}[0;30m"
RED="${ESCAPE}[0;31m"
GREEN="${ESCAPE}[0;32m"
YELLOW="${ESCAPE}[0;33m"
BLUE="${ESCAPE}[0;34m"
PURPLE="${ESCAPE}[0;35m"
CYAN="${ESCAPE}[0;36m"
WHITE="${ESCAPE}[0;37m"
GRAY="${ESCAPE}[1;30m"

# Arguments
uri=${1}
filename=$(echo "${uri}" | sed 's/.*\///g')
foldername=$(echo "${filename}" | sed 's/\.tar.*//g')
install_dir=${2}
archive_md5sum=${3}
extra_parameters=${4}
extra_install_parameters=${5}
after_build=${6}

if [[ "$(md5sum "${filename}" | sed 's/ .*//g')" != "${archive_md5sum}" ]]; then
	echo -e "${RED}!${CLEAR} Invalid md5sum! Exiting immediately!"
	exit 1
fi
echo -e "${BLUE}(i)${CLEAR} ${CYAN}(${foldername})${CLEAR} Extracting archive"
tar xpvf "${filename}" >/dev/null 2>&1
pushd "${foldername}" >/dev/null 2>&1

# Compilation itself
echo -e "${BLUE}(i)${CLEAR} ${CYAN}(${foldername})${CLEAR} Configuring"
FORCE_UNSAFE_CONFIGURE=1 ./configure --prefix=/usr ${extra_parameters} >/dev/null

echo -e "${BLUE}(i)${CLEAR} ${CYAN}(${foldername})${CLEAR} Compiling"
make -j$(nproc) >/dev/null

echo -e "${BLUE}(i)${CLEAR} ${CYAN}(${foldername})${CLEAR} Installing"
if [ -n "${extra_install_parameters}" ]; then
	make install DESTDIR="/transition" ${extra_install_parameters} >/dev/null
	make install ${extra_install_parameters} >/dev/null
else
	make install DESTDIR="/transition" >/dev/null
	make install >/dev/null
fi

# Just in case it's needed
if [ -n "${after_build}" ]; then
	echo -e "${BLUE}(i)${CLEAR} ${CYAN}(${foldername})${CLEAR} Executing custom commands"
	eval "${after_build}" >/dev/null 2>&1
fi

# Cleanup
popd >/dev/null 2>&1

rm -rf "${foldername}"
rm -f "${filename}"
