#! /bin/bash
#
# Copyright (C) 2015 Red Hat <contact@redhat.com>
#
# Author: David Zafman <dzafman@redhat.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU Library Public License as published by
# the Free Software Foundation; either version 2, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Library Public License for more details.
#
source $CEPH_ROOT/qa/standalone/ceph-helpers.sh

# Test development and debugging
# Set to "yes" in order to ignore diff errors and save results to update test
getjson="no"

jqfilter='.inconsistents'
sortkeys='import json; import sys ; JSON=sys.stdin.read() ; ud = json.loads(JSON) ; print json.dumps(ud, sort_keys=True, indent=2)'

function run() {
    local dir=$1
    shift

    export CEPH_MON="127.0.0.1:7121" # git grep '\<7121\>' : there must be only one
    export CEPH_ARGS
    CEPH_ARGS+="--fsid=$(uuidgen) --auth-supported=none "
    CEPH_ARGS+="--mon-host=$CEPH_MON "

    local funcs=${@:-$(set | sed -n -e 's/^\(TEST_[0-9a-z_]*\) .*/\1/p')}
    for func in $funcs ; do
        setup $dir || return 1
        $func $dir || return 1
        teardown $dir || return 1
    done
}

function create_scenario() {
    local dir=$1
    local poolname=$2
    local TESTDATA=$3
    local osd=$4

    SNAP=1
    rados -p $poolname mksnap snap${SNAP}
    dd if=/dev/urandom of=$TESTDATA bs=256 count=${SNAP}
    rados -p $poolname put obj1 $TESTDATA
    rados -p $poolname put obj5 $TESTDATA
    rados -p $poolname put obj3 $TESTDATA
    for i in `seq 6 14`
     do rados -p $poolname put obj${i} $TESTDATA
    done

    SNAP=2
    rados -p $poolname mksnap snap${SNAP}
    dd if=/dev/urandom of=$TESTDATA bs=256 count=${SNAP}
    rados -p $poolname put obj5 $TESTDATA

    SNAP=3
    rados -p $poolname mksnap snap${SNAP}
    dd if=/dev/urandom of=$TESTDATA bs=256 count=${SNAP}
    rados -p $poolname put obj3 $TESTDATA

    SNAP=4
    rados -p $poolname mksnap snap${SNAP}
    dd if=/dev/urandom of=$TESTDATA bs=256 count=${SNAP}
    rados -p $poolname put obj5 $TESTDATA
    rados -p $poolname put obj2 $TESTDATA

    SNAP=5
    rados -p $poolname mksnap snap${SNAP}
    SNAP=6
    rados -p $poolname mksnap snap${SNAP}
    dd if=/dev/urandom of=$TESTDATA bs=256 count=${SNAP}
    rados -p $poolname put obj5 $TESTDATA

    SNAP=7
    rados -p $poolname mksnap snap${SNAP}

    rados -p $poolname rm obj4
    rados -p $poolname rm obj2

    kill_daemons $dir TERM osd || return 1

    # Don't need to use ceph_objectstore_tool() function because osd stopped

    JSON="$(ceph-objectstore-tool --data-path $dir/${osd} --head --op list obj1)"
    ceph-objectstore-tool --data-path $dir/${osd} "$JSON" --force remove

    JSON="$(ceph-objectstore-tool --data-path $dir/${osd} --op list obj5 | grep \"snapid\":2)"
    ceph-objectstore-tool --data-path $dir/${osd} "$JSON" remove

    JSON="$(ceph-objectstore-tool --data-path $dir/${osd} --op list obj5 | grep \"snapid\":1)"
    OBJ5SAVE="$JSON"
    ceph-objectstore-tool --data-path $dir/${osd} "$JSON" remove

    JSON="$(ceph-objectstore-tool --data-path $dir/${osd} --op list obj5 | grep \"snapid\":4)"
    dd if=/dev/urandom of=$TESTDATA bs=256 count=18
    ceph-objectstore-tool --data-path $dir/${osd} "$JSON" set-bytes $TESTDATA

    JSON="$(ceph-objectstore-tool --data-path $dir/${osd} --head --op list obj3)"
    dd if=/dev/urandom of=$TESTDATA bs=256 count=15
    ceph-objectstore-tool --data-path $dir/${osd} "$JSON" set-bytes $TESTDATA

    JSON="$(ceph-objectstore-tool --data-path $dir/${osd} --op list obj4 | grep \"snapid\":7)"
    ceph-objectstore-tool --data-path $dir/${osd} "$JSON" remove

    JSON="$(ceph-objectstore-tool --data-path $dir/${osd} --head --op list obj2)"
    ceph-objectstore-tool --data-path $dir/${osd} "$JSON" rm-attr snapset

    # Create a clone which isn't in snapset and doesn't have object info
    JSON="$(echo "$OBJ5SAVE" | sed s/snapid\":1/snapid\":7/)"
    dd if=/dev/urandom of=$TESTDATA bs=256 count=7
    ceph-objectstore-tool --data-path $dir/${osd} "$JSON" set-bytes $TESTDATA

    JSON="$(ceph-objectstore-tool --data-path $dir/${osd} --head --op list obj6)"
    ceph-objectstore-tool --data-path $dir/${osd} "$JSON" clear-snapset
    JSON="$(ceph-objectstore-tool --data-path $dir/${osd} --head --op list obj7)"
    ceph-objectstore-tool --data-path $dir/${osd} "$JSON" clear-snapset corrupt
    JSON="$(ceph-objectstore-tool --data-path $dir/${osd} --head --op list obj8)"
    ceph-objectstore-tool --data-path $dir/${osd} "$JSON" clear-snapset seq
    JSON="$(ceph-objectstore-tool --data-path $dir/${osd} --head --op list obj9)"
    ceph-objectstore-tool --data-path $dir/${osd} "$JSON" clear-snapset clone_size
    JSON="$(ceph-objectstore-tool --data-path $dir/${osd} --head --op list obj10)"
    ceph-objectstore-tool --data-path $dir/${osd} "$JSON" clear-snapset clone_overlap
    JSON="$(ceph-objectstore-tool --data-path $dir/${osd} --head --op list obj11)"
    ceph-objectstore-tool --data-path $dir/${osd} "$JSON" clear-snapset clones
    JSON="$(ceph-objectstore-tool --data-path $dir/${osd} --head --op list obj12)"
    ceph-objectstore-tool --data-path $dir/${osd} "$JSON" clear-snapset head
    JSON="$(ceph-objectstore-tool --data-path $dir/${osd} --head --op list obj13)"
    ceph-objectstore-tool --data-path $dir/${osd} "$JSON" clear-snapset snaps
    JSON="$(ceph-objectstore-tool --data-path $dir/${osd} --head --op list obj14)"
    ceph-objectstore-tool --data-path $dir/${osd} "$JSON" clear-snapset size

    echo "garbage" > $dir/bad
    JSON="$(ceph-objectstore-tool --data-path $dir/${osd} --head --op list obj15)"
    ceph-objectstore-tool --data-path $dir/${osd} "$JSON" set-attr snapset $dir/bad
    rm -f $dir/bad
}

