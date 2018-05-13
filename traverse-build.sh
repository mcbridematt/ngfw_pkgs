#!/bin/bash

THIS_DIR=$(pwd)
mkdir -p repo/conf
cp _repoconf repo/conf/distributions

git clone https://github.com/untangle/ngfw_upstream

# Do some setup for the modified 'upstream' packages
curl https://files.pythonhosted.org/packages/39/51/fc4d3cdcf8f46509887d8771ce18ca6cfafd1d02eb429d69da95866a0b5e/javalang-0.11.0.tar.gz -o ngfw_upstream/python-javalang/javalang_0.11.0.orig.tar.gz

cd ngfw_upstream/iptables/
apt-get source iptables
cd iptables-1.6.0+snapshot20161117
cp ../iptables-1.6.0/upstream-patches/0600_IMQ.patch debian/patches/
echo "0600_IMQ.patch" >> debian/patches/series
mv ../iptables_1.6.0+snapshot20161117.orig.tar.bz2 ../iptables_1.6.0+snapshot20161117-6traverse.orig.tar.bz2
dch -l traverse-ut  "apply untangle IMQ patch"

cd "${THIS_DIR}"

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
reprepro -b repo includedeb stretch *.deb

cd "${THIS_DIR}/ngfw_upstream"
sed -i 's/iptables-1.6.0/iptables-1.6.0+snapshot20161117-6traverse/g' build-order.txt

for i in $(cat build-order.txt | grep -v '#' | grep -v '^\$' | awk '{{print $1}}'); do
	echo "Building upstream $i"
	echo
	echo
	cd "${THIS_DIR}/ngfw_upstream/${i}"
	dpkg-buildpackage
	cd ..
	reprepro -b "${THIS_DIR}/repo" includedeb stretch *.deb
	echo "DONE $i"
	echo
	echo
done
