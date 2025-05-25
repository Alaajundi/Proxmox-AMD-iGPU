cat > /usr/local/bin/gpu_temp_alert.sh << 'EOF'
#!/bin/bash
TEMP_THRESHOLD=80
TEMP_RAW=$(cat /sys/class/drm/card*/device/hwmon/hwmon*/temp*_input 2>/dev/null | head -1)
TEMP_C=$((${TEMP_RAW:-0} / 1000))

if [ "$TEMP_C" -gt "$TEMP_THRESHOLD" ]; then
    echo "WARNING: GPU temperature is ${TEMP_C}°C (threshold: ${TEMP_THRESHOLD}°C)" | logger -t gpu-alert
    # Optional: Send notification or email
fi
EOF

chmod +x /usr/local/bin/gpu_temp_alert.sh

# Add to crontab for monitoring every minute
echo "* * * * * /usr/local/bin/gpu_temp_alert.sh" | crontab -