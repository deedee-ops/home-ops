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
        - -consoleblank
        - consoleblank=15
        - -init_on_alloc
        - -init_on_free
        - -selinux
        - apparmor=0
        - init_on_alloc=0
        - init_on_free=0
        - mitigations=off
        - security=none
    systemExtensions:
        officialExtensions:
            - siderolabs/i915
            - siderolabs/intel-ucode
            - siderolabs/thunderbolt
```
