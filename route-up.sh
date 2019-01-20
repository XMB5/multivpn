#!/bin/bash

printenv | sort

source "$(dirname "$0")/util.sh"

ip link set dev "$dev" up mtu "$tun_mtu"

if [ -n "$ifconfig_remote" ]; then
    ip addr add dev "$dev" local "$ifconfig_local" peer "$ifconfig_remote";
else
    ip addr add dev "$dev" "$ifconfig_local/$(netmask_to_netbits "$ifconfig_netmask")" broadcast "$ifconfig_broadcast"
fi

ip route add "$trusted_ip/32" via "$route_net_gateway"
if [ -z "$custom_local_address" ]; then
    ip route add 0.0.0.0/1 via "$route_vpn_gateway"
    ip route add 128.0.0.0/1 via "$route_vpn_gateway"
else
    ip route add default via "$ifconfig_local" dev "$dev" table "$route_table"
    for direction in from to; do
        ip rule add $direction "$ifconfig_local/32" table "$route_table"
    done
    iptables -t nat -A POSTROUTING -s "$custom_local_address" -j SNAT --to-source "$orig_ifconfig_local"
fi
ip route flush cache