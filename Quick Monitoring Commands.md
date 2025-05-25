# Quick GPU status
alias gpu-status='echo "GPU: $(cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null)% | Temp: $(($(cat /sys/class/drm/card*/device/hwmon/hwmon*/temp*_input 2>/dev/null | head -1) / 1000))°C"'

# Jellyfin hardware usage
alias jellyfin-hw='echo "Hardware sessions: $(lsof /dev/dri/renderD128 2>/dev/null | grep -v COMMAND | wc -l)"'

# System performance summary
alias perf-summary='echo "Load: $(uptime | awk -F"load average:" "{print \$2}" | awk "{print \$1}" | tr -d ",") | GPU: $(cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null)% | CPU: $(top -bn1 | grep "Cpu(s)" | awk "{print \$2}" | cut -d"%" -f1)%"'