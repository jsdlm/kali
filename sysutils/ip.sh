#!/bin/bash
curl -s --max-time 2 ifconfig.me || echo "N/A"
