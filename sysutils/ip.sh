#!/bin/bash
curl -s --max-time 2 https://api.ipify.org || echo "N/A"
