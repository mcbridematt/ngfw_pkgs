#! /bin/bash

Xdialog --default-no --wrap --title "Recovery" --yesno "Are you sure want to run Recovery? It will stop network services." 15 60

if [ $? -eq 0 ]; then
    urxvt -T "Recovery" -e sudo /usr/share/untangle/bin/ut-restore
else
    echo "No shutting down"
fi
