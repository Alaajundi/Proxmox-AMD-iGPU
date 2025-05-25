# Simple real-time dashboard
watch -n 1 'echo "=== GPU Dashboard $(date) ==="; 
echo "GPU Usage: $(cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null)%";
echo "Temperature: $(($(cat /sys/class/drm/card*/device/hwmon/hwmon*/temp*_input 2>/dev/null | head -1) / 1000))°C";
echo "Active HW Sessions: $(lsof /dev/dri/renderD128 2>/dev/null | grep -v COMMAND | wc -l)";
echo "System Load: $(uptime | awk -F"load average:" "{print \$2}" | awk "{print \$1}" | tr -d ",")";
echo "Memory: $(free -h | grep Mem | awk "{print \$3 \"/\" \$2}")";
echo "Jellyfin Status: $(systemctl is-active jellyfin)"'