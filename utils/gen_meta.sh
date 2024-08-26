#!/usr/bin/env bash
# set -x # show cmds
set -e # fail globally

if [ -z "${1}" ]; then
	echo -e "Invalid usage!\n${0} category/pkg"
	exit 1
fi

# Deps
source session/.config
source pkgs/${1}

dependencies_json=$(jq -c -n '$ARGS.positional' --args "${dependencies[@]}")

# archive_md5sum belongs to the initial source code archive
correct_md5sum=$(md5sum "out/${name}-${version}.tar.gz.cav" | sed 's/ .*//g')

# write meta file
jq -n --arg name "${name}" \
	--arg category "${category}" \
	--arg beauty_name "${beauty_name}" \
	--arg description "${description}" \
	--arg version "${version}" \
	--arg uri "${uri}" \
	--arg md5sum "${correct_md5sum}" \
	--argjson dependencies "${dependencies_json}" \
	'{
        "category": $category,
        "name": $name,
        "beauty_name": $beauty_name,
        "description": $description,
        "uri": $uri,
        "version": $version,
        "md5sum": $md5sum,
        "dependencies": $dependencies
    }' >"out/${name}-${version}.meta.cav"

# validate meta file
jq '.' "out/${name}-${version}.meta.cav" >/dev/null
