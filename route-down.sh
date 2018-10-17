#!/bin/bash

echo "route-down > dev: $dev  rt_table: $rt_table  custom_local_address: $custom_local_address  \
ifconfig_local: $ifconfig_local  route_vpn_gateway: $route_vpn_gateway  tun_mtu: $tun_mtu"

iptables -t nat -D POSTROUTING --source "$custom_local_address" -j SNAT --to-source "$ifconfig_local"

ip rule del from "$custom_local_address/32" table "$rt_table"
ip rule del to "$route_vpn_gateway/32" table "$rt_table"
ip route del default via "$custom_local_address" dev "$dev" table "$rt_table"
ip route flush cache