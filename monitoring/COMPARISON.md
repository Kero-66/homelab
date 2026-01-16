# Beszel vs Netdata Comparison

Quick setup for comparing monitoring solutions side-by-side.

## Access URLs
- **Beszel**: http://localhost:8090
- **Netdata**: http://localhost:19999

## Quick Start

```bash
cd /mnt/library/repos/homelab/monitoring
docker compose -f compose-comparison.yaml up -d
```

## Initial Setup

### Beszel
1. Access http://localhost:8090
2. Create admin account
3. Copy the agent key from the UI
4. Update `.env` with `BESZEL_KEY=<your-key>`
5. Restart: `docker compose -f compose-comparison.yaml up -d`

### Netdata
1. Access http://localhost:19999
2. Works immediately - no configuration needed
3. (Optional) Sign up for Netdata Cloud for multi-node monitoring

## Comparison Checklist

### Performance
- [ ] CPU usage of each tool
- [ ] Memory footprint
- [ ] Disk I/O impact

### Features
- [ ] Real-time metrics granularity
- [ ] Docker container monitoring
- [ ] GPU monitoring (AMD 9070)
- [ ] Disk/filesystem monitoring
- [ ] Network monitoring
- [ ] Alerting capabilities
- [ ] Historical data retention

### User Experience
- [ ] Dashboard responsiveness
- [ ] Mobile/responsive design
- [ ] Customization options
- [ ] Ease of setup
- [ ] Alert configuration

### Integration
- [ ] Prometheus export
- [ ] Grafana integration
- [ ] API access
- [ ] Multi-node support

## Stop and Clean Up

```bash
# Stop both
docker compose -f compose-comparison.yaml down

# Remove all data
docker compose -f compose-comparison.yaml down -v
```

## Notes
- Beszel is lightweight, focused on simplicity
- Netdata is comprehensive, with extensive plugin ecosystem
- Both support Docker monitoring out of the box
