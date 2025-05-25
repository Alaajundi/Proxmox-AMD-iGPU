#!/bin/bash
# AMD GPU Performance Monitor Script
# File: /usr/local/bin/gpu_monitor.sh

echo "=== AMD GPU Performance Monitor ==="
echo "Timestamp: $(date)"
echo

# GPU Information
echo "GPU Information:"
lspci | grep VGA | grep AMD
echo

# GPU Utilization
echo "GPU Utilization:"
gpu_busy=$(cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1)
if [ -n "$gpu_busy" ]; then
    echo "GPU Usage: ${gpu_busy}%"
else
    echo "GPU Usage: Not available"
fi

# GPU Temperature
echo "GPU Temperature:"
temp_files=$(find /sys/class/drm/card*/device/hwmon/hwmon*/temp*_input 2>/dev/null)
if [ -n "$temp_files" ]; then
    for temp_file in $temp_files; do
        temp_raw=$(cat "$temp_file" 2>/dev/null)
        if [ -n "$temp_raw" ]; then
            temp_c=$((temp_raw / 1000))
            echo "Temperature: ${temp_c}°C"
        fi
    done
else
    echo "Temperature: Not available"
fi

# Memory Usage
echo
echo "System Memory:"
free -h | grep -E "(Mem|Swap)"

# GPU Memory (if available)
echo
echo "GPU Memory:"
vram_used=$(cat /sys/class/drm/card*/device/mem_info_vram_used 2>/dev/null | head -1)
vram_total=$(cat /sys/class/drm/card*/device/mem_info_vram_total 2>/dev/null | head -1)
if [ -n "$vram_used" ] && [ -n "$vram_total" ]; then
    vram_used_mb=$((vram_used / 1024 / 1024))
    vram_total_mb=$((vram_total / 1024 / 1024))
    echo "VRAM Used: ${vram_used_mb}MB / ${vram_total_mb}MB"
else
    echo "VRAM info not available"
fi

# Active Hardware Acceleration
echo
echo "Active Hardware Acceleration:"
hw_sessions=$(lsof /dev/dri/renderD128 2>/dev/null)
if [ -n "$hw_sessions" ]; then
    echo "Active sessions:"
    echo "$hw_sessions"
else
    echo "No active hardware encoding sessions"
fi

# DRM Devices
echo
echo "DRM Devices:"
ls -la /dev/dri/ 2>/dev/null || echo "No DRI devices found"

# Jellyfin Process Status
echo
echo "Jellyfin Status:"
if pgrep -f jellyfin > /dev/null; then
    echo "Jellyfin is running"
    jellyfin_cpu=$(ps -p $(pgrep jellyfin) -o %cpu --no-headers 2>/dev/null | head -1)
    jellyfin_mem=$(ps -p $(pgrep jellyfin) -o %mem --no-headers 2>/dev/null | head -1)
    echo "CPU: ${jellyfin_cpu}%, Memory: ${jellyfin_mem}%"
else
    echo "Jellyfin is not running"
fi

echo
echo "==================="