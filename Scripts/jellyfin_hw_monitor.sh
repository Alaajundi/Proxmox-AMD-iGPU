#!/bin/bash
# Jellyfin Hardware Acceleration Monitor
# File: /usr/local/bin/jellyfin_hw_monitor.sh

echo "=== Jellyfin Hardware Acceleration Monitor ==="
echo "Timestamp: $(date)"
echo

# Check Jellyfin service status
echo "Jellyfin Service Status:"
systemctl is-active jellyfin
systemctl is-enabled jellyfin
echo

# Check Jellyfin processes
echo "Jellyfin Processes:"
jellyfin_pids=$(pgrep -f jellyfin)
if [ -n "$jellyfin_pids" ]; then
    echo "Active Jellyfin processes:"
    for pid in $jellyfin_pids; do
        ps -p "$pid" -o pid,ppid,%cpu,%mem,cmd --no-headers
    done
else
    echo "No Jellyfin processes running"
fi
echo

# Check FFmpeg processes (transcoding sessions)
echo "Active Transcoding Sessions:"
ffmpeg_pids=$(pgrep ffmpeg)
if [ -n "$ffmpeg_pids" ]; then
    echo "Active FFmpeg processes:"
    for pid in $ffmpeg_pids; do
        cmd=$(ps -p "$pid" -o cmd --no-headers | head -c 100)
        echo "PID $pid: $cmd..."
    done
else
    echo "No active transcoding sessions"
fi
echo

# Hardware acceleration device usage
echo "Hardware Acceleration Usage:"
if [ -c /dev/dri/renderD128 ]; then
    hw_users=$(lsof /dev/dri/renderD128 2>/dev/null)
    if [ -n "$hw_users" ]; then
        echo "Processes using hardware acceleration:"
        echo "$hw_users"
    else
        echo "No processes currently using hardware acceleration"
    fi
else
    echo "Hardware acceleration device not found"
fi
echo

# GPU performance metrics
echo "GPU Performance:"
gpu_usage=$(cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1)
temp=$(cat /sys/class/drm/card*/device/hwmon/hwmon*/temp*_input 2>/dev/null | head -1)
if [ -n "$gpu_usage" ]; then
    echo "GPU Utilization: ${gpu_usage}%"
fi
if [ -n "$temp" ]; then
    temp_c=$((temp / 1000))
    echo "GPU Temperature: ${temp_c}°C"
fi
echo

# System performance
echo "System Performance:"
echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
echo "Memory Usage:"
free -h | grep -E "(Mem|Swap)"
echo

# Check recent Jellyfin logs for hardware acceleration
echo "Recent Jellyfin Hardware Acceleration Activity:"
recent_logs=$(journalctl -u jellyfin --since "5 minutes ago" -n 10 --no-pager 2>/dev/null)
hw_logs=$(echo "$recent_logs" | grep -i -E "(vaapi|hardware|accel|h264_vaapi|hevc_vaapi)")
if [ -n "$hw_logs" ]; then
    echo "$hw_logs"
else
    echo "No recent hardware acceleration activity in logs"
fi
echo

# VA-API test
echo "VA-API Functionality Test:"
if command -v vainfo &> /dev/null; then
    vainfo_output=$(vainfo --display drm --device /dev/dri/renderD128 2>&1)
    if echo "$vainfo_output" | grep -q "VAProfileH264"; then
        echo "✅ VA-API hardware acceleration working"
        encoder_count=$(echo "$vainfo_output" | grep -c "VAEntrypointEncSlice")
        decoder_count=$(echo "$vainfo_output" | grep -c "VAEntrypointVLD")
        echo "   Available encoders: $encoder_count"
        echo "   Available decoders: $decoder_count"
    else
        echo "❌ VA-API hardware acceleration not working"
        echo "Error details:"
        echo "$vainfo_output" | head -5
    fi
else
    echo "vainfo command not available"
fi
echo

# Jellyfin transcoding directory check
echo "Jellyfin Transcoding Directory:"
transcode_dir="/var/lib/jellyfin/transcodes"
if [ -d "$transcode_dir" ]; then
    transcode_files=$(ls -la "$transcode_dir" 2>/dev/null | wc -l)
    transcode_size=$(du -sh "$transcode_dir" 2>/dev/null | cut -f1)
    echo "Transcode files: $((transcode_files - 2))"  # subtract . and ..
    echo "Directory size: $transcode_size"
else
    echo "Transcoding directory not found"
fi

echo
echo "==========================================="

# Optional: Save to log file
if [ "$1" = "--log" ]; then
    log_file="/var/log/jellyfin_hw_monitor.log"
    echo "$(date): Monitor completed" >> "$log_file"
fi