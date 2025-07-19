#!/bin/bash

systemctl --user is-active --quiet ktrace.service
if [ $? -eq 0 ]; then
    echo "actif"
else
    echo "inactif"
fi
