#!/bin/bash
# call zephyr $1 are the exec and $2 the so entry point modules
#
# we compare if the size of the corefn file differs,
# if not we set the timestamp back to the previous build
# otherwise we would rebuild the generated sources evry time

if [[ -e output/dce ]]; then
    for d in output/dce/*; do
	mv -f $d/corefn.json $d/old-corefn.json;
    done;
fi;

zephyr $1 $2 -v -g corefn -i output/purs -o output/dce;
changed=""
(
    cd output/dce;
    for d in *; do
	if [[ ! -e $d/corefn.json ]]; then
	    rm -fr $d;
	elif [[ -e $d/old-corefn.json ]]; then
	    if [[ ../purs/$d/corefn.json -nt $d/old-corefn.json ]]; then
		#s1=$(stat -c%s $d/old-corefn.json);
		#s2=$(stat -c%s $d/corefn.json);
		#if [[ "$s1" -eq "$s2" ]]; then
		changed="$changed $d";
	    else
		touch -r $d/old-corefn.json $d/corefn.json;
	    fi;
	fi;
    done;
)
if [[ -n "$changed" ]]; then
    echo "zephyr changed modules:";
fi;

if [[ -n "$2" ]]; then
    rm -fr output/dce-exec;
    zephyr $1 -v -g corefn -i output/purs -o output/dce-exec;
    rm -fr output/dce-so;
    zephyr $2 -v -g corefn -i output/purs -o output/dce-so;
fi;
    
    
