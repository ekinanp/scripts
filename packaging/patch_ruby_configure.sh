#!/usr/bin/env bash

PATCH_CMD="patch --strip=1 --fuzz=0 --ignore-whitespace --no-backup-if-mismatch"

version="$1"

[[ -z "${version}" ]] && echo "USAGE: ./update_ruby.sh <version>" && exit 1
[[ ! "${version}" =~ ^([0-9])\.([0-9])\.([0-9])$ ]] && echo "Version must be of the form <major>.<minor>.<patch>" && exit 1

major="${BASH_REMATCH[1]}"
minor="${BASH_REMATCH[2]}"
patch="${BASH_REMATCH[3]}"
configure_in_patch="/Users/enis.inan/GitHub/puppet-agent/resources/patches/ruby_${major}${minor}${patch}/revert_aix_configure_in_changes.patch"

ruby_dir="ruby-${version}"
ruby_tar="${ruby_dir}.tar.gz"

# Download the ruby TAR to the present directory

curl -o "${ruby_tar}" "https://cache.ruby-lang.org/pub/ruby/${major_minor}/${ruby_tar}"
tar -xvf "${ruby_tar}"

# Now patch configure.in and create the new "configure" file 

pushd "${ruby_dir}"
${PATCH_CMD} < ${configure_in_patch}
popd

temp_ruby_dir="${ruby_dir}_conf"
cp -r "${ruby_dir}" "${temp_ruby_dir}"
pushd "${temp_ruby_dir}"
autoconf
cp configure "../${ruby_dir}/"
popd

# TAR everything up, but first remove the original, downloaded TAR
rm "${ruby_tar}"
tar -zcvf "${ruby_tar}" "${ruby_dir}"

# Clean-up
rm -rf "${ruby_dir}"
rm -rf "${temp_ruby_dir}"
