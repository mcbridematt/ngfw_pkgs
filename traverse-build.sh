#!/bin/bash
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
cd ngfw_upstream
for i in $(cat build-order.txt | grep -v '#' | grep -v '^\$' | awk '{{print $1}}'); do
	echo "Building upstream $i"
	echo
	echo
	cd $i
	dpkg-buildpackage
	cd ..
	echo "DONE $i"
	echo
	echo
done
