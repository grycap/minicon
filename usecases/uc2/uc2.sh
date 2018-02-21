#!/bin/bash
#
# minicon - Minimization of filesystems for containers
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

UC=2
UCFOLDER=usecases/uc${UC}
REFIMAGE=minicon:uc${UC}fat
MINICONIMAGE=minicon:uc${UC}

CURDIR=$(dirname $0)
MINICONDIR=$(readlink -f $CURDIR/../..)

docker build $UCFOLDER -t $REFIMAGE

cat > $UCFOLDER/execfile-cmd <<\EOF
ssh localhost
/usr/bin/ssh localhost
/bin/ping -c 1 www.google.es
EOF

set -x
docker images $REFIMAGE
docker run --privileged --rm -it -v $MINICONDIR:/tmp/minicon $REFIMAGE bash -c "apt-get install -y strace && /tmp/minicon/minicon -t /tmp/minicon/$UCFOLDER/uc${UC}.tar --plugin=strace:execfile=/tmp/minicon/$UCFOLDER/execfile-cmd -E bash -E ssh -E ip -E id -E cat -E ls -E mkdir -E ping -E wget"
docker import $MINICONDIR/$UCFOLDER/uc${UC}.tar $MINICONIMAGE
docker images $MINICONIMAGE
