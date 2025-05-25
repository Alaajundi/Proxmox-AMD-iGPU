cat > /usr/local/bin/gpu_performance_report.sh << 'EOF'
#!/bin/bash
echo "=== AMD Phoenix3 iGPU Performance Report ==="
echo "Generated: $(date)"
echo

# Hardware info
echo "Hardware Configuration:"
lscpu | grep "Model name" | awk -F: '{print "CPU:" $2}'
lspci -d 1002: | head -1 | awk -F: '{print "GPU:" $3}'
echo "Kernel: $(uname -r)"
echo "Mesa: $(apt list --installed 2>/dev/null | grep mesa-amdgpu-va-drivers | awk '{print $2}')"
echo

# Current status
echo "Current Performance:"
gpu_usage=$(cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1)
temp_raw=$(cat /sys/class/drm/card*/device/hwmon/hwmon*/temp*_input 2>/dev/null | head -1)
temp_c=$((${temp_raw:-0} / 1000))
echo "GPU Utilization: ${gpu_usage:-N/A}%"
echo "Temperature: ${temp_c}°C"
echo "Active Sessions: $(lsof /dev/dri/renderD128 2>/dev/null | grep -v COMMAND | wc -l)"

# VA-API capabilities
echo
echo "Hardware Acceleration Capabilities:"
/usr/lib/jellyfin-ffmpeg/vainfo --display drm --device /dev/dri/renderD128 2>/dev/null | grep -E "(VAProfile|VAEntrypoint)" | wc -l | awk '{print "Supported Profiles: " $1}'

# Performance statistics (if log exists)
if [ -f "/var/log/gpu_performance.csv" ]; then
    echo
    echo "Performance Statistics (last 24 hours):"
    tail -n 2880 /var/log/gpu_performance.csv | awk -F, '
    NR>1 {
        gpu_sum+=$2; temp_sum+=$3; sessions_sum+=$10; count++
        if($2>gpu_max) gpu_max=$2
        if($3>temp_max) temp_max=$3
    }
    END {
        if(count>0) {
            printf "Average GPU Usage: %.1f%%\n", gpu_sum/count
            printf "Average Temperature: %.1f°C\n", temp_sum/count
            printf "Peak GPU Usage: %d%%\n", gpu_max
            printf "Peak Temperature: %d°C\n", temp_max
            printf "Total Samples: %d\n", count
        }
    }'
fi
EOF

chmod +x /usr/local/bin/gpu_performance_report.sh