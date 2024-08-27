#!/usr/bin/env bash
# set -x # show cmds
set -e # fail globally

SCRIPT=$(realpath "${0}")
SCRIPTPATH=$(dirname "${SCRIPT}")

# All paths on respective pkg/ files are taken from project root
pushd "${SCRIPTPATH}/../" >/dev/null

# colors for pretty output
source "utils/colors.sh"
source "utils/archiving.sh"

# public information (cavOS repo path, etc)
source "session/.config"

# $1 is of form category/pkg
if [ -z "${1}" ]; then
	echo -e "${RED}(x)${CLEAR} Invalid usage!\n${0} category/pkg"
	exit 1
fi
source "pkgs/${1}"

CAVOS__TARGET="${cavos_path}/target/"
if [[ -e "~/opt/cross/bin/x86_64-cavos-gcc" ]]; then
	echo "${RED}(x)${CLEAR} No cross compiler found!"
	exit 1
fi

if [[ ! -d "$CAVOS__TARGET" ]]; then
	echo -e "${RED}(x)${CLEAR} cavOS target could not be fetched!"
	exit 1
fi

if [[ -z "${name}" ]] ||
	[[ -z "${category}" ]] ||
	[[ -z "${beauty_name}" ]] ||
	[[ -z "${description}" ]] ||
	[[ -z "${uri}" ]] ||
	[[ -z "${version}" ]] ||
	[[ -z "${system}" ]] ||
	[[ -z "${build_system}" ]]; then
	echo -e "${RED}(x)${CLEAR} Invalid build file, missing generic attributes!"
	exit 1
fi

if ! declare -p paths >/dev/null 2>&1; then
	echo -e "${RED}(x)${CLEAR} Invalid build file, paths is required!"
	exit 1
fi

if ! declare -p dependencies >/dev/null 2>&1; then
	echo -e "${RED}(x)${CLEAR} Invalid build file, dependencies is required!"
	exit 1
fi

# Check if dependencies are installed
for dependency in "${dependencies[@]}"; do
	source "pkgs/dummy"
	source "pkgs/${dependency}"
	if [[ ! -f "out/${name}-${version}.meta.cav" ]]; then
		echo -e "${YELLOW}(+)${CLEAR} ${CYAN}(${name})${CLEAR} is required but not found!"
		pkgs/build.sh "${category}/${name}"
	fi
done

# Source it back again (persists after scope of loop)
source "pkgs/dummy"
source "pkgs/${1}"

# Deps utilize recursion (no need for double-checks)
if [ -f "out/${name}-${version}.meta.cav" ]; then
	echo -e "${YELLOW}(-)${CLEAR} ${CYAN}(${name}-${version})${CLEAR} File already exists"
	exit 0
fi

# Build package
if [[ "$system" == "host" ]]; then
	if [[ "$build_system" == "autotools" ]]; then
		if [[ -z "${archive}" ]] || [[ -z "${config_sub_path}" ]]; then
			echo -e "${RED}(x)${CLEAR} Invalid build file, missing autotools attributes!"
			exit 1
		fi

		# Compilation
		pushd "$cavos_path" >/dev/null
		chmod +x "${cav_repo}/methods/autotools.sh"
		"${cav_repo}/methods/autotools.sh" "$archive" "$install_dir" "$config_sub_path" "$extra_parameters" "$optional_patchname" "$extra_install_parameters" "$before_build" "$aft_build" "$archive_md5sum"
		pushd "${SCRIPTPATH}/../" >/dev/null
	elif [[ "$build_system" == "cmd" ]]; then
		if ! declare -F cmd >/dev/null; then
			echo -e "${RED}(x)${CLEAR} Invalid build file, missing custom cmd function!"
			exit 1
		fi

		# Execute custom commands
		echo -e "${BLUE}(i)${CLEAR} ${CYAN}(${category}/${name})${CLEAR} Executing custom commands"
		pushd "$cavos_path" >/dev/null
		cmd >/dev/null
		popd >/dev/null
	else
		echo -e "${RED}(x)${CLEAR} Could not detect build system! (autotools, cmd)"
		exit 1
	fi
elif [[ "$system" == "ignore" ]]; then
	echo "Ignored xd" >/dev/null
else
	echo -e "${RED}(x)${CLEAR} Could not detect system type (host, chroot)!"
	exit 1
fi

# Archiving
if [[ "$system" != "ignore" ]]; then
	echo -e "${BLUE}(i)${CLEAR} Finalizing ${CYAN}${name}-${version}.tar.gz.cav${CLEAR}"
	archive "${category}/${name}"
fi

# Metadata tagging
chmod +x "${cav_repo}/utils/gen_meta.sh"
"${cav_repo}/utils/gen_meta.sh" "${category}/${name}"

# Regenerate master
chmod +x "utils/gen_master.sh"
utils/gen_master.sh
