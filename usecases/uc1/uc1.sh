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

UC=1
UCFOLDER=usecases/uc${UC}
CURDIR=$(dirname $0)
MINICONDIR=$(readlink -f $CURDIR/../..)

set -x
docker images ubuntu:latest
docker run --rm -it -v $MINICONDIR:/tmp/minicon ubuntu:latest /tmp/minicon/minicon -t /tmp/minicon/$UCFOLDER/uc${UC}.tar bash ls mkdir less cat find
docker import $MINICONDIR/$UCFOLDER/uc${UC}.tar minicon:uc${UC}
docker images minicon:uc${UC}
