#!/usr/bin/env bash
set -e
# set -x # Uncomment for debugging

if [ -z "${1}" ]; then
	echo -e "Invalid usage!\n${0} category/pkg"
	exit 1
fi

SCRIPT=$(realpath "${0}")
SCRIPTPATH=$(dirname "${SCRIPT}")
cd "$SCRIPTPATH/../"

# $1 is of form category/pkg
source "pkgs/${1}"

if [[ ! -d "session/target/transition" ]]; then
	echo "${RED}(x)${CLEAR} No transition directory!"
	exit 1
fi

pushd "session/target/transition" >/dev/null
tar -czf "${SCRIPTPATH}/../out/${name}-${version}.tar.gz.cav" .
popd >/dev/null

sudo rm -rf "session/target/transition"
