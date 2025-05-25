# GRUB_CMDLINE_LINUX_DEFAULT configuration for AMD iGPU passthrough
# Copy this to /etc/default/grub

# Original line (comment out):
# GRUB_CMDLINE_LINUX_DEFAULT="quiet"

# Modified line for AMD iGPU passthrough:
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt pcie_acs_override=downstream,multifunction"

# After modifying, run:
# update-grub
# reboot