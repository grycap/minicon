#!/bin/bash
#
# DoSH - Docker SHell
# https://github.com/grycap/dosh
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

if [ ! -e "$SRCFOLDER/src" ]; then
  echo "could not find src folder in $SRCFOLDER"
  exit 1
fi

MANFOLDER="$SRCFOLDER/doc/man"

if [ ! -d "$MANFOLDER" ]; then
  MANFOLDER=
fi

SRCFOLDER="$SRCFOLDER/src"

source "$SRCFOLDER/version"

if [ $? -ne 0 ]; then
  echo "could not find the version for the package"
  exit 1
fi
REVISION=${VERSION##*-}

if [ "$REVISION" == "$VERSION" ]; then
  REVISION=
fi

if [ "$REVISION" != "" ]; then
  REVISION="-${REVISION}"
fi
VERSION=${VERSION%%-*}

FNAME=./minicon-${VERSION}
rm -rf "$FNAME"

mkdir -p "${FNAME}/bin"
mkdir -p "${FNAME}/usr/share/man/man1"

for i in minicon mergecon minidock importcon; do
  $SRCFOLDER/bashflatten -C $SRCFOLDER/$i > "${FNAME}/bin/$i"
  if [ -e "$MANFOLDER/$i.1" ]; then
    cp "$MANFOLDER/$i.1" "${FNAME}/usr/share/man/man1/"
    gzip "${FNAME}/usr/share/man/man1/${i}.1"
  fi
done

chmod 755 ${FNAME}/bin/*
chmod 644 ${FNAME}/usr/share/man/man1/*

tar czf minicon-${VERSION}.tar.gz $FNAME
cp minicon-${VERSION}.tar.gz ~/rpmbuild/SOURCES/
rpmbuild -ba minicon.spec
cp ~/rpmbuild/RPMS/noarch/minicon-${VERSION}${REVISION}.noarch.rpm .