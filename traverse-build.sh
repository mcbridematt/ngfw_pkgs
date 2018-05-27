#!/bin/bash

THIS_DIR=$(pwd)
mkdir -p repo/conf
cp _repoconf repo/conf/distributions

git clone --branch arm64-fixes https://github.com/mcbridematt/ngfw_upstream

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
cd ngfw_upstream/libnetfilter-queue
mv libnetfilter-queue-1.0.2/ libnetfilter-queue-untangle
apt-get source libnetfilter-queue
cd libnetfilter-queue-1.0.2/
cp -r ../libnetfilter-queue-untangle/upstream-patches debian/patches
dch -l traverse-ut  "apply untangle NFQA patch"
cd ..
mv libnetfilter-queue_1.0.2.orig.tar.bz2 libnetfilter-queue_1.0.2-2traverse.orig.tar.bz2


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
echo "Adding debs to repo"
cd "${THIS_DIR}"
reprepro -b "${THIS_DIR}/repo" includedeb stretch ${THIS_DIR}/*.deb
du -h repo 

cd "${THIS_DIR}/ngfw_upstream"
sed -i 's/iptables-1.6.0/iptables-1.6.0+snapshot20161117-6traverse/g' build-order.txt
sed -i 's/libnetfilter-queue-1.0.2/libnetfilter-queue-1.0.2-2traverse/g' build-order.txt

for i in $(cat build-order.txt | grep -v '#' | grep -v '^\$' | awk '{{print $1}}'); do
	echo "Building upstream $i"
	echo
	echo
	cd "${THIS_DIR}/ngfw_upstream/${i}"
	dpkg-buildpackage -b -us -uc
	cd ..
	reprepro -b "${THIS_DIR}/repo" includedeb stretch *.deb
	echo "DONE $i"
	echo
	echo
done
