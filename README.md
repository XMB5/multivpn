# multivpn

MultiVPN allows multiple OpenVPN instances to run simultaneously and provides a simple mechanism to use all of them at once.

## How it works
The normal flow of an OpenVPN connection looks like
1. The client it creates a virtual network interface.
2. The server will send an IP address for the client to use.
3. The client will assign this IP address to the virtual network device.
4. The client changes routing tables to send all connections through this device.
5. Once the connection is done, revert all changes to the routing table and delete the virtual network device.

MultiVPN modifies steps 3 and 4 of this process.
Instead of assigning the server-generated IP address to the client's virtual device, MultiVPN uses whatever IP address the user passes
through the `custom_local_address` environment variable. This prevents IP address collisions if different servers assign
the same IP address to different OpenVPN clients. This modification works on the client side, however,
the server will expect packets from the IP address it assigned. To fix this, MultiVPN uses `iptables SNAT`, which will
change the IP address of all packets to use the server-generated address. Next, MultiVPN skips step 4, the step which
routes all traffic through the VPN, because multiple VPN connections will add conflicting entries to the routing table
which will prevent them from working. Instead, MultiVPN creates a separate routing table for each VPN connection.
MultiVPN instructs linux to use a different routing table for each virtual network device. This way, connections can be
made to the same IP address from different network devices by binding to the device's IP address.

## How to use
1. Clone this repository anywhere on your machine (`git clone https://github.com/XMB5/multivpn`)
2. At the end of an OpenVPN command, add
```
--route-noexec --ifconfig-noexec --script-security 2 \
--route-up path/to/multivpn/route-up.sh --route-pre-down path/to/multivpn/route-down.sh \
--setenv custom_local_address 100.64.0.1 --setenv route_table 200
```
3. To use the OpenVPN connection create a connection bound to 100.64.0.1, for example `curl --interface 100.64.0.1 https://ipinfo.io/`

## Limitations
- currently only supports IPv4
- only for linux

## License
    MultiVPN, a program to use multiple OpenVPN connections on one computer.
    Copyright (C) 2019 Sam Foxman
    
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
    
    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.
    
    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.