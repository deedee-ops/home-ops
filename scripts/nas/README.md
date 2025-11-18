# NAS

## TrueNAS

Provision:

```bash
curl -sSL https://raw.githubusercontent.com/deedee-ops/home-ops/refs/heads/master/scripts/nas/deploy-truenas.sh | bash -s meemee /mnt/apps/docker
```

Add custom APP YAML, with following contents:

```yaml
include:
  - /mnt/apps/docker/stacks/komodo/docker/stacks/komodo/compose.yaml
name: komodo
services: {}
```

## Unraid

Install `unraid-script` as a user script. Run it in background and schedule every hour.
