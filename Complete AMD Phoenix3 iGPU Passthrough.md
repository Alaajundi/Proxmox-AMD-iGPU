# Complete AMD Phoenix3 iGPU Passthrough Setup Guide

## Overview
Step-by-step guide to enable AMD Phoenix3 iGPU passthrough from Proxmox VE to Ubuntu VM with full hardware acceleration.

---

## Phase 1: Proxmox Host Configuration

### Step 1: Enable IOMMU and PCIe Passthrough

Edit GRUB configuration:
```bash
nano /etc/default/grub
```

Modify the GRUB_CMDLINE_LINUX_DEFAULT line:
```bash
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt pcie_acs_override=downstream,multifunction"
```

Update GRUB and reboot:
```bash
update-grub
reboot
```

Verify IOMMU is enabled:
```bash
dmesg | grep -i iommu
# Should show: AMD-Vi: Found IOMMU...
```

### Step 2: Configure VFIO Kernel Modules

Add VFIO modules to load at boot:
```bash
echo 'vfio' >> /etc/modules
echo 'vfio_iommu_type1' >> /etc/modules  
echo 'vfio_pci' >> /etc/modules
echo 'vfio_virqfd' >> /etc/modules
```

### Step 3: Identify GPU PCI Information

Find your AMD GPU and audio devices:
```bash
lspci -nn | grep -E "(VGA|Audio)" | grep AMD
```

Example output:
```
c7:00.0 VGA compatible controller [0300]: AMD [1002:1900] (Phoenix3)
c7:00.1 Audio device [0403]: AMD [1002:1640] (Rembrandt Audio)
```

Note the PCI IDs: `1002:1900` (GPU) and `1002:1640` (Audio)

### Step 4: Configure VFIO Device Binding

Create VFIO configuration with your PCI IDs:
```bash
echo "options vfio-pci ids=1002:1900,1002:1640" > /etc/modprobe.d/vfio.conf
```

### Step 5: Blacklist Host GPU Drivers

Prevent Proxmox host from using the GPU:
```bash
echo "blacklist amdgpu" >> /etc/modprobe.d/blacklist.conf
echo "blacklist radeon" >> /etc/modprobe.d/blacklist.conf
```

Update initramfs and reboot:
```bash
update-initramfs -u -k all
reboot
```

### Step 6: Download Required VBIOS Files

**CRITICAL**: AMD Phoenix iGPUs require VBIOS files to initialize properly.

```bash
# Create VBIOS directory
mkdir -p /usr/share/kvm

# Download Phoenix series VBIOS files
cd /usr/share/kvm
wget https://github.com/isc30/ryzen-gpu-passthrough-proxmox/raw/main/vbios_8745hs.bin
wget https://github.com/isc30/ryzen-gpu-passthrough-proxmox/raw/main/vbios_8845hs.bin  
wget https://github.com/isc30/ryzen-gpu-passthrough-proxmox/raw/main/vbios_7840hs.bin

# Set proper permissions
chmod 644 /usr/share/kvm/vbios_*.bin
```

### Step 7: Verify VFIO Binding

Confirm VFIO has successfully bound to your GPU:
```bash
lspci -k -s c7:00.0
```

Expected output:
```
c7:00.0 VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI] Phoenix3
    Kernel driver in use: vfio-pci
    Kernel modules: amdgpu
```

---

## Phase 2: VM Configuration

### Step 8: Create Ubuntu VM

Create a new VM with these specifications:
- **OS**: Ubuntu 24.04 LTS Server or Desktop
- **Machine Type**: q35
- **BIOS**: OVMF (UEFI)
- **CPU**: host (enable all cores)
- **RAM**: 8GB minimum (16GB recommended)
- **Storage**: 50GB minimum

### Step 9: Configure GPU Passthrough

Edit your VM configuration file:
```bash
nano /etc/pve/qemu-server/108.conf
```

Add these essential lines:
```bash
# GPU passthrough with VBIOS (MANDATORY for Phoenix3)
hostpci0: 0000:c7:00.0,pcie=1,romfile=vbios_8745hs.bin
hostpci1: 0000:c7:00.1,pcie=1

# Required VM settings
machine: q35
bios: ovmf
cpu: host
args: -cpu host,kvm=off,hv_vendor_id=proxmox

# Optional performance settings
numa: 1
hugepages: 1024
```

**Critical Note**: The `romfile=vbios_8745hs.bin` parameter is essential to avoid "BIOS signature incorrect" errors.

### Step 10: Start VM and Verify GPU Detection

Start the VM and check if GPU is detected:
```bash
# In Ubuntu VM
lspci | grep VGA
```

Expected output:
```
00:01.0 VGA compatible controller: Device 1234:1111 (rev 02)  # Virtual GPU
01:00.0 VGA compatible controller: AMD [AMD/ATI] Phoenix3 (rev c6)  # Passed-through GPU
```

---

## Phase 3: Ubuntu VM Driver Configuration

### Step 11: Install Hardware Enablement (HWE) Stack

The default Ubuntu 24.04 kernel lacks proper AMD Phoenix3 support. Install the HWE stack:

```bash
# Update system
apt update && apt upgrade -y

# Install HWE kernel for better hardware support
apt install -y linux-generic-hwe-24.04 linux-headers-generic-hwe-24.04

# Reboot to new kernel
reboot
```

Verify new kernel version:
```bash
uname -r
# Should show: 6.11.0-xx-generic or higher
```

### Step 12: Remove Conflicting Drivers

If AMD's DKMS drivers are present, remove them:
```bash
# Check for DKMS conflicts
find /lib/modules/$(uname -r) -name "*amdgpu*"

# Remove DKMS versions if found
apt remove --purge amdgpu-dkms amdgpu-dkms-firmware amdgpu-core
rm -f /lib/modules/$(uname -r)/updates/dkms/amdgpu.ko*
depmod -a
```

### Step 13: Install Ubuntu Native AMD Drivers

Install the distribution-provided drivers:
```bash
# Install AMD graphics drivers
apt install -y xserver-xorg-video-amdgpu mesa-amdgpu-va-drivers
apt install -y libdrm-amdgpu1 mesa-vulkan-drivers mesa-va-drivers
apt install -y vainfo linux-firmware mesa-utils
```

### Step 14: Load and Verify AMD GPU Module

Load the amdgpu kernel module:
```bash
modprobe amdgpu
```

Verify successful loading:
```bash
# Check if module is loaded
lsmod | grep amdgpu

# Verify GPU driver binding
lspci -k | grep -A 3 "01:00.0"
```

Expected output:
```
01:00.0 VGA compatible controller: AMD [AMD/ATI] Phoenix3 (rev c6)
    Subsystem: Device 1f66:0031
    Kernel driver in use: amdgpu
    Kernel modules: amdgpu
```

### Step 15: Verify Hardware Acceleration

Check for DRI devices:
```bash
ls -la /dev/dri/
```

Expected output:
```
crw-rw---- 1 root video  226,   0 May 25 15:10 card0
crw-rw---- 1 root video  226,   1 May 25 15:10 card1  
crw-rw---- 1 root render 226, 128 May 25 15:10 renderD128
```

Test VA-API hardware acceleration:
```bash
vainfo --display drm --device /dev/dri/renderD128
```

Expected output:
```
vainfo: VA-API version: 1.22 (libva 2.22.0)
vainfo: Driver version: Mesa Gallium driver 25.0.6 for AMD Radeon Graphics (radeonsi, phoenix)
vainfo: Supported profile and entrypoints
      VAProfileH264ConstrainedBaseline: VAEntrypointVLD
      VAProfileH264ConstrainedBaseline: VAEntrypointEncSlice
      VAProfileH264Main               : VAEntrypointVLD
      VAProfileH264Main               : VAEntrypointEncSlice
      VAProfileH264High               : VAEntrypointVLD
      VAProfileH264High               : VAEntrypointEncSlice
      VAProfileHEVCMain               : VAEntrypointVLD
      VAProfileHEVCMain               : VAEntrypointEncSlice
      VAProfileHEVCMain10             : VAEntrypointVLD
      VAProfileHEVCMain10             : VAEntrypointEncSlice
      VAProfileJPEGBaseline           : VAEntrypointVLD
      VAProfileVP9Profile0            : VAEntrypointVLD
      VAProfileVP9Profile2            : VAEntrypointVLD
      VAProfileAV1Profile0            : VAEntrypointVLD
      VAProfileAV1Profile0            : VAEntrypointEncSlice
      VAProfileNone                   : VAEntrypointVideoProc
```

---

## Phase 4: Jellyfin Configuration

### Step 16: Install Jellyfin

```bash
# Install Jellyfin
curl -fsSL https://repo.jellyfin.org/install-debuntu.sh | sudo bash
```

### Step 17: Configure Hardware Acceleration

1. Access Jellyfin web interface: `http://VM_IP:8096`
2. Complete initial setup wizard
3. Navigate to: **Dashboard → Playback → Transcoding**
4. Configure these settings:

**Hardware Acceleration Settings:**
- **Hardware acceleration**: `Video Acceleration API (VA-API)`
- **VA-API Device**: `/dev/dri/renderD128`
- **Enable hardware decoding for**: ✅ H.264, H.265, VP9, AV1
- **Enable hardware encoding for**: ✅ H.264, H.265, AV1  
- **Allow encoding in HEVC format**: ✅ Yes
- **Hardware encoding CRF**: 23 (good quality/size balance)
- **Enable VPP Tone mapping**: ✅ Yes (if available)

### Step 18: Set Proper Permissions

Ensure Jellyfin can access the GPU:
```bash
# Add jellyfin user to video and render groups
usermod -a -G video,render jellyfin

# Restart Jellyfin service
systemctl restart jellyfin
systemctl status jellyfin
```

### Step 19: Test Hardware Acceleration

Verify Jellyfin's ffmpeg can use hardware acceleration:
```bash
/usr/lib/jellyfin-ffmpeg/vainfo --display drm --device /dev/dri/renderD128
```

Should show the same hardware encoders as the system vainfo.

---

## Phase 5: Performance Verification

### Step 20: Install Monitoring Tools

```bash
# Install GPU monitoring tools
apt install -y radeontop htop

# Real-time GPU usage (similar to htop for GPU)
radeontop
```

### Step 21: Test Transcoding Performance

1. Upload a test video to Jellyfin
2. Start playback that requires transcoding
3. Monitor performance:

```bash
# Watch GPU utilization
watch -n 1 'echo "GPU: $(cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null)%"'

# Monitor CPU usage
htop
```

**Expected Results During Transcoding:**
- **GPU Usage**: 60-90%
- **CPU Usage**: 10-30% (down from 80%+ without hardware acceleration)
- **Temperature**: 55-75°C
- **Transcoding Speed**: Real-time or faster

---

## Success Criteria

✅ **GPU Detected**: `lspci` shows Phoenix3 GPU  
✅ **Driver Loaded**: `amdgpu` kernel module active  
✅ **Hardware Acceleration**: `vainfo` shows encoders  
✅ **Jellyfin Working**: Transcoding uses <30% CPU  
✅ **Performance**: 10-20x faster than software encoding  

---

## Performance Expectations

### Hardware Acceleration Capabilities:
- **H.264**: Full encode/decode (all profiles)
- **H.265/HEVC**: Full encode/decode (Main, Main10)
- **AV1**: Full encode/decode (future-proof)
- **VP9**: Hardware decode
- **Concurrent Streams**: 5-8 × 1080p or 2-3 × 4K

### Resource Usage:
- **CPU**: 80%+ reduction during transcoding
- **Power**: 90% lower consumption vs software
- **Speed**: 10-20x faster transcoding
- **Quality**: Superior to software encoding

---

**Setup Complete!** Your AMD Phoenix3 iGPU is now providing full hardware acceleration for Jellyfin transcoding.