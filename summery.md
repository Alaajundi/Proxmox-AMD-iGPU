
````markdown
# Proxmox Host Configuration Files

Configuration files and settings for AMD Phoenix3 iGPU passthrough on Proxmox VE host.

---

## GRUB Configuration

**File:** `/etc/default/grub`

```bash
# GRUB_CMDLINE_LINUX_DEFAULT configuration for AMD iGPU passthrough
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt pcie_acs_override=downstream,multifunction"

# Alternative configuration for some systems:
# GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt pci=noaer"

# If using ZFS, you might also need:
# GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt pcie_acs_override=downstream,multifunction rootdelay=10"
```

**Apply changes:**
```bash
update-grub
reboot
```

---

## Kernel Modules Configuration

**File:** `/etc/modules`

```bash
# VFIO modules for GPU passthrough
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd

# Optional: Additional modules
kvmgt
vfio_mdev
```

---

## VFIO PCI Device Binding

**File:** `/etc/modprobe.d/vfio.conf`

```bash
# Bind AMD Phoenix3 GPU and audio to VFIO
options vfio-pci ids=1002:1900,1002:1640

# Alternative format with additional devices:
# options vfio-pci ids=1002:1900,1002:1640,1002:164e

# For multiple GPU systems, specify all device IDs:
# options vfio-pci ids=1002:1900,1002:1640,1002:15e7,1002:1637
```

**Device ID Identification:**
```bash
# Find your specific PCI IDs
lspci -nn | grep -E "(VGA|Audio)" | grep AMD
# Example output:
# c7:00.0 VGA compatible controller [0300]: AMD [1002:1900] (Phoenix3)
# c7:00.1 Audio device [0403]: AMD [1002:1640] (Rembrandt Audio)
```

---

## GPU Driver Blacklist

**File:** `/etc/modprobe.d/blacklist.conf`

```bash
# Blacklist GPU drivers on Proxmox host
blacklist amdgpu
blacklist radeon
blacklist nouveau

# Optional: Blacklist framebuffer drivers
# blacklist efifb
# blacklist vesafb
# blacklist simplefb
```

---

## VM Configuration Template

**File:** `/etc/pve/qemu-server/108.conf` (Example VM ID 108)

```bash
# Basic VM settings
agent: 1
balloon: 0
bios: ovmf
boot: order=scsi0;net0;ide2
cores: 6
cpu: host
machine: q35
memory: 16384
meta: creation-qemu=8.1.5,ctime=1732550400
name: jellyfin-gpu
net0: virtio=BC:24:11:12:34:56,bridge=vmbr0,firewall=1
numa: 1
ostype: l26
parent: gpu-working
scsihw: virtio-scsi-single
smbios1: uuid=12345678-1234-1234-1234-123456789abc

# Storage configuration
scsi0: ZFS-VMs:vm-108-disk-1,iothread=1,size=100G
ide2: ZFS-VMs:vm-108-cloudinit,media=cdrom

# GPU Passthrough Configuration (CRITICAL)
hostpci0: 0000:c7:00.0,pcie=1,romfile=vbios_8745hs.bin
hostpci1: 0000:c7:00.1,pcie=1

# Performance optimizations
args: -cpu host,kvm=off,hv_vendor_id=proxmox
hugepages: 1024

# UEFI settings
efidisk0: ZFS-VMs:vm-108-disk-0,efitype=4m,pre-enrolled-keys=1,size=1M

# Cloud-init (optional)
cicustom: vendor=ZFS-VMs:snippets/vendor.yaml
cipassword: $6$rounds=500000$... (hashed password)
ciuser: ubuntu
ipconfig0: ip=192.168.0.233/24,gw=192.168.0.1
nameserver: 8.8.8.8
searchdomain: local
sshkeys: ssh-rsa AAAAB3NzaC1yc... (your SSH key)
```

**Key Configuration Notes:**

1. **hostpci0** - GPU passthrough with VBIOS file (MANDATORY)
2. **hostpci1** - Audio passthrough 
3. **machine: q35** - Required for PCIe passthrough
4. **bios: ovmf** - UEFI BIOS required
5. **cpu: host** - Pass through host CPU features
6. **args** - KVM hiding for GPU compatibility

---

## VBIOS Files Location

**Directory:** `/usr/share/kvm/`

```bash
# Required VBIOS files for AMD Phoenix series
/usr/share/kvm/vbios_8745hs.bin
/usr/share/kvm/vbios_8845hs.bin  
/usr/share/kvm/vbios_7840hs.bin
/usr/share/kvm/vbios_8645hs.bin  # Copy of 8745hs for your specific CPU

# Download commands:
wget https://github.com/isc30/ryzen-gpu-passthrough-proxmox/raw/main/vbios_8745hs.bin
wget https://github.com/isc30/ryzen-gpu-passthrough-proxmox/raw/main/vbios_8845hs.bin
wget https://github.com/isc30/ryzen-gpu-passthrough-proxmox/raw/main/vbios_7840hs.bin

# Set permissions
chmod 644 /usr/share/kvm/vbios_*.bin
chown root:root /usr/share/kvm/vbios_*.bin
```

---

## Network Configuration Example

**File:** `/etc/network/interfaces` (if using static network)

```bash
# Network interface for VM bridge
auto lo
iface lo inet loopback

auto eno1
iface eno1 inet manual

auto vmbr0
iface vmbr0 inet static
    address 192.168.0.100/24
    gateway 192.168.0.1
    bridge-ports eno1
    bridge-stp off
    bridge-fd 0
    dns-nameservers 8.8.8.8 8.8.4.4
```

---

## Startup Scripts

**File:** `/usr/local/bin/gpu-passthrough-setup.sh`

```bash
#!/bin/bash
# GPU Passthrough Setup Script

echo "Setting up AMD Phoenix3 GPU passthrough..."

# Verify IOMMU is enabled
if ! dmesg | grep -q "AMD-Vi: Found IOMMU"; then
    echo "ERROR: IOMMU not enabled in BIOS or GRUB"
    exit 1
fi

# Check VFIO binding
GPU_PCI="c7:00.0"  # Adjust for your system
if ! lspci -k -s $GPU_PCI | grep -q "vfio-pci"; then
    echo "WARNING: GPU not bound to VFIO-PCI"
    echo "Current driver: $(lspci -k -s $GPU_PCI | grep "Kernel driver in use" | awk '{print $5}')"
fi

# Verify VBIOS files exist
for vbios in vbios_8745hs.bin vbios_8845hs.bin vbios_7840hs.bin; do
    if [ ! -f "/usr/share/kvm/$vbios" ]; then
        echo "WARNING: Missing VBIOS file: $vbios"
    else
        echo "Found VBIOS: $vbios"
    fi
done

echo "GPU passthrough setup verification complete"
```

**Make executable:**
```bash
chmod +x /usr/local/bin/gpu-passthrough-setup.sh
```

---

## System Service for VFIO Setup

**File:** `/etc/systemd/system/vfio-setup.service`

```ini
[Unit]
Description=VFIO GPU Passthrough Setup
After=multi-user.target
Before=qemu-server.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/gpu-passthrough-setup.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

**Enable service:**
```bash
systemctl daemon-reload
systemctl enable vfio-setup.service
```

---

## Verification Commands

```bash
# Check IOMMU groups
find /sys/kernel/iommu_groups/ -name "*c7:00*" 2>/dev/null

# Verify VFIO binding
lspci -k | grep -A 2 -B 2 "vfio-pci"

# Check loaded modules
lsmod | grep vfio

# Verify VM can see GPU
qm monitor 108 -cmd "info pci"
```

---

## Backup Configuration Script

**File:** `/usr/local/bin/backup-gpu-config.sh`

```bash
#!/bin/bash
BACKUP_DIR="/root/gpu-passthrough-backup-$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

# Backup configuration files
cp /etc/default/grub "$BACKUP_DIR/"
cp /etc/modules "$BACKUP_DIR/"
cp -r /etc/modprobe.d/ "$BACKUP_DIR/"
cp /etc/pve/qemu-server/108.conf "$BACKUP_DIR/"

# Backup VBIOS files
cp -r /usr/share/kvm/ "$BACKUP_DIR/"

# Create system info snapshot
lspci -nn > "$BACKUP_DIR/lspci_output.txt"
lsmod > "$BACKUP_DIR/lsmod_output.txt"
dmesg > "$BACKUP_DIR/dmesg_output.txt"

echo "Configuration backed up to: $BACKUP_DIR"
```

---

## Troubleshooting Configuration

**File:** `/usr/local/bin/diagnose-gpu-passthrough.sh`

```bash
#!/bin/bash
echo "=== GPU Passthrough Diagnostics ==="

# System info
echo "Host System:"
uname -a
lscpu | grep "Model name"

# IOMMU status
echo -e "\nIOMU Status:"
dmesg | grep -i iommu | head -3

# VFIO modules
echo -e "\nVFIO Modules:"
lsmod | grep vfio

# GPU binding
echo -e "\nGPU Driver Binding:"
lspci -k | grep -A 3 -B 1 "1002:1900"

# VBIOS files
echo -e "\nVBIOS Files:"
ls -la /usr/share/kvm/vbios_*.bin

# VM configuration
echo -e "\nVM GPU Configuration:"
grep hostpci /etc/pve/qemu-server/108.conf

echo -e "\n=== Diagnostics Complete ==="
```

**This configuration provides a complete Proxmox host setup for AMD Phoenix3 iGPU passthrough with all necessary files and verification scripts.**