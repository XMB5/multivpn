netmask_to_netbits() {
    #https://github.com/OpenVPN/openvpn/blob/14d7e0e496f15563005fffc6d4791a95444ddf23/src/openvpn/route.c#L4041
    #function returns prefix for given netmask in arg1
    #from https://stackoverflow.com/a/50414560
    bits=0
    for octet in $(echo $1| sed 's/\./ /g'); do
         binbits=$(echo "obase=2; ibase=10; ${octet}"| bc | sed 's/0//g')
         let bits+=${#binbits}
    done
    echo "${bits}"
}

if [ -n "$custom_local_address" ]; then
    orig_ifconfig_local="$ifconfig_local"
    ifconfig_local="$custom_local_address"
    ifconfig_netmask=255.255.255.255
fi