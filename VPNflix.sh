#!/bin/bash
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run with sudo."
    exit 1
fi
vpn=""
while [[ "$vpn" != "w" && "$vpn" != "o" ]]; do
    echo "Use WireGuard or OpenVPN? (w/o)"
    read vpn
done

apt update
apt upgrade
apt install hostapd dnsmasq

if [[ $vpn == "w" ]]; then
    apt install wireguard
    cp wg0.conf /etc/wireguard/
    systemctl enable wg-quick@wg0
elif [[ $vpn == "o" ]]; then
    apt install openvpn
    cp server.conf /etc/openvpn/
    systemctl enable openvpn@server
fi

systemctl unmask hostapd
systemctl disable hostapd

echo "interface wlan0
    static ip_address=192.168.4.1/24
    nohook wpa_supplicant" >> /etc/dhcpcd.conf

cp hostapd.conf /etc/hostapd/

echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' | tee -a /etc/default/hostapd

mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig

echo -e "interface=wlan0\ndhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h" | tee /etc/dnsmasq.conf

sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf

iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sh -c "iptables-save > /etc/iptables.ipv4.nat"

if ! grep -q "iptables-restore < /etc/iptables.ipv4.nat" /etc/rc.local; then
    sed -i '/^exit 0/i\iptables-restore < \/etc\/iptables.ipv4.nat' /etc/rc.local
fi

systemctl enable hostapd
systemctl enable dnsmasq

echo "Installation complete. Press any key to reboot..."
read -n 1 -s

reboot