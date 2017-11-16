#!/bin/sh
for i in `cat traverse-build-order.txt | awk '{{print $1}}'`; do 
	echo "Building $i"
	echo
	echo
	cd $i
	dpkg-buildpackage
	cd ..
	echo "DONE $i"
	echo
	echo
done
