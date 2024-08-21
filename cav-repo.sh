#!/usr/bin/env bash
set -e # fail globally

SCRIPT=$(realpath "${0}")
SCRIPTPATH=$(dirname "${SCRIPT}")

__NAME__="cav-repo"
__DESCRIPTION__="The cavOS packaging system"
__VERSION__="0.0.1"
__AUTHORS__="MalwarePad & h4rl"
__LICENSE__="GNU GPL-3.0"

# Ensure proper path
cd "${SCRIPTPATH}"

# Dependencies
source utils/colors.sh
source session/.config

# Global because we need it for seperators
MSG="-- cav-repo starting at $(date) --"

requirements() {
	local CAVOS__TARGET

	CAVOS__TARGET="${cavos_path}/target/"
	if [[ -e "~/opt/cross/bin/x86_64-cavos-gcc" ]]; then
		echo "${RED}(x)${CLEAR} No cross compiler found!"
		exit 1
	fi

	if [[ ! -d "$CAVOS__TARGET" ]]; then
		echo -e "${RED}(x)${CLEAR} cavOS target could not be fetched!"
		exit 1
	fi
}

sync_cavos() {
	if [ ! -d "$cavos_path" ]; then
		echo -e "${RED}(x)${CLEAR} FATAL! cavOS not found!\nMake sure you've properly cloned cavos and provided the path in the .config files...\nSee the session/ directory for details!"
		exit 1
	fi

	pushd "$cavos_path" >/dev/null

	echo -e "${BLUE}(i)${CLEAR} Syncing the cavOS git repository"
	git pull >/dev/null 2>&1

	echo -e "${BLUE}(i)${CLEAR} Building cavOS"
	make clean >/dev/null 2>&1
	make disk >/dev/null 2>&1

	popd >/dev/null
}

information() {
	local CPU_NAME
	local NPROC
	local DISTRO

	CPU_NAME="$(cat /proc/cpuinfo | grep -i "model name" | head -n 1 | sed 's/.*\: //g')"
	NPROC="$(nproc)"
	DISTRO="$(cat /etc/*-release | grep -i "PRETTY_NAME" | sed 's/PRETTY_NAME\=//g;s/\"//g')"

	echo -e "${GRAY}${MSG}${CLEAR}"
	echo -e "${BLUE}Distribution :${CLEAR} $DISTRO"
	echo -e "${BLUE}CPU Model    :${CLEAR} $CPU_NAME"
	echo -e "${BLUE}CPU Count    :${CLEAR} $NPROC"
}

seperator() {
	echo -en "${GRAY}"
	printf '%*s\n' "${#MSG}" '' | tr ' ' '-'
	echo -en "${CLEAR}"
}

precourse() {
	information
	seperator
	sync_cavos
	seperator
}

closure() {
	echo -e "\n${GRAY}-- cav-repo ended at $(date) --${CLEAR}"
}

