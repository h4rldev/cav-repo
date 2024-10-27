#!/usr/bin/env bash
# set -x # show cmds
set -e # fail globally

SCRIPT=$(realpath "${0}")
SCRIPTPATH=$(dirname "${SCRIPT}")

# All paths on respective pkg/ files are taken from project root
pushd "${SCRIPTPATH}/../" >/dev/null

# colors for pretty output
source "utils/colors.sh"

# $1 is of form category/pkg
if [ -z "${1}" ]; then
	echo -e "${RED}(x)${CLEAR} Invalid usage!\n${0} category/pkg"
	exit 1
fi
source "pkgs/${1}"

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

if declare -p build_dependencies >/dev/null 2>&1; then
	for dependency in "${build_dependencies[@]}"; do
		source "pkgs/dummy"
		source "pkgs/${dependency}"
		if [[ ! -f "out/${name}-${version}.meta.cav" ]]; then
			echo -e "${YELLOW}(+)${CLEAR} ${CYAN}(${name})${CLEAR} is required but not found! (build dependency)"
			pkgs/build.sh "${category}/${name}"
		fi
	done
fi

# Source it back again (persists after scope of loop)
source "pkgs/dummy"
source "pkgs/${1}"

# Deps utilize recursion (no need for double-checks)
if [ -f "out/${name}-${version}.meta.cav" ]; then
	echo -e "${YELLOW}(-)${CLEAR} ${CYAN}(${name}-${version})${CLEAR} File already exists"
	exit 0
fi

if [[ -d "session/target/transition" ]]; then
	echo "${RED}(x)${CLEAR} Transition directory left hanging!"
	exit 1
fi

# Build package
if [[ "$system" == "host" ]]; then
	if [[ "$build_system" == "autotools" ]]; then
		# "methods/autotools.sh" "$archive" "$install_dir" "$config_sub_path" "$extra_parameters" "$optional_patchname" "$extra_install_parameters" "$before_build" "$aft_build" "$archive_md5sum"
		echo -e "${RED}(x)${CLEAR} Autotools build system todo/discontinued!"
		exit 1
	elif [[ "$build_system" == "cmd" ]]; then
		if ! declare -F cmd >/dev/null; then
			echo -e "${RED}(x)${CLEAR} Invalid build file, missing custom cmd function!"
			exit 1
		fi

		# Execute custom commands
		echo -e "${BLUE}(i)${CLEAR} ${CYAN}(${category}/${name})${CLEAR} Executing custom commands"
		cmd >/dev/null
	else
		echo -e "${RED}(x)${CLEAR} Could not detect build system! (autotools, cmd)"
		exit 1
	fi
elif [[ "$system" == "cavos" ]]; then
	if [[ "$build_system" == "autotools" ]]; then
		if [[ -z "${archive}" ]]; then
			echo -e "${RED}(x)${CLEAR} Invalid build file, missing autotools attributes!"
			exit 1
		fi

		# Include cavOS' chroot script
		source "utils/chroot.sh"

		# Compilation
		pushd "session/target/" >/dev/null
		echo -e "${BLUE}(i)${CLEAR} ${CYAN}(${category}/${name})${CLEAR} (host) Downloading file"
		# Download and extract the tarball
		wget -nc "${archive}" >/dev/null 2>&1

		cp "../../methods/autotools_hosted.sh" .
		chmod +x "autotools_hosted.sh"

		chroot_establish "."
		if ! sudo chroot "." /usr/bin/env -i HISTFILE=/dev/null PATH=/usr/bin:/usr/sbin /autotools_hosted.sh "$archive" "$install_dir" "$archive_md5sum" "$extra_parameters" "$extra_install_parameters" "$before_build" "$after_build"; then
			chroot_drop "."
			echo -e "${RED}!${CLEAR} Chroot fail! Exiting immediately!"
			exit 1
		fi
		chroot_drop "."

		rm -f "autotools_hosted.sh"
		popd >/dev/null
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
	chmod +x "utils/archiving.sh"
	utils/archiving.sh "${category}/${name}"
fi

# Metadata tagging
chmod +x "utils/gen_meta.sh"
"utils/gen_meta.sh" "${category}/${name}"

# Regenerate master
chmod +x "utils/gen_master.sh"
utils/gen_master.sh
