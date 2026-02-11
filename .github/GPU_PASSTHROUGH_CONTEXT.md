# GPU Passthrough Configuration - Session Context

**CRITICAL: READ THIS FIRST IN EVERY NEW SESSION**

## User Context
- User has experienced **multiple desktop crashes** during GPU passthrough configuration attempts
- User is **frustrated with having to repeat context** across sessions
- **DO NOT attempt GPU passthrough changes without reading this file first**

## Hardware Configuration

### System Details
- **OS:** Fedora 43 (Kernel 6.18.8-200.fc43.x86_64)
- **Platform:** AMD Ryzen with integrated graphics
- **Virtualization:** KVM/QEMU/libvirt installed and working

### GPU Setup (CRITICAL - DO NOT CONFUSE THESE)

1. **AMD Radeon RX 9070** (PCI 03:00.0 - ID 1002:7550)
   - **Role:** HOST DESKTOP GPU (user's primary display)
   - **Driver:** amdgpu (must stay on amdgpu)
   - **Audio:** 1002:ab40
   - **IOMMU Group:** 14 (isolated)
   - **Status:** NEVER pass this through - it powers the desktop!

2. **AMD Granite Ridge [Radeon Graphics]** (PCI 12:00.0 - ID 1002:13c0)
   - **Role:** VM PASSTHROUGH TARGET (integrated GPU)
   - **Driver:** Should be vfio-pci (for VM use)
   - **Audio:** 1002:1640
   - **IOMMU Group:** 29 (isolated)
   - **Status:** This is the GPU to pass through to VMs

### Virtual Machines
- Windows 11 VM exists: `/var/lib/libvirt/images/win11.qcow2` (61GB)
- Windows 11 backup: `/var/lib/libvirt/images/win11-1.qcow2` (31GB)

## Configuration Applied (2026-02-10)

### What Was Changed

1. **File:** `/etc/modprobe.d/vfio.conf`
   ```
   options vfio-pci ids=1002:13c0,1002:1640
   ```
   - Binds integrated GPU (12:00.0) and its audio to vfio-pci
   - Backup at: `/etc/modprobe.d/vfio.conf.backup`

2. **File:** `/etc/default/grub`
   ```
   GRUB_CMDLINE_LINUX="rhgb quiet amd_iommu=on iommu=pt vfio-pci.ids=1002:13c0,1002:1640"
   ```
   - Enables AMD IOMMU
   - Uses passthrough mode (iommu=pt)
   - Pre-binds integrated GPU to vfio-pci at boot
   - Backup at: `/etc/default/grub.backup`

3. **Initramfs:** Rebuilt with vfio modules
   ```bash
   dracut --force --add-drivers "vfio vfio_iommu_type1 vfio_pci"
   ```

4. **GRUB:** Updated bootloader configuration
   ```bash
   grub2-mkconfig -o /boot/grub2/grub.cfg
   ```

### Previous Mistake (FIXED)
- **OLD (WRONG):** `vfio-pci ids=1002:7550,1002:ab40` - This bound the RX 9070
- **NEW (CORRECT):** `vfio-pci ids=1002:13c0,1002:1640` - This binds the integrated GPU

## Expected State After Reboot

### Normal Boot
```bash
# RX 9070 - Desktop GPU (should be on amdgpu)
$ lspci -ks 03:00.0
03:00.0 VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI] Navi 48 [Radeon RX 9070/9070 XT/9070 GRE]
        Kernel driver in use: amdgpu

# Integrated GPU - For VMs (should be on vfio-pci)
$ lspci -ks 12:00.0
12:00.0 VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI] Granite Ridge [Radeon Graphics]
        Kernel driver in use: vfio-pci
```

### Verification Commands
```bash
# Check GPU drivers
lspci -k | grep -A 3 VGA

# Verify IOMMU is enabled
dmesg | grep -i iommu

# Check vfio bound devices
dmesg | grep vfio

# List IOMMU groups
for d in /sys/kernel/iommu_groups/*/devices/*; do 
    n=${d#*/iommu_groups/*}; n=${n%%/*}
    printf 'IOMMU Group %s ' "$n"
    lspci -nns "${d##*/}"
done | grep -E 'Group (14|29)'
```

## Recovery Procedures

### If System Crashes or No Display After Reboot

#### Option 1: Boot with GRUB Edit (Temporary)
1. Reboot and press ESC/Shift at GRUB menu
2. Select boot entry and press 'e' to edit
3. Find the line starting with `linux` or `linuxefi`
4. Remove: `amd_iommu=on iommu=pt vfio-pci.ids=1002:13c0,1002:1640`
5. Optionally add: `nomodeset` (if display issues)
6. Press Ctrl+X or F10 to boot
7. This is temporary - will work for one boot only

#### Option 2: Full Rollback (Permanent Fix)
```bash
# Restore backup configurations
sudo cp /etc/modprobe.d/vfio.conf.backup /etc/modprobe.d/vfio.conf
sudo cp /etc/default/grub.backup /etc/default/grub

# Rebuild initramfs
sudo dracut --force

# Update GRUB
sudo grub2-mkconfig -o /boot/grub2/grub.cfg

# Reboot
sudo reboot
```

#### Option 3: Nuclear Option (Remove All VFIO)
```bash
# Remove vfio configuration completely
sudo rm /etc/modprobe.d/vfio.conf

# Reset GRUB to vanilla defaults
sudo sed -i 's/GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX="rhgb quiet"/' /etc/default/grub

# Rebuild everything
sudo dracut --force
sudo grub2-mkconfig -o /boot/grub2/grub.cfg

# Reboot
sudo reboot
```

## Crash History

1. **First Attempt:** Desktop crashed - configuration bound wrong GPU (RX 9070)
2. **Second Attempt:** Desktop crashed - same issue, context lost
3. **Third Attempt (2026-02-10):** Configuration corrected to bind integrated GPU
   - **Status:** Awaiting reboot to verify

## Next Steps (Post-Reboot)

### If Boot Successful
1. Verify integrated GPU is on vfio-pci: `lspci -ks 12:00.0`
2. Verify RX 9070 is on amdgpu: `lspci -ks 03:00.0`
3. Check desktop display is working on RX 9070
4. Configure Windows 11 VM to use passed-through integrated GPU

### If Boot Failed
1. Use recovery procedures above
2. Check kernel logs: `journalctl -xb -p err`
3. Investigate dmesg: `dmesg | grep -i 'vfio\|iommu\|amdgpu'`
4. Update this document with failure details

## Important Notes for Future Sessions

1. **ALWAYS check this file before making GPU changes**
2. **RX 9070 = Desktop GPU = Never touch = Must stay on amdgpu**
3. **Integrated GPU = VM GPU = Pass through = Should be on vfio-pci**
4. **Backups exist** at `.backup` extensions in `/etc/`
5. **User is frustrated** - avoid repeating mistakes, document everything

## Related Documentation

- Main technical docs: `/mnt/library/repos/homelab/docs/GPU_PASSTHROUGH_STATE.md`
- This context file: `/mnt/library/repos/homelab/.github/GPU_PASSTHROUGH_CONTEXT.md`

## Quick Reference

| Device | PCI ID | PCI Address | Purpose | Driver |
|--------|--------|-------------|---------|--------|
| RX 9070 | 1002:7550 | 03:00.0 | Desktop | amdgpu |
| RX 9070 Audio | 1002:ab40 | 03:00.1 | Desktop Audio | snd_hda_intel |
| Integrated GPU | 1002:13c0 | 12:00.0 | VM Passthrough | vfio-pci |
| iGPU Audio | 1002:1640 | 12:00.1 | VM Audio | vfio-pci |

**Last Updated:** 2026-02-10
**Status:** Configuration applied, awaiting reboot verification
**Reboot Required:** YES
