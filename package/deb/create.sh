#!/bin/bash
#
# minicon - Minimization of Container Filesystems
# https://github.com/grycap/minicon
#
# Copyright (C) GRyCAP - I3M - UPV 
# Developed by Carlos A. caralla@upv.es
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

SRCFOLDER=$1
if [ "$SRCFOLDER" == "" ]; then
  SRCFOLDER="."
fi

# VERSION=$(cat "$SRCFOLDER/version")
source "$SRCFOLDER/version"

if [ $? -ne 0 ]; then
  echo "could not find the version for the package"
  exit 1
fi
REVISION=${VERSION##*-}
VERSION=${VERSION%%-*}

if [ "$REVISION" == "$VERSION" ]; then
  REVISION=
fi

if [ "$REVISION" != "" ]; then
  REVISION="-${REVISION}"
fi

FNAME=build/minicon_${VERSION}${REVISION}
mkdir -p "${FNAME}/bin"
mkdir -p "${FNAME}/DEBIAN"

for i in minicon mergecon minidock importcon; do
  $SRCFOLDER/bashflatten -C $SRCFOLDER/$i > "${FNAME}/bin/$i"
done

chmod 755 ${FNAME}/bin/*

cat > "${FNAME}/DEBIAN/control" << EOF
Package: minicon
Version: ${VERSION}${REVISION}
Section: base
Priority: optional
Architecture: all
Depends: bash, jq, tar, libc-bin, coreutils, tar, rsync, file, strace
Maintainer: Carlos A. <caralla@upv.es>
Description: MiniCon - Minimization of Container Filesystems
 **minicon** aims at reducing the footprint of the filesystem for arbitrary
 the container, just adding those files that are needed. That means that the
 other files in the original container are removed.
 **minidock** is a helper to use minicon for Docker containers.
EOF

cd "${FNAME}"
find . -type f ! -regex '.*.hg.*' ! -regex '.*?debian-binary.*' ! -regex '.*?DEBIAN.*' -printf "%P " | xargs md5sum > "DEBIAN/md5sums"
cd -

fakeroot dpkg-deb --build "${FNAME}"