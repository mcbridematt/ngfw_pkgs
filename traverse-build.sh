#!/bin/bash
THIS_DIR=$(pwd)
for i in $(cat traverse-build-order.txt | awk '{{print $1}}'); do
	echo "Building $i"
	echo
	echo
	cd "${THIS_DIR}/${i}"
	dpkg-buildpackage
	echo "DONE $i"
	echo
	echo
done
cd "${THIS_DIR}/ngfw_upstream"
for i in $(cat build-order.txt | grep -v '#' | grep -v '^\$' | awk '{{print $1}}'); do
	echo "Building upstream $i"
	echo
	echo
	cd "${THIS_DIR}/ngfw_upstream/${i}"
	dpkg-buildpackage
	echo "DONE $i"
	echo
	echo
done
