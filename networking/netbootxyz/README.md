Quick notes for running netboot.xyz in this repo

Overview
- This compose runs `netbootxyz/netboot.xyz` in `network_mode: host` so it can bind DHCP/TFTP/ProxyDHCP (UDP 67/69/4011) and serve PXE on the LAN.

Important safety notes
- Host DHCP/TFTP must be stopped before starting this container (otherwise the container can't bind ports).
- `network_mode: host` gives the container direct access to host networking; use only on trusted hosts.

Steps to run (on your Docker host)

1) Stop any running dnsmasq/isc-dhcp-server processes. If a service is running, stop it:

```bash
sudo systemctl stop dnsmasq isc-dhcp-server || true
sudo systemctl disable dnsmasq isc-dhcp-server || true
```

If you see a user process (example from your system: PID 37593), kill it:

```bash
sudo ps -fp 37593
sudo kill 37593
# or more forcefully if it doesn't stop:
# sudo pkill -f dnsmasq
```

2) Verify UDP ports are free:

```bash
sudo ss -u -lpn | grep -E ':67|:68|:69|:4011' || true
```

3) Start the container (from this directory):

```bash
cd networking/netbootxyz
docker compose up -d
```

4) Check logs and listeners:

```bash
docker compose logs -f netbootxyz
sudo ss -u -lpn | grep -E ':67|:68|:69|:4011' || true
```

5) Capture DHCP/TFTP/ProxyDHCP traffic while testing a PXE boot (replace `enp10s0` with your LAN interface):

```bash
sudo tcpdump -n -i enp10s0 'udp and (port 67 or port 69 or port 4011)' -vv
```

6) Test HTTP/TFTP from another machine on the LAN:

```bash
curl -I http://<host-ip>/
# TFTP example (replace path/file with an actual small file in /tftp):
# tftp -v <host-ip> -c get <file>
```

If you prefer macvlan instead of host networking, reply with:
- the host LAN interface name (example: `enp10s0`)
- your LAN subnet (example: `192.168.1.0/24`)
- gateway (example: `192.168.1.1`)
- an unused IP to assign the container (example: `192.168.1.100`)

I'll generate a macvlan compose variant if you need that.
