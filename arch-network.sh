#!/bin/sh

echo ''
echo '   Setting up networking...'
echo ''


### Initialize arguments
hostname=$1
localdomain=$2

### Generate hosts file
cat << HOSTS > /etc/hosts
127.0.0.1 localhost.$localdomain localhost
::1 localhost.$localdomain localhost
127.0.1.1 $hostname.$localdomain $hostname
HOSTS


### Generate wired network configuration file
cat << WIRED > /etc/systemd/network/wired.network
[Match]
Name=en*

[Network]
DHCP=true

[DHCP]
RouteMetric=10
WIRED


### Generate wireless network configuration file
cat << WIRELESS > /etc/systemd/network/wireless.network
[Match]
Name=wl*

[Network]
DHCP=true

[DHCP]
RouteMetric=20
WIRELESS


### Enable services
systemctl enable systemd-networkd
systemctl enable systemd-resolved


### Enable available interfaces
for i in $(ip link | awk '($2 ~ /^(en|wl)/) {print substr($2, 1, length($2) - 1)}'); do
  ip link set "$i" up
done
