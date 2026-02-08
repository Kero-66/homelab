
# Usenet Provider Setup — Easynews

This guide helps you configure **Easynews** in **SABnzbd**.

---

## 1. Primary Server Details

Use these details for the primary server in either application:

- **Host:** `news.easynews.com`
- **Port:** `563` (SSL) or `119` (Non-SSL)
- **SSL:** Enabled (Recommended)
- **Connections:** `20` (Recommended limit for Easynews)
- **Username:** `YOUR_EASYNEWS_USERNAME`
- **Password:** `YOUR_EASYNEWS_PASSWORD`

---

## 2. Configuration in SABnzbd

1. Open SABnzbd Web UI (default: [http://localhost:8085](http://localhost:8085)).
2. Go to **Config** (cog icon) -> **Servers**.
3. Click **Add Server**.
4. Enter the details from above:
   - **Host:** `news.easynews.com`
   - **Username:** Your username.
   - **Password:** Your password.
   - **SSL:** Check the box.
   - **Port:** `563`.
5. Click **Test Server**.
6. Click **Add**.

---

## Automation Setup

Don't forget to connect your download client to **Sonarr** and **Radarr**:

1. Go to **Settings** -> **Download Clients** in Sonarr/Radarr.
2. Add **SABnzbd**.
3. Use the IP address specified in your `.env` (e.g., `172.39.0.13` for SABnzbd).
