#!/bin/sh

echo -e "\n\nSyncing...\n\n"

sudo rsync -rlpvz -e ssh /var/www/metavize \
    --exclude 'echospam*' \
    --exclude 'echod*' \
    --exclude 'test-*' \
    --exclude 'fprot-*' \
    --exclude 'sophos-*' \
    --exclude 'virus-transform*' \
    --exclude 'kernel-dev*' \
    --exclude 'dev-mv*' \
    root@release-alpha.metavize.com:/var/www.release-alpha/

scp \
    ~/work/pkgs/scripts/override.testing.metavize \
    ~/work/pkgs/scripts/deb-scan.sh  \
    ~/work/pkgs/scripts/clean-packages.sh \
    root@release-alpha.metavize.com:~/

echo -e "\n\nCleaning...\n\n"

ssh release-alpha.metavize.com -lroot "rm -f /var/www.release-alpha/metavize/pool/metavize/e/echod*"
ssh release-alpha.metavize.com -lroot "rm -f /var/www.release-alpha/metavize/pool/metavize/e/echospam*"
ssh release-alpha.metavize.com -lroot "rm -f /var/www.release-alpha/metavize/pool/metavize/t/test-*"
ssh release-alpha.metavize.com -lroot "rm -f /var/www.release-alpha/metavize/pool/metavize/f/fprot-*"
ssh release-alpha.metavize.com -lroot "rm -f /var/www.release-alpha/metavize/pool/metavize/s/sophos-*"
ssh release-alpha.metavize.com -lroot "rm -f /var/www.release-alpha/metavize/pool/metavize/v/virus-transform*"
ssh release-alpha.metavize.com -lroot "rm -f /var/www.release-alpha/metavize/pool/metavize/k/kernel-dev*"
ssh release-alpha.metavize.com -lroot "rm -f /var/www.release-alpha/metavize/pool/metavize/d/dev-mv*"
ssh release-alpha.metavize.com -lroot "sh ~/clean-packages.sh /var/www.release-alpha/metavize/pool/metavize 3 delete"

echo -e "\n\nBuilding Package List...\n\n"

ssh release-alpha.metavize.com -lroot "sh ~/deb-scan.sh /var/www.release-alpha/metavize "

