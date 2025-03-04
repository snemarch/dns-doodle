#!/bin/sh

# watch clears the console, which isn't super for a docker-compose stack
#watch -n 15 nslookup -type=a google.com 192.168.100.100

# Use the default docker-host resolver

while true; do
    nslookup -type=a google.com
    sleep 15
done

