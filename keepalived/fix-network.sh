#!/bin/sh
set -e

echo Setting sysctls
sysctl net.ipv4.vs.conntrack=1
sysctl net.ipv4.vs.expire_nodest_conn=1

#ip link delete dnsnet-host
#iptables -t nat -D POSTROUTING -s 192.168.100.0/24 -o dnsnet-host -j SNAT --to-source 192.168.100.100

if (ip link show dnsnet-host up > /dev/null 2>&1); then
    echo "dnsnet-host link already added, skipping setup"
else
    echo "Creating dnsnet-host link"
    ip link add dnsnet-host link eth0.53 type ipvlan mode l3
    ip addr add 192.168.100.254/24 dev dnsnet-host
    ip link set dnsnet-host up
fi

if (iptables -t nat -C POSTROUTING -s 192.168.100.0/24 -o dnsnet-host -j SNAT --to-source 192.168.100.100 > /dev/null 2>&1); then
    echo "iptables rule already exists, skipping setup"
else
    echo "Setting up iptables"
    iptables -t nat -A POSTROUTING -s 192.168.100.0/24 -o dnsnet-host -j SNAT --to-source 192.168.100.100
fi