function TEST_scrub_snaps() {
    local dir=$1
    local poolname=test
    local OBJS=15
    local OSDS=1

    TESTDATA="testdata.$$"

    run_mon $dir a --osd_pool_default_size=$OSDS || return 1
    run_mgr $dir x || return 1
    for osd in $(seq 0 $(expr $OSDS - 1))
    do
      run_osd $dir $osd || return 1
    done

    # Create a pool with a single pg
    create_pool $poolname 1 1
    wait_for_clean || return 1
    poolid=$(ceph osd dump | grep "^pool.*[']test[']" | awk '{ print $2 }')

    dd if=/dev/urandom of=$TESTDATA bs=1032 count=1
    for i in `seq 1 $OBJS`
    do
        rados -p $poolname put obj${i} $TESTDATA
    done

    local primary=$(get_primary $poolname obj1)

    create_scenario $dir $poolname $TESTDATA $primary

    rm -f $TESTDATA

    for osd in $(seq 0 $(expr $OSDS - 1))
    do
      run_osd $dir $osd || return 1
    done

    local pgid="${poolid}.0"
    if ! pg_scrub "$pgid" ; then
        cat $dir/osd.0.log
        return 1
    fi

    test "$(grep "_scan_snaps start" $dir/osd.${primary}.log | wc -l)" = "2" || return 1

    rados list-inconsistent-pg $poolname > $dir/json || return 1
    # Check pg count
    test $(jq '. | length' $dir/json) = "1" || return 1
    # Check pgid
    test $(jq -r '.[0]' $dir/json) = $pgid || return 1

    rados list-inconsistent-obj $pgid > $dir/json || return 1

    # The injected snapshot errors with a single copy pool doesn't
    # see object errors because all the issues are detected by
    # comparing copies.
    jq "$jqfilter" << EOF | python -c "$sortkeys" > $dir/checkcsjson
{
    "epoch": 17,
    "inconsistents": []
}
EOF

    jq "$jqfilter" $dir/json | python -c "$sortkeys" > $dir/csjson
    multidiff $dir/checkcsjson $dir/csjson || test $getjson = "yes" || return 1

    rados list-inconsistent-snapset $pgid > $dir/json || return 1

    jq "$jqfilter" << EOF | python -c "$sortkeys" > $dir/checkcsjson
{
  "inconsistents": [
    {
      "errors": [
        "headless"
      ],
      "snap": 1,
      "locator": "",
      "nspace": "",
      "name": "obj1"
    },
    {
      "errors": [
        "size_mismatch"
      ],
      "snap": 1,
      "locator": "",
      "nspace": "",
      "name": "obj10"
    },
    {
      "errors": [
        "headless"
      ],
      "snap": 1,
      "locator": "",
      "nspace": "",
      "name": "obj11"
    },
    {
      "errors": [
        "size_mismatch"
      ],
      "snap": 1,
      "locator": "",
      "nspace": "",
      "name": "obj14"
    },
    {
      "errors": [
        "headless"
      ],
      "snap": 1,
      "locator": "",
      "nspace": "",
      "name": "obj6"
    },
    {
      "errors": [
        "headless"
      ],
      "snap": 1,
      "locator": "",
      "nspace": "",
      "name": "obj7"
    },
    {
      "errors": [
        "size_mismatch"
      ],
      "snap": 1,
      "locator": "",
      "nspace": "",
      "name": "obj9"
    },
    {
      "errors": [
        "headless"
      ],
      "snap": 4,
      "locator": "",
      "nspace": "",
      "name": "obj2"
    },
    {
      "errors": [
        "size_mismatch"
      ],
      "snap": 4,
      "locator": "",
      "nspace": "",
      "name": "obj5"
    },
    {
      "errors": [
        "headless"
      ],
      "snap": 7,
      "locator": "",
      "nspace": "",
      "name": "obj2"
    },
    {
      "errors": [
        "info_missing",
        "headless"
      ],
      "snap": 7,
      "locator": "",
      "nspace": "",
      "name": "obj5"
    },
    {
      "name": "obj10",
      "nspace": "",
      "locator": "",
      "snap": "head",
      "snapset": {
        "head_exists": 1,
        "snap_context": {
          "seq": 1,
          "snaps": [
            1
          ]
        },
        "clones": [
          {
            "snap": 1,
            "size": 1032,
            "overlap": "????",
            "snaps": [
              1
            ]
          }
        ]
      },
      "errors": []
    },
    {
      "extra clones": [
        1
      ],
      "errors": [
        "extra_clones"
      ],
      "snap": "head",
      "locator": "",
      "nspace": "",
      "name": "obj11",
      "snapset": {
        "head_exists": 1,
        "snap_context": {
          "seq": 1,
          "snaps": [
            1
          ]
        },
        "clones": []
      }
    },
    {
      "errors": [
        "head_mismatch"
      ],
      "snap": "head",
      "locator": "",
      "nspace": "",
      "name": "obj12",
      "snapset": {
        "head_exists": 0,
        "snap_context": {
          "seq": 1,
          "snaps": [
            1
          ]
        },
        "clones": [
          {
            "snap": 1,
            "size": 1032,
            "overlap": "[]",
            "snaps": [
              1
            ]
          }
        ]
      }
    },
    {
      "name": "obj14",
      "nspace": "",
      "locator": "",
      "snap": "head",
      "snapset": {
        "head_exists": 1,
        "snap_context": {
          "seq": 1,
          "snaps": [
            1
          ]
        },
        "clones": [
          {
            "snap": 1,
            "size": 1033,
            "overlap": "[]",
            "snaps": [
              1
            ]
          }
        ]
      },
      "errors": []
    },
    {
      "errors": [
        "snapset_corrupted"
      ],
      "snap": "head",
      "locator": "",
      "nspace": "",
      "name": "obj15"
    },
    {
      "extra clones": [
        7,
        4
      ],
      "errors": [
        "snapset_missing",
        "extra_clones"
      ],
      "snap": "head",
      "locator": "",
      "nspace": "",
      "name": "obj2"
    },
    {
      "errors": [
        "size_mismatch"
      ],
      "snap": "head",
      "locator": "",
      "nspace": "",
      "name": "obj3",
      "snapset": {
        "head_exists": 1,
        "snap_context": {
          "seq": 3,
          "snaps": [
            3,
            2,
            1
          ]
        },
        "clones": [
          {
            "snap": 1,
            "size": 1032,
            "overlap": "[]",
            "snaps": [
              1
            ]
          },
          {
            "snap": 3,
            "size": 256,
            "overlap": "[]",
            "snaps": [
              3,
              2
            ]
          }
        ]
      }
    },
    {
      "missing": [
        7
      ],
      "errors": [
        "clone_missing"
      ],
      "snap": "head",
      "locator": "",
      "nspace": "",
      "name": "obj4",
      "snapset": {
        "head_exists": 1,
        "snap_context": {
          "seq": 7,
          "snaps": [
            7,
            6,
            5,
            4,
            3,
            2,
            1
          ]
        },
        "clones": [
          {
            "snap": 7,
            "size": 1032,
            "overlap": "[]",
            "snaps": [
              7,
              6,
              5,
              4,
              3,
              2,
              1
            ]
          }
        ]
      }
    },
    {
      "missing": [
        2,
        1
      ],
      "extra clones": [
        7
      ],
      "errors": [
        "extra_clones",
        "clone_missing"
      ],
      "snap": "head",
      "locator": "",
      "nspace": "",
      "name": "obj5",
      "snapset": {
        "head_exists": 1,
        "snap_context": {
          "seq": 6,
          "snaps": [
            6,
            5,
            4,
            3,
            2,
            1
          ]
        },
        "clones": [
          {
            "snap": 1,
            "size": 1032,
            "overlap": "[]",
            "snaps": [
              1
            ]
          },
          {
            "snap": 2,
            "size": 256,
            "overlap": "[]",
            "snaps": [
              2
            ]
          },
          {
            "snap": 4,
            "size": 512,
            "overlap": "[]",
            "snaps": [
              4,
              3
            ]
          },
          {
            "snap": 6,
            "size": 1024,
            "overlap": "[]",
            "snaps": [
              6,
              5
            ]
          }
        ]
      }
    },
    {
      "extra clones": [
        1
      ],
      "errors": [
        "extra_clones"
      ],
      "snap": "head",
      "locator": "",
      "nspace": "",
      "name": "obj6",
      "snapset": {
        "head_exists": 1,
        "snap_context": {
          "seq": 1,
          "snaps": [
            1
          ]
        },
        "clones": []
      }
    },
    {
      "extra clones": [
        1
      ],
      "errors": [
        "head_mismatch",
        "extra_clones"
      ],
      "snap": "head",
      "locator": "",
      "nspace": "",
      "name": "obj7",
      "snapset": {
        "head_exists": 0,
        "snap_context": {
          "seq": 0,
          "snaps": []
        },
        "clones": []
      }
    },
    {
      "errors": [
        "snapset_error"
      ],
      "snap": "head",
      "locator": "",
      "nspace": "",
      "name": "obj8",
      "snapset": {
        "head_exists": 1,
        "snap_context": {
          "seq": 0,
          "snaps": [
            1
          ]
        },
        "clones": [
          {
            "snap": 1,
            "size": 1032,
            "overlap": "[]",
            "snaps": [
              1
            ]
          }
        ]
      }
    },
    {
      "name": "obj9",
      "nspace": "",
      "locator": "",
      "snap": "head",
      "snapset": {
        "head_exists": 1,
        "snap_context": {
          "seq": 1,
          "snaps": [
            1
          ]
        },
        "clones": [
          {
            "snap": 1,
            "size": "????",
            "overlap": "[]",
            "snaps": [
              1
            ]
          }
        ]
      },
      "errors": []
    }
  ],
  "epoch": 20
}
EOF

    jq "$jqfilter" $dir/json | python -c "$sortkeys" > $dir/csjson
    multidiff $dir/checkcsjson $dir/csjson || test $getjson = "yes" || return 1
    if test $getjson = "yes"
    then
        jq '.' $dir/json > save1.json
    fi

    if test "$LOCALRUN" = "yes" && which jsonschema > /dev/null;
    then
      jsonschema -i $dir/json $CEPH_ROOT/doc/rados/command/list-inconsistent-snap.json || return 1
    fi

    pidfiles=$(find $dir 2>/dev/null | grep 'osd[^/]*\.pid')
    pids=""
    for pidfile in ${pidfiles}
    do
        pids+="$(cat $pidfile) "
    done

    for i in `seq 1 7`
    do
        rados -p $poolname rmsnap snap$i
    done

    ERRORS=0

    for pid in $pids
    do
        if ! kill -0 $pid
        then
            echo "OSD Crash occurred"
            ERRORS=$(expr $ERRORS + 1)
        fi
    done

    kill_daemons $dir || return 1

    declare -a err_strings
    err_strings[0]="log_channel[(]cluster[)] log [[]ERR[]] : scrub [0-9]*[.]0 .*::obj10:.* : is missing in clone_overlap"
    err_strings[1]="log_channel[(]cluster[)] log [[]ERR[]] : scrub [0-9]*[.]0 .*::obj5:7 : no '_' attr"
    err_strings[2]="log_channel[(]cluster[)] log [[]ERR[]] : scrub [0-9]*[.]0 .*::obj5:7 : is an unexpected clone"
    err_strings[3]="log_channel[(]cluster[)] log [[]ERR[]] : scrub [0-9]*[.]0 .*::obj5:4 : on disk size [(]4608[)] does not match object info size [(]512[)] adjusted for ondisk to [(]512[)]"
    err_strings[4]="log_channel[(]cluster[)] log [[]ERR[]] : scrub [0-9]*[.]0 .*:::obj5:head : expected clone .*:::obj5:2"
    err_strings[5]="log_channel[(]cluster[)] log [[]ERR[]] : scrub [0-9]*[.]0 .*:::obj5:head : expected clone .*:::obj5:1"
    err_strings[6]="log_channel[(]cluster[)] log [[]INF[]] : scrub [0-9]*[.]0 .*:::obj5:head : 2 missing clone[(]s[)]"
    err_strings[7]="log_channel[(]cluster[)] log [[]ERR[]] : scrub [0-9]*[.]0 .*:::obj12:head : snapset.head_exists=false, but head exists"
    err_strings[8]="log_channel[(]cluster[)] log [[]ERR[]] : scrub [0-9]*[.]0 .*:::obj8:head : snaps.seq not set"
    err_strings[9]="log_channel[(]cluster[)] log [[]ERR[]] : scrub [0-9]*[.]0 .*:::obj7:head : snapset.head_exists=false, but head exists"
    err_strings[10]="log_channel[(]cluster[)] log [[]ERR[]] : scrub [0-9]*[.]0 .*:::obj7:1 : is an unexpected clone"
    err_strings[11]="log_channel[(]cluster[)] log [[]ERR[]] : scrub [0-9]*[.]0 .*:::obj3:head : on disk size [(]3840[)] does not match object info size [(]768[)] adjusted for ondisk to [(]768[)]"
    err_strings[12]="log_channel[(]cluster[)] log [[]ERR[]] : scrub [0-9]*[.]0 .*:::obj6:1 : is an unexpected clone"
    err_strings[13]="log_channel[(]cluster[)] log [[]ERR[]] : scrub [0-9]*[.]0 .*:::obj2:head : no 'snapset' attr"
    err_strings[14]="log_channel[(]cluster[)] log [[]ERR[]] : scrub [0-9]*[.]0 .*:::obj2:7 : clone ignored due to missing snapset"
    err_strings[15]="log_channel[(]cluster[)] log [[]ERR[]] : scrub [0-9]*[.]0 .*:::obj2:4 : clone ignored due to missing snapset"
    err_strings[16]="log_channel[(]cluster[)] log [[]ERR[]] : scrub [0-9]*[.]0 .*:::obj4:head : expected clone .*:::obj4:7"
    err_strings[17]="log_channel[(]cluster[)] log [[]INF[]] : scrub [0-9]*[.]0 .*:::obj4:head : 1 missing clone[(]s[)]"
    err_strings[18]="log_channel[(]cluster[)] log [[]ERR[]] : scrub [0-9]*[.]0 .*:::obj1:1 : is an unexpected clone"
    err_strings[19]="log_channel[(]cluster[)] log [[]ERR[]] : scrub [0-9]*[.]0 .*:::obj9:1 : is missing in clone_size"
    err_strings[20]="log_channel[(]cluster[)] log [[]ERR[]] : scrub [0-9]*[.]0 .*:::obj11:1 : is an unexpected clone"
    err_strings[21]="log_channel[(]cluster[)] log [[]ERR[]] : scrub [0-9]*[.]0 .*:::obj14:1 : size 1032 != clone_size 1033"
    err_strings[22]="log_channel[(]cluster[)] log [[]ERR[]] : [0-9]*[.]0 scrub 22 errors"
    err_strings[23]="log_channel[(]cluster[)] log [[]ERR[]] : scrub [0-9]*[.]0 .*:::obj15:head : can't decode 'snapset' attr buffer"

    for err_string in "${err_strings[@]}"
    do
        if ! grep "$err_string" $dir/osd.${primary}.log > /dev/null;
        then
            echo "Missing log message '$err_string'"
            ERRORS=$(expr $ERRORS + 1)
        fi
    done

    if [ $ERRORS != "0" ];
    then
        echo "TEST FAILED WITH $ERRORS ERRORS"
        return 1
    fi

    echo "TEST PASSED"
    return 0
}

