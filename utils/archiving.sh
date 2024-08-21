#!/usr/bin/env bash
set -e
# set -x # Uncomment for debugging

archive() {
	if [ -z "${1}" ]; then
		echo -e "Invalid usage!\n${0} category/pkg"
		exit 1
	fi

	# $1 is of form category/pkg
	source "pkgs/${1}"

	# public information (cavOS repo path, etc)
	source "session/.config"

	if [[ -d "/tmp/cav-archive" ]]; then
		echo -e "${RED}(x)${CLEAR} Please let the other process finish first!"
		exit 1
	fi

	mkdir -p /tmp/cav-archive

	# Copy the package's respective files to the archive directory
	for path in ${paths[@]}; do
		# Copy the files to the archive directory
		PREFIX="${path%/*}"
		if [ ! -z $PREFIX ]; then
			mkdir -p "/tmp/cav-archive/$PREFIX/"
		fi

		cp -r "${cavos_path}/target/${path}" "/tmp/cav-archive/$PREFIX/"
	done

	pushd "/tmp/cav-archive" >/dev/null
	tar -czf "${cav_repo}/out/${name}-${version}.tar.gz.cav" .
	popd >/dev/null

	rm -rf "/tmp/cav-archive"
}
