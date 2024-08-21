#!/usr/bin/env bash

lockarray=()

while IFS= read -r -d $'\0'; do
	packages+=("${REPLY:5}")
done < <(find pkgs/ -type f ! -name dummy ! -name build.sh -print0)

for pkg_index in "${!packages[@]}"; do
	pkg=${packages[$pkg_index]}
	source pkgs/$pkg # source the package for name, version
	lockarray+=("$name-$version")
done

jq -n '$ARGS.positional' --args "${lockarray[@]}" >out/master.lock.cav