function _scrub_snaps_multi() {
    local dir=$1
    local poolname=test
    local OBJS=15
    local OSDS=2
    local which=$2

    TESTDATA="testdata.$$"

    run_mon $dir a --osd_pool_default_size=$OSDS || return 1
    run_mgr $dir x || return 1
    for osd in $(seq 0 $(expr $OSDS - 1))
    do
      run_osd $dir $osd || return 1
    done

    # Create a pool with a single pg
    create_pool $poolname 1 1
    wait_for_clean || return 1
    poolid=$(ceph osd dump | grep "^pool.*[']test[']" | awk '{ print $2 }')

    dd if=/dev/urandom of=$TESTDATA bs=1032 count=1
    for i in `seq 1 $OBJS`
    do
        rados -p $poolname put obj${i} $TESTDATA
    done

    local primary=$(get_primary $poolname obj1)
    local replica=$(get_not_primary $poolname obj1)

    eval create_scenario $dir $poolname $TESTDATA \$$which

    rm -f $TESTDATA

    for osd in $(seq 0 $(expr $OSDS - 1))
    do
      run_osd $dir $osd || return 1
    done

    local pgid="${poolid}.0"
    if ! pg_scrub "$pgid" ; then
        cat $dir/osd.0.log
        return 1
    fi

    test "$(grep "_scan_snaps start" $dir/osd.${primary}.log | wc -l)" -gt "3" || return 1
    test "$(grep "_scan_snaps start" $dir/osd.${replica}.log | wc -l)" -gt "3" || return 1

    rados list-inconsistent-pg $poolname > $dir/json || return 1
    # Check pg count
    test $(jq '. | length' $dir/json) = "1" || return 1
    # Check pgid
    test $(jq -r '.[0]' $dir/json) = $pgid || return 1

    rados list-inconsistent-obj $pgid --format=json-pretty

    rados list-inconsistent-snapset $pgid > $dir/json || return 1

    # Since all of the snapshots on the primary is consistent there are no errors here
    if [ $which = "replica" ];
    then
        scruberrors="21"
        jq "$jqfilter" << EOF | python -c "$sortkeys" > $dir/checkcsjson
{
    "epoch": 23,
    "inconsistents": []
}
EOF

else
        scruberrors="33"
        jq "$jqfilter" << EOF | python -c "$sortkeys" > $dir/checkcsjson
{
    "epoch": 23,
    "inconsistents": [
        {
            "name": "obj10",
            "nspace": "",
            "locator": "",
            "snap": 1,
            "errors": [
                "size_mismatch"
            ]
        },
        {
            "name": "obj11",
            "nspace": "",
            "locator": "",
            "snap": 1,
            "errors": [
                "headless"
            ]
        },
        {
            "name": "obj14",
            "nspace": "",
            "locator": "",
            "snap": 1,
            "errors": [
                "size_mismatch"
            ]
        },
        {
            "name": "obj6",
            "nspace": "",
            "locator": "",
            "snap": 1,
            "errors": [
                "headless"
            ]
        },
        {
            "name": "obj7",
            "nspace": "",
            "locator": "",
            "snap": 1,
            "errors": [
                "headless"
            ]
        },
        {
            "name": "obj9",
            "nspace": "",
            "locator": "",
            "snap": 1,
            "errors": [
                "size_mismatch"
            ]
        },
        {
            "name": "obj5",
            "nspace": "",
            "locator": "",
            "snap": 7,
            "errors": [
                "info_missing",
                "headless"
            ]
        },
        {
            "name": "obj10",
            "nspace": "",
            "locator": "",
            "snap": "head",
            "snapset": {
                "head_exists": 1,
                "snap_context": {
                    "seq": 1,
                    "snaps": [
                        1
                    ]
                },
                "clones": [
                    {
                        "snap": 1,
                        "size": 1032,
                        "overlap": "????",
                        "snaps": [
                            1
                        ]
                    }
                ]
            },
            "errors": []
        },
        {
            "name": "obj11",
            "nspace": "",
            "locator": "",
            "snap": "head",
            "snapset": {
                "head_exists": 1,
                "snap_context": {
                    "seq": 1,
                    "snaps": [
                        1
                    ]
                },
                "clones": []
            },
            "errors": [
                "extra_clones"
            ],
            "extra clones": [
                1
            ]
        },
        {
           "errors": [
             "head_mismatch"
           ],
           "locator": "",
           "name": "obj12",
           "nspace": "",
           "snap": "head",
           "snapset": {
             "clones": [
               {
                 "overlap": "[]",
                 "size": 1032,
                 "snap": 1,
                 "snaps": [
                   1
                 ]
               }
             ],
             "head_exists": 0,
              "snap_context": {
              "seq": 1,
              "snaps": [
                1
              ]
            }
          }
        },
        {
            "name": "obj14",
            "nspace": "",
            "locator": "",
            "snap": "head",
            "snapset": {
                "head_exists": 1,
                "snap_context": {
                    "seq": 1,
                    "snaps": [
                        1
                    ]
                },
                "clones": [
                    {
                        "snap": 1,
                        "size": 1033,
                        "overlap": "[]",
                        "snaps": [
                            1
                        ]
                    }
                ]
            },
            "errors": []
        },
        {
            "name": "obj5",
            "nspace": "",
            "locator": "",
            "snap": "head",
            "snapset": {
                "head_exists": 1,
                "snap_context": {
                    "seq": 6,
                    "snaps": [
                        6,
                        5,
                        4,
                        3,
                        2,
                        1
                    ]
                },
                "clones": [
                    {
                        "snap": 1,
                        "size": 1032,
                        "overlap": "[]",
                        "snaps": [
                            1
                        ]
                    },
                    {
                        "snap": 2,
                        "size": 256,
                        "overlap": "[]",
                        "snaps": [
                            2
                        ]
                    },
                    {
                        "snap": 4,
                        "size": 512,
                        "overlap": "[]",
                        "snaps": [
                            4,
                            3
                        ]
                    },
                    {
                        "snap": 6,
                        "size": 1024,
                        "overlap": "[]",
                        "snaps": [
                            6,
                            5
                        ]
                    }
                ]
            },
            "errors": [
                "extra_clones"
            ],
            "extra clones": [
                7
            ]
        },
        {
            "name": "obj6",
            "nspace": "",
            "locator": "",
            "snap": "head",
            "snapset": {
                "head_exists": 1,
                "snap_context": {
                    "seq": 1,
                    "snaps": [
                        1
                    ]
                },
                "clones": []
            },
            "errors": [
                "extra_clones"
            ],
            "extra clones": [
                1
            ]
        },
        {
            "name": "obj7",
            "nspace": "",
            "locator": "",
            "snap": "head",
            "snapset": {
                "head_exists": 0,
                "snap_context": {
                    "seq": 0,
                    "snaps": []
                },
                "clones": []
            },
            "errors": [
                "head_mismatch",
                "extra_clones"
            ],
            "extra clones": [
                1
            ]
        },
        {
            "name": "obj8",
            "nspace": "",
            "locator": "",
            "snap": "head",
            "snapset": {
                "head_exists": 1,
                "snap_context": {
                    "seq": 0,
                    "snaps": [
                        1
                    ]
                },
                "clones": [
                    {
                        "snap": 1,
                        "size": 1032,
                        "overlap": "[]",
                        "snaps": [
                            1
                        ]
                    }
                ]
            },
            "errors": [
                "snapset_error"
            ]
        },
        {
            "name": "obj9",
            "nspace": "",
            "locator": "",
            "snap": "head",
            "snapset": {
                "head_exists": 1,
                "snap_context": {
                    "seq": 1,
                    "snaps": [
                        1
                    ]
                },
                "clones": [
                    {
                        "snap": 1,
                        "size": "????",
                        "overlap": "[]",
                        "snaps": [
                            1
                        ]
                    }
                ]
            },
            "errors": []
        }
    ]
}
EOF
fi

    jq "$jqfilter" $dir/json | python -c "$sortkeys" > $dir/csjson
    multidiff $dir/checkcsjson $dir/csjson || test $getjson = "yes" || return 1
    if test $getjson = "yes"
    then
        jq '.' $dir/json > save1.json
    fi

    if test "$LOCALRUN" = "yes" && which jsonschema > /dev/null;
    then
      jsonschema -i $dir/json $CEPH_ROOT/doc/rados/command/list-inconsistent-snap.json || return 1
    fi

    pidfiles=$(find $dir 2>/dev/null | grep 'osd[^/]*\.pid')
    pids=""
    for pidfile in ${pidfiles}
    do
        pids+="$(cat $pidfile) "
    done

    # When removing snapshots with a corrupt replica, it crashes.
    # See http://tracker.ceph.com/issues/23875
    if [ $which = "primary" ];
    then
        for i in `seq 1 7`
        do
            rados -p $poolname rmsnap snap$i
        done
    fi

    ERRORS=0

    for pid in $pids
    do
        if ! kill -0 $pid
        then
            echo "OSD Crash occurred"
            ERRORS=$(expr $ERRORS + 1)
        fi
    done

    kill_daemons $dir || return 1

    declare -a err_strings
    err_strings[0]="log_channel[(]cluster[)] log [[]ERR[]] : [0-9]*[.]0 shard [0-1] .*:::obj4:7 : missing"
    err_strings[1]="log_channel[(]cluster[)] log [[]ERR[]] : [0-9]*[.]0 shard [0-1] soid .*:::obj3:head : size 3840 != size 768 from auth oi"
    err_strings[2]="log_channel[(]cluster[)] log [[]ERR[]] : [0-9]*[.]0 shard [0-1] .*:::obj5:1 : missing"
    err_strings[3]="log_channel[(]cluster[)] log [[]ERR[]] : [0-9]*[.]0 shard [0-1] .*:::obj5:2 : missing"
    err_strings[4]="log_channel[(]cluster[)] log [[]ERR[]] : [0-9]*[.]0 shard [0-1] soid .*:::obj5:4 : size 4608 != size 512 from auth oi"
    err_strings[5]="log_channel[(]cluster[)] log [[]ERR[]] : [0-9]*[.]0 soid .*:::obj5:7 : failed to pick suitable object info"
    err_strings[6]="log_channel[(]cluster[)] log [[]ERR[]] : [0-9]*[.]0 shard [0-1] .*:::obj1:head : missing"
    err_strings[7]="log_channel[(]cluster[)] log [[]ERR[]] : [0-9]*[.]0 scrub ${scruberrors} errors"

    for err_string in "${err_strings[@]}"
    do
        if ! grep "$err_string" $dir/osd.${primary}.log > /dev/null;
        then
            echo "Missing log message '$err_string'"
            ERRORS=$(expr $ERRORS + 1)
        fi
    done

    if [ $ERRORS != "0" ];
    then
        echo "TEST FAILED WITH $ERRORS ERRORS"
        return 1
    fi

    echo "TEST PASSED"
    return 0
}

function TEST_scrub_snaps_replica() {
    local dir=$1
    ORIG_ARGS=$CEPH_ARGS
    CEPH_ARGS+=" --osd_scrub_chunk_min=3 --osd_scrub_chunk_max=3"
    _scrub_snaps_multi $dir replica
    err=$?
    CEPH_ARGS=$ORIG_ARGS
    return $err
}

function TEST_scrub_snaps_primary() {
    local dir=$1
    ORIG_ARGS=$CEPH_ARGS
    CEPH_ARGS+=" --osd_scrub_chunk_min=3 --osd_scrub_chunk_max=3"
    _scrub_snaps_multi $dir primary
    err=$?
    CEPH_ARGS=$ORIG_ARGS
    return $err
}

main osd-scrub-snaps "$@"

# Local Variables:
# compile-command: "cd build ; make -j4 && \
#    ../qa/run-standalone.sh osd-scrub-snaps.sh"
# End:
