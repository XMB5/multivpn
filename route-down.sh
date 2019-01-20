#!/bin/bash

# This file is part of MultiVPN.
#
# MultiVPN is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Foobar is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Foobar.  If not, see <https://www.gnu.org/licenses/>.

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