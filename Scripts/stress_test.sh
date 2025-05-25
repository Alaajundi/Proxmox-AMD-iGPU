#!/bin/bash
# AMD GPU Stress Test Script
# File: /usr/local/bin/stress_test.sh

echo "=== AMD GPU Stress Test ==="
echo "Starting stress test at $(date)"
echo

# Check prerequisites
if ! command -v vainfo &> /dev/null; then
    echo "Error: vainfo not found. Install with: apt install vainfo"
    exit 1
fi

if [ ! -c /dev/dri/renderD128 ]; then
    echo "Error: Hardware acceleration device not found"
    exit 1
fi

# Test 1: Basic VA-API functionality
echo "Test 1: VA-API Hardware Detection"
vainfo --display drm --device /dev/dri/renderD128
echo

# Test 2: GPU temperature baseline
echo "Test 2: Temperature Baseline"
temp_start=$(cat /sys/class/drm/card*/device/hwmon/hwmon*/temp*_input 2>/dev/null | head -1)
temp_start_c=$((temp_start / 1000))
echo "Starting temperature: ${temp_start_c}°C"
echo

# Test 3: Create test video for transcoding
echo "Test 3: Creating test video..."
test_video="/tmp/test_4k.mp4"
if [ ! -f "$test_video" ]; then
    ffmpeg -f lavfi -i testsrc2=duration=60:size=3840x2160:rate=30 \
           -c:v libx264 -preset ultrafast -y "$test_video" 2>/dev/null
    echo "Test video created: $test_video"
fi

# Test 4: Hardware encoding stress test
echo "Test 4: Hardware Encoding Stress Test"
output_dir="/tmp/gpu_stress_output"
mkdir -p "$output_dir"

echo "Starting multiple concurrent hardware encodes..."
for i in {1..3}; do
    echo "Starting encode session $i..."
    /usr/lib/jellyfin-ffmpeg/ffmpeg \
        -hwaccel vaapi \
        -hwaccel_device /dev/dri/renderD128 \
        -i "$test_video" \
        -c:v h264_vaapi \
        -b:v 5M \
        -y "$output_dir/output_$i.mp4" &
done

# Monitor during stress test
echo "Monitoring for 30 seconds..."
for j in {1..30}; do
    sleep 1
    gpu_usage=$(cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null)
    temp_current=$(cat /sys/class/drm/card*/device/hwmon/hwmon*/temp*_input 2>/dev/null | head -1)
    temp_current_c=$((temp_current / 1000))
    printf "\rTime: %2ds | GPU: %s%% | Temp: %s°C" "$j" "$gpu_usage" "$temp_current_c"
done
echo

# Wait for encodes to complete
echo "Waiting for encodes to complete..."
wait

# Final temperature check
temp_end=$(cat /sys/class/drm/card*/device/hwmon/hwmon*/temp*_input 2>/dev/null | head -1)
temp_end_c=$((temp_end / 1000))
temp_delta=$((temp_end_c - temp_start_c))

echo
echo "=== Stress Test Results ==="
echo "Starting temperature: ${temp_start_c}°C"
echo "Peak temperature: ${temp_end_c}°C"
echo "Temperature increase: ${temp_delta}°C"

# Check output files
echo
echo "Encode Results:"
for i in {1..3}; do
    output_file="$output_dir/output_$i.mp4"
    if [ -f "$output_file" ]; then
        size=$(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file")
        size_mb=$((size / 1024 / 1024))
        echo "Session $i: SUCCESS (${size_mb}MB)"
    else
        echo "Session $i: FAILED"
    fi
done

# Cleanup
echo
echo "Cleaning up test files..."
rm -f "$test_video"
rm -rf "$output_dir"

echo "Stress test completed at $(date)"
echo "=========================="