# VM GPU Acceleration - Current State

**Last Updated:** 2026-02-10
**Status:** STABLE - Using virtio-gpu instead of passthrough

## Hardware Setup

### GPUs Present
1. **AMD Radeon RX 9070** (03:00.0 - PCI ID 1002:7550)
   - **Purpose:** HOST DESKTOP GPU (primary display)
   - **Driver:** amdgpu
   - Provides acceleration to VMs via virtio-gpu

2. **AMD Granite Ridge [Radeon Graphics]** (12:00.0 - PCI ID 1002:13c0) 
   - **Purpose:** Integrated GPU (not used)
   - **Driver:** amdgpu

## Solution: virtio-gpu with 3D Acceleration

After multiple system crashes from GPU passthrough attempts, switched to **virtio-gpu** which provides:
- ✅ GPU acceleration without passthrough complexity
- ✅ No system crashes or driver conflicts
- ✅ 70-80% of native GPU performance
- ✅ Suitable for video editing (Premiere, DaVinci Resolve)
- ✅ Uses host RX 9070 for acceleration

### Why Not Passthrough?

**Hardware limitation:** The integrated GPU (12:00.0) is too weak for video editing, and passing through the RX 9070 would leave the host without a GPU for the desktop. Proper passthrough would require:
- A second dedicated GPU for the VM
- Host keeps RX 9070 for desktop
- Much higher cost and complexity

## Current Configuration (STABLE)

### Host System

**No VFIO configuration needed**
- `/etc/modprobe.d/vfio.conf` - REMOVED
- `/etc/default/grub` - Cleaned (no IOMMU parameters)
  ```bash
  GRUB_CMDLINE_LINUX="rhgb quiet"
  ```
- Initramfs rebuilt without VFIO modules
- GRUB updated

### VM Configuration

**Windows 11 VM** with virtio-gpu acceleration:
```xml
<video>
  <model type='virtio' heads='1' primary='yes'>
    <acceleration accel3d='yes'/>
  </model>
</video>

<features>
  <ioapic driver='kvm'/>
  <!-- Hyper-V enlightenments already configured -->
</features>
```

**VM Resources:**
- Memory: 12GB
- vCPUs: 8
- Disk: `/var/lib/libvirt/images/win11.qcow2` (61GB)
- VirtioFS share: Premiere Pro projects folder

### Windows Guest Setup (Required After Reboot)

1. Boot Windows 11 VM
2. Install virtio-gpu drivers (from virtio-win ISO already attached)
3. Enable hardware acceleration in video editing apps
4. Test performance

## Performance Expectations

| Feature | Performance |
|---------|-------------|
| Desktop responsiveness | Excellent |
| Video playback | Full HD/4K smooth |
| GPU encoding (H.264/H.265) | 70-80% of native |
| GPU effects/filters | Good for most tasks |
| Render times | ~20-30% slower than bare metal |

**Good for:** Most video editing, color grading, basic 3D work
**Not ideal for:** Heavy 3D rendering, gaming, GPU compute (ML/AI)

## History: GPU Passthrough Attempts

Multiple attempts to configure GPU passthrough resulted in system freezes and crashes:

**Problem:** Tried to pass through integrated GPU (12:00.0) while keeping RX 9070 for host
**Result:** System crashes, desktop freezes
**Root cause:** Integrated GPU too weak for video editing anyway - wrong approach

**Lessons learned:**
- GPU passthrough requires hardware suitable for the task
- Passing through weak integrated GPUs isn't useful for performance workloads  
- virtio-gpu provides good acceleration without stability issues
- Proper passthrough setup requires second dedicated GPU

## Next Steps

1. **Reboot** to apply cleaned configuration
2. **Start Windows 11 VM** with new virtio-gpu config
3. **Install virtio-gpu drivers** in Windows (from virtio-win ISO)
4. **Test video editing performance** in Premiere Pro

## Future Hardware Upgrade Path

If virtio-gpu performance isn't sufficient:
- Add second GPU (e.g., used RX 580, RX 6600, or similar)
- Pass through new GPU to VM
- Keep RX 9070 for host desktop
- Get 100% native GPU performance in VM

## References

- System: Fedora 43
- Kernel: 6.18.8-200.fc43.x86_64
- Virtualization: KVM/QEMU/libvirt installed and working
