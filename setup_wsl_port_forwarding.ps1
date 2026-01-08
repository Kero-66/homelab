# WSL2 Port Forwarding Script for Jellyfin and Media Services
# Run this in PowerShell as Administrator on Windows

# Get WSL IP address
$wslIp = (wsl hostname -I).Trim()
Write-Host "WSL IP: $wslIp"

# Get Windows IP address
$windowsIp = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.InterfaceAlias -like "*Ethernet*" -or $_.InterfaceAlias -like "*Wi-Fi*"} | Select-Object -First 1).IPAddress
Write-Host "Windows IP: $windowsIp"

# Remove existing port proxies
Write-Host "`nRemoving existing port forwarding rules..."
netsh interface portproxy reset

# Jellyfin ports
Write-Host "`nSetting up Jellyfin port forwarding..."
netsh interface portproxy add v4tov4 listenport=8096 listenaddress=0.0.0.0 connectport=8096 connectaddress=$wslIp
netsh interface portproxy add v4tov4 listenport=7359 listenaddress=0.0.0.0 connectport=7359 connectaddress=$wslIp
netsh interface portproxy add v4tov4 listenport=1900 listenaddress=0.0.0.0 connectport=1900 connectaddress=$wslIp

# Media services ports
Write-Host "Setting up media services port forwarding..."
netsh interface portproxy add v4tov4 listenport=8989 listenaddress=0.0.0.0 connectport=8989 connectaddress=$wslIp  # Sonarr
netsh interface portproxy add v4tov4 listenport=7878 listenaddress=0.0.0.0 connectport=7878 connectaddress=$wslIp  # Radarr
netsh interface portproxy add v4tov4 listenport=8686 listenaddress=0.0.0.0 connectport=8686 connectaddress=$wslIp  # Lidarr
netsh interface portproxy add v4tov4 listenport=9696 listenaddress=0.0.0.0 connectport=9696 connectaddress=$wslIp  # Prowlarr
netsh interface portproxy add v4tov4 listenport=6767 listenaddress=0.0.0.0 connectport=6767 connectaddress=$wslIp  # Bazarr
netsh interface portproxy add v4tov4 listenport=8080 listenaddress=0.0.0.0 connectport=8080 connectaddress=$wslIp  # qBittorrent
netsh interface portproxy add v4tov4 listenport=6789 listenaddress=0.0.0.0 connectport=6789 connectaddress=$wslIp  # NZBGet
netsh interface portproxy add v4tov4 listenport=5055 listenaddress=0.0.0.0 connectport=5055 connectaddress=$wslIp  # Jellyseerr
netsh interface portproxy add v4tov4 listenport=3002 listenaddress=0.0.0.0 connectport=3002 connectaddress=$wslIp  # Jellystat

# Configure Windows Firewall
Write-Host "`nConfiguring Windows Firewall..."
New-NetFirewallRule -DisplayName "Jellyfin-HTTP" -Direction Inbound -LocalPort 8096 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "Jellyfin-Discovery" -Direction Inbound -LocalPort 7359 -Protocol UDP -Action Allow -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "Jellyfin-DLNA" -Direction Inbound -LocalPort 1900 -Protocol UDP -Action Allow -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "Sonarr" -Direction Inbound -LocalPort 8989 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "Radarr" -Direction Inbound -LocalPort 7878 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "Lidarr" -Direction Inbound -LocalPort 8686 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "Prowlarr" -Direction Inbound -LocalPort 9696 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "Bazarr" -Direction Inbound -LocalPort 6767 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "qBittorrent" -Direction Inbound -LocalPort 8080 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "NZBGet" -Direction Inbound -LocalPort 6789 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "Jellyseerr" -Direction Inbound -LocalPort 5055 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "Jellystat" -Direction Inbound -LocalPort 3002 -Protocol TCP -Action Allow -ErrorAction SilentlyContinue

Write-Host "`n✅ Port forwarding setup complete!"
Write-Host "`nCurrent port proxy configuration:"
netsh interface portproxy show all

Write-Host "`n📱 Your devices should now be able to connect to:"
Write-Host "   Jellyfin: http://$windowsIp`:8096"
Write-Host "`n💡 If this doesn't work, make sure:"
Write-Host "   1. Your TV/phone are on the same network"
Write-Host "   2. Windows Defender Firewall is not blocking the connections"
Write-Host "   3. Run this script again if you restart WSL (the IP might change)"
