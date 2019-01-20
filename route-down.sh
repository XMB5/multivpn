#!/bin/bash

printenv | sort

source "$(dirname "$0")/util.sh"

ip route del "$trusted_ip/32"
if [ -z "$custom_local_address" ]; then
    ip route del 0.0.0.0/1
    ip route del 128.0.0.0/1
else
    iptables -t nat -D POSTROUTING -s "$custom_local_address" -j SNAT --to-source "$orig_ifconfig_local"
    for direction in from to; do
        ip rule del $direction "$ifconfig_local/32" table "$route_table"
    done
    ip route flush table "$route_table"
fi
if [ -n "$ifconfig_remote" ]; then
    ip addr del dev "$dev" local "$ifconfig_local" peer "$ifconfig_remote"
else
    ip addr del dev "$dev" "$ifconfig_local/$(netmask_to_netbits "$ifconfig_netmask")"
fi
ip route flush cache