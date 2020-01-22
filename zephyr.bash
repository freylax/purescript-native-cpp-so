#!/bin/bash
# call zephyr $1 are the exec and $2 the so entry point modules
#
# we compare if the size of the corefn file differs,
# if not we set the timestamp back to the previous build
# otherwise we would rebuild the generated sources evry time
# change comma separated list to space separated one

if [[ -n "$1" ]]; then
    ex="${1//,/$' '}"
fi;
if [[ -n "$2" ]]; then
    so="${2//,/$' '}"
fi;
#{
#  date  
#  echo "zephyr called with ($ex) and ($so)" 
#} >> zephyr.log

if [[ -e output/dce ]]; then
    for d in output/dce/*; do
	mv -f $d/corefn.json $d/old-corefn.json;
    done;
fi;

zephyr $ex $so -v -g corefn -i output/purs -o output/dce;
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

if [[ -n "$so" ]]; then
    rm -fr output/dce-exec;
    zephyr $ex -v -g corefn -i output/purs -o output/dce-exec;
    rm -fr output/dce-so;
    zephyr $so -v -g corefn -i output/purs -o output/dce-so;
fi;
    
    
