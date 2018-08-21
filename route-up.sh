#!/bin/bash

echo "route-up > dev: $dev  rt_table: $rt_table  custom_local_address: $custom_local_address  \
ifconfig_local: $ifconfig_local  ifconfig_remote: $ifconfig_remote  route_vpn_gateway: $route_vpn_gateway  \
tun_mtu: $tun_mtu"

if [[ "$dev" != tun* ]]; then
    echo "only tun devices are supported"
    exit 1
fi

ifconfig "$dev" "$custom_local_address" pointopoint "$ifconfig_remote" mtu "$tun_mtu"

ip route add default via "$route_vpn_gateway" dev "$dev" table "$rt_table"
ip rule add from "$custom_local_address/32" table "$rt_table"
ip rule add to "$route_vpn_gateway/32" table "$rt_table"
ip route flush cache

iptables -t nat -A POSTROUTING --source "$custom_local_address" -j SNAT --to-source "$ifconfig_local"

exit 0