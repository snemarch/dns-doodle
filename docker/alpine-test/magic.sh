#!/bin/sh

ipvsadm --set 0 0 15
ipvsadm -A -u 192.168.100.100:53 -s rr
ipvsadm -a -u 192.168.100.100:53 -r 192.168.100.2:53 -m
ipvsadm -a -u 192.168.100.100:53 -r 192.168.100.3:53 -m
