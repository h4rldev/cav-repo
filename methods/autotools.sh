#!/usr/bin/env bash
# set -x # show cmds
set -e # fail globally

SCRIPT=$(realpath "${0}")
SCRIPTPATH=$(dirname "${SCRIPT}")

source "${SCRIPTPATH}/../utils/colors.sh"

CAVOS_FS_TARGET=$(readlink -f "${SCRIPTPATH}/../session/target")
CAVOS_TOOLS_BIN=$(readlink -f "${SCRIPTPATH}/../session/target/tools/bin")

# Cross compile an autotools package for our custom target (x86_64-cavos)
# Ensure the cavOS toolchain's in PATH
if [[ ":$PATH:" != *":$CAVOS_TOOLS_BIN:"* ]]; then
	export PATH=$CAVOS_TOOLS_BIN:$PATH
fi

# Arguments
uri=${1}
filename=$(echo "${uri}" | sed 's/.*\///g')
foldername=$(echo "${filename}" | sed 's/\.tar.*//g')

install_dir=${2}
if [ -z "$install_dir" ]; then
	install_dir=$(realpath -s "$CAVOS_FS_TARGET/usr/")
fi

config_sub_path=${3}

# EXTRA arguments
extra_parameters=${4}
optional_patchname=${5}
extra_install_parameters=${6}
before_build=${7}
after_build=${8}
archive_md5sum=${9}

# Make sure the tarball/folder isn't already there
if [[ "$filename" != *\/* ]] || [[ "$filename" != *\\* ]]; then
	# ^ is just so we don't delete anything important...
	rm -rf "$filename" "$foldername"
fi

echo -e "${BLUE}(p)${CLEAR} ${CYAN}(${foldername})${CLEAR} Downloading file"
# Download and extract the tarball
wget -nc "${uri}" >/dev/null 2>&1

if [[ "$(md5sum "${filename}" | sed 's/ .*//g')" != "${archive_md5sum}" ]]; then
	echo -e "${RED}!${CLEAR} Invalid md5sum! Exiting immediately!"
	exit 1
fi
echo -e "${BLUE}(p)${CLEAR} ${CYAN}(${foldername})${CLEAR} Extracting archive"
tar xpvf "${filename}" >/dev/null 2>&1
pushd "${foldername}" >/dev/null 2>&1

# Add our target
# sed -i 's/\# Now accept the basic system types\./cavos\*\);;/g' "${config_sub_path}"

# Do any optional patches
if [ -n "${optional_patchname}" ]; then
	echo -e "${BLUE}(p)${CLEAR} ${CYAN}(${foldername})${CLEAR} Applying ${optional_patchname} patch"
	patch -p1 <"../${optional_patchname}" >/dev/null 2>&1
fi

# Just in case it's needed
if [ -n "${before_build}" ]; then
	echo -e "${BLUE}(p)${CLEAR} ${CYAN}(${foldername})${CLEAR} Executing custom commands"
	eval "${before_build}" >/dev/null 2>&1
fi

# Use a separate directory for compiling (good practice)
mkdir -p build
pushd build >/dev/null 2>&1

# Compilation itself
echo -e "${BLUE}(p)${CLEAR} ${CYAN}(${foldername})${CLEAR} Configuring"
../configure --prefix="/usr" --host=x86_64-linux-musl ${extra_parameters} >/dev/null

echo -e "${BLUE}(p)${CLEAR} ${CYAN}(${foldername})${CLEAR} Compiling"
make -j$(nproc) >/dev/null

echo -e "${BLUE}(p)${CLEAR} ${CYAN}(${foldername})${CLEAR} Installing"
if [ -n "${extra_install_parameters}" ]; then
	make DESTDIR="$install_dir/../" install ${extra_install_parameters} >/dev/null
else
	make DESTDIR="$install_dir/../" install >/dev/null
fi

# Just in case it's needed
if [ -n "${after_build}" ]; then
	echo -e "${BLUE}(p)${CLEAR} ${CYAN}(${foldername})${CLEAR} Executing custom commands"
	eval "${after_build}" >/dev/null 2>&1
fi

# Cleanup
popd >/dev/null 2>&1
popd >/dev/null 2>&1

rm -rf "${foldername}"
rm -f "${filename}"