single() {
	if [ -z "$1" ]; then
		echo -e "${RED}(x)${CLEAR} Bad usage! 1 argument required!"
		exit 1
	fi

	if [[ "$1" != *\/* ]]; then
		echo -e "${RED}(x)${CLEAR} Bad usage! Argument should be of type ${BLUE}category/pkg${CLEAR}!"
		exit 1
	fi

	requirements
	precourse

	chmod +x pkgs/build.sh
	pkgs/build.sh "$1"
	closure
}

all() {
	requirements

	local -a packages
	local processed_name
	packages=()

	requirements
	precourse

	while IFS= read -r -d $'\0'; do
		packages+=("${REPLY:5}")
	done < <(find pkgs/ -type f ! -name dummy ! -name build.sh -print0)

	for pkg_index in "${!packages[@]}"; do
		MSG="-- [$((pkg_index + 1))/${#packages[@]}] Packaging ${packages[$pkg_index]}... --"
		echo -e "\n${GRAY}${MSG}${CLEAR}"

		chmod +x pkgs/build.sh
		pkgs/build.sh "${packages[$pkg_index]}"

		seperator
	done

	closure
}

upload_master() {
	if [ ! -f "out/master.lock.cav" ]; then
		echo -e "${RED}(x)${CLEAR} Master lock could not be found!"
		exit 1
	fi

	utils/s3.sh "out/master.lock.cav" "master.lock.cav"
}

upload_single() {
	if [ -z "$1" ]; then
		echo -e "${RED}(x)${CLEAR} Bad usage! 1 argument required!"
		exit 1
	fi

	if [[ "$1" != *\/* ]]; then
		echo -e "${RED}(x)${CLEAR} Bad usage! Argument should be of type ${BLUE}category/pkg${CLEAR}!"
		exit 1
	fi

	source "pkgs/$1"
	ARCHIVE="out/${name}-${version}.tar.gz.cav"
	METADATA="out/${name}-${version}.meta.cav"
	if [ ! -f "$ARCHIVE" ]; then
		echo -e "${RED}(x)${CLEAR} $ARCHIVE couldn't be found!"
		exit 1
	fi

	if [ ! -f "$METADATA" ]; then
		echo -e "${RED}(x)${CLEAR} $METADATA couldn't be found!"
		exit 1
	fi

	chmod +x utils/s3.sh
	utils/s3.sh "$ARCHIVE" "${name}-${version}.tar.gz.cav"
	utils/s3.sh "$METADATA" "${name}-${version}.meta.cav"
	upload_master
}

upload_all() {
	local -a packages
	local package
	local ARCHIVE
	local METADATA

	chmod +x utils/s3.sh
	while IFS= read -r -d $'\0'; do
		packages+=("${REPLY:5}")
	done < <(find pkgs/ -type f ! -name dummy ! -name build.sh -print0)

	# i'm getting very tired and sleepy lmao
	# same but not sleepy
	# we're close to the end anyways
	# yeah, it's nice that it's fun and i get good vibes from that it's almost over
	# i can't type anymore
	# anomaly videos & vcing friends have kept me sane
	# i have been staring code in silence for the past 10 hours :")
	# very nice ceasar-chan!
	# ceasar-chan?
	# https://www.youtube.com/watch?v=4KNqFhJ6-n0
	# fire
	# uhhh, last chance, do we call it cav or cavpkg?
	# cav
	# copilot picked it for me, firehmmm
	#  do we just take a look around the codebase and then start pushing onto github?
	# yeah, we can do that
	# LMFAO the thought process is exactly of someone who has been writing code for almost 10 hours now

	for pkg_index in "${!packages[@]}"; do
		source "pkgs/${packages[$pkg_index]}"

		ARCHIVE="out/${name}-${version}.tar.gz.cav"
		METADATA="out/${name}-${version}.meta.cav"
		package="${packages[$pkg_index]}"

		utils/s3.sh "$ARCHIVE" "${name}-${version}.tar.gz.cav"
		utils/s3.sh "$METADATA" "${name}-${version}.meta.cav"
	done

	upload_master
}

print_version() {
	echo "${__NAME__} - ${__VERSION__}"
	echo "made with <3 by ${__AUTHORS__}"
}

print_help() {
	cat <<EOF
${__NAME__} - ${__DESCRIPTION__}
${__AUTHORS__} - ${__VERSION__}
Licensed under ${__LICENSE__}

Usage: $0 [options]

Options:
    -h, --help     Display this message
    -v, --version  Display version information
    -r, --regen    Force regenerate master lock
    -ps, --single  Build a single package
    -pa, --all     Build all packages
    -us, --usingle Upload a single package (along with master lock)
    -un, --uall    Upload all packages (along with master lock)

Made with <3 by ${__AUTHORS__}
EOF
}

case $1 in
-v | --version)
	print_version
	;;
-ps | --single)
	single "${2}"
	;;
-pa | --all)
	all
	;;
-r | --regen)
	chmod +x utils/gen_master.sh
	utils/gen_master.sh
	;;
-us | --usingle) # -u --silent????? # we can't really do it a different way and we don't support multiple arguments anyways, idk any different ways? maybe think about it while i implement this
	upload_single "$2"
	;;
-ua | --uall)
	upload_all
	;;
-h | --help | *)
	print_help
	;;
esac