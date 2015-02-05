#!/bin/bash
#
# Ceph distributed storage system
#
# Copyright (C) 2014 Red Hat <contact@redhat.com>
#
# Author: Loic Dachary <loic@dachary.org>
#
#  This library is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public
#  License as published by the Free Software Foundation; either
#  version 2.1 of the License, or (at your option) any later version.
#

#
# Return true if the working tree is after the release that made
# make -j8 check possible
#
function can_parallel_make_check() {
    test "$(git rev-list --max-count=1 --ancestry-path HEAD ^tags/v0.88)"
}

function maybe_parallel_make_check() {
    if can_parallel_make_check ; then
        echo -j$(get_processors)
    fi
}
#
# Return MAX(1, (number of processors / 2)) by default or NPROC
#
function get_processors() {
    if test -n "$NPROC" ; then
        echo $NPROC
    else
        if test $(nproc) -ge 2 ; then
            expr $(nproc) / 2
        else
            echo 1
        fi
    fi
}

function run() {
    sudo $(which apt-get yum zypper 2>/dev/null) install -y ccache jq
    sudo modprobe rbd

    if test -f ./install-deps.sh ; then
	$DRY_RUN ./install-deps.sh || return 1
    fi
    $DRY_RUN ./autogen.sh || return 1
    $DRY_RUN ./configure "$@" --disable-static --with-radosgw --with-debug --without-lttng \
        CC="ccache gcc" CXX="ccache g++" CFLAGS="-Wall -g" CXXFLAGS="-Wall -g" || return 1
    $DRY_RUN make -j$(get_processors) || return 1
    $DRY_RUN make $(maybe_parallel_make_check) check || return 1
    $DRY_RUN make dist || return 1
}

function main() {
    if run "$@" ; then
        echo "make check: successful run on $(git rev-parse HEAD)"
        return 0
    else
        find . -name '*.trs' | xargs grep -l FAIL | while read file ; do
            log=$(dirname $file)/$(basename $file .trs).log
            echo FAIL: $log
            cat $log
        done
        return 1
    fi
}

main "$@"
