# deedee cluster

## schematic

```yaml
customization:
    extraKernelArgs:
        - i915.enable_guc=3
        - intel_iommu=on
        - iommu=pt
        - net.ifnames=0
        - sysctl.kernel.kexec_load_disabled=1
        - talos.auditd.disabled=1
        - -lockdown
        - lockdown=integrity
    systemExtensions:
        officialExtensions:
            - siderolabs/i915
            - siderolabs/intel-ucode
            - siderolabs/thunderbolt
```
