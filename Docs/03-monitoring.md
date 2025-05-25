# GPU Performance Monitoring Guide

## Real-Time Monitoring Tools

### 1. RadenonTop (Recommended)
```bash
# Install
apt install -y radeontop

# Real-time monitoring (like htop for GPU)
radeontop

# Log to file
radeontop -d /var/log/gpu_stats.log &
```

### 2. Custom Monitoring Scripts

Use the provided scripts in the `scripts/` directory:

```bash
# Quick status check
/usr/local/bin/gpu_monitor.sh

# Jellyfin-specific monitoring
/usr/local/bin/jellyfin_hw_monitor.sh

# Stress testing
/usr/local/bin/stress_test.sh
```

### 3. System Monitoring Commands

```bash
# GPU utilization
cat /sys/class/drm/card*/device/gpu_busy_percent

# GPU temperature
sensors | grep temp

# Active hardware encoding
lsof /dev/dri/renderD128

# VA-API capabilities
vainfo --display drm --device /dev/dri/renderD128
```

## Performance Metrics to Monitor

### Key Indicators
- **GPU Utilization**: 60-90% during active transcoding
- **Temperature**: Should stay under 85°C
- **CPU Usage**: 10-30% (down from 80%+ without hardware acceleration)
- **Memory**: Shared between GPU operations

### Expected Values During Transcoding
| Metric | Idle | Light Load | Heavy Load |
|--------|------|------------|------------|
| GPU Usage | 0-5% | 30-60% | 70-95% |
| Temperature | 35-45°C | 50-65°C | 65-80°C |
| CPU Usage | 5-15% | 15-25% | 20-35% |

## Automated Monitoring Setup

### 1. Continuous Monitoring Service

```bash
# Create systemd service
cat > /etc/systemd/system/gpu-monitor.service << 'EOF'
[Unit]
Description=GPU Performance Monitor
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/local/bin/gpu_monitor.sh
Restart=always
RestartSec=60

[Install]
WantedBy=multi-user.target
EOF

systemctl enable gpu-monitor.service
systemctl start gpu-monitor.service
```

### 2. Cron-based Monitoring

```bash
# Add to crontab
crontab -e

# Monitor every 5 minutes
*/5 * * * * /usr/local/bin/gpu_monitor.sh >> /var/log/gpu_monitor.log 2>&1
```

## Web-based Monitoring

### Install Netdata (Optional)
```bash
bash <(curl -Ss https://my-netdata.io/kickstart.sh) --dont-wait
# Access at: http://VM_IP:19999
```

## Troubleshooting Performance Issues

### Low GPU Utilization
- Check if hardware acceleration is enabled in Jellyfin
- Verify VA-API device path: `/dev/dri/renderD128`
- Check for software fallback in logs

### High Temperature
- Verify cooling system
- Check thermal throttling: `dmesg | grep thermal`
- Monitor sustained workloads

### Inconsistent Performance
- Check for competing applications using GPU
- Monitor system resources during transcoding
- Verify stable driver installation