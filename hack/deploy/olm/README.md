# External Secrets Operator OLM Deployment Scripts

This directory contains scripts to build and deploy the External Secrets Operator using OLM (Operator Lifecycle Manager).

## Files

- `deploy.sh` - Main script for building and deploying the operator
- `config.env` - Example configuration file
- `README.md` - This documentation file

## Quick Start

### Using Make Targets (Recommended)

```bash
# Source configuration and build+deploy
source hack/deploy/olm/config.env
make olm-deploy

# Build only (skip deployment)
source hack/deploy/olm/config.env
make olm-deploy-build-only
```

### Direct Script Usage

```bash
# Run with default configuration
./hack/deploy/olm/deploy.sh
```

### Using Configuration File

```bash
# Copy and modify the example configuration
cp hack/deploy/olm/config.env hack/deploy/olm/my-config.env
# Edit hack/deploy/olm/my-config.env with your values

# Source the configuration and run
source hack/deploy/olm/my-config.env
./hack/deploy/olm/deploy.sh
```

## Configuration

The script is configured entirely through environment variables:

| Environment Variable | Default                                                                 | Description                            |
| -------------------- | ----------------------------------------------------------------------- | -------------------------------------- |
| `QUAY_USER_ID`       | `myuser`                                                                | Quay.io user ID for image repositories |
| `CATALOG_NAME`       | `eso-custom-index`                                                      | Name of the catalog source             |
| `VERSION`            | `1.0.0`                                                                 | Version to build and deploy            |
| `CATALOG_IMG`        | `quay.io/${QUAY_USER_ID}/external-secrets-operator-catalog:v${VERSION}` | Catalog image URL                      |
| `IMAGE_TAG_BASE`     | `quay.io/${QUAY_USER_ID}/external-secrets-operator`                     | Base image tag for bundle and catalog  |
| `IMG`                | `quay.io/${QUAY_USER_ID}/external-secrets-operator:v${VERSION}`         | Operator image URL                     |
| `NAMESPACE`          | `openshift-marketplace`                                                 | Namespace to deploy catalog source     |
| `PUBLISHER`          | `Red Hat Stage Testing`                                                 | Publisher name for the catalog         |
| `CONTAINER_TOOL`     | `podman`                                                                | Container tool (podman/docker)         |
| `SKIP_DEPLOY`        | `false`                                                                 | Skip deployment steps                  |

## Examples

### Example 1: Using Make Targets with Default Configuration

```bash
# Source config and deploy
source hack/deploy/olm/config.env
make olm-deploy

# Or build only
source hack/deploy/olm/config.env
make olm-deploy-build-only
```

### Example 2: Using Configuration File

```bash
# Copy and edit the configuration
cp hack/deploy/olm/config.env hack/deploy/olm/my-config.env
# Edit hack/deploy/olm/my-config.env with your values

# Source and run
source hack/deploy/olm/my-config.env
./hack/deploy/olm/deploy.sh
```

### Example 3: Using Environment Variables

```bash
# Set environment variables
export QUAY_USER_ID=myuser
export VERSION=1.1.0
export CATALOG_NAME=my-eso-catalog

# Run with environment variables
./hack/deploy/olm/deploy.sh
```

### Example 4: Build Only, Skip Deployment

```bash
# Set SKIP_DEPLOY and run
export SKIP_DEPLOY=true
export QUAY_USER_ID=myuser
./hack/deploy/olm/deploy.sh
```

## What the Script Does

The script performs the following steps:

1. **Prerequisites Check**: Verifies required tools are available
2. **Build Phase**:
   - Runs `make update build`
   - Builds and pushes operator image: `make docker-build docker-push`
   - Builds and pushes bundle image: `make bundle-build bundle-push`
   - Builds and pushes catalog image: `make catalog-build catalog-push`
3. **Deploy Phase** (unless `SKIP_DEPLOY=true`):
   - Creates and applies CatalogSource to OpenShift/Kubernetes
   - Waits for CatalogSource to be ready
4. **Post-deployment**: Shows next steps for installing the operator

## Prerequisites

- `make` command
- Container tool (`podman` or `docker`)
- OpenShift CLI (`oc`) or Kubernetes CLI (`kubectl`)
- Access to push images to the specified registry
- Access to deploy to the target OpenShift/Kubernetes cluster

## Post-Deployment

After successful deployment, you can:

1. **Verify the catalog source**:
   ```bash
   oc get catalogsource eso-custom-index -n openshift-marketplace
   ```

2. **Check available packages**:
   ```bash
   oc get packagemanifests | grep external-secrets
   ```

3. **Install via Web Console**: Navigate to OperatorHub and search for "External Secrets"

4. **Install via CLI**: Create a Subscription resource:
   ```yaml
   apiVersion: operators.coreos.com/v1alpha1
   kind: Subscription
   metadata:
     name: external-secrets-operator
     namespace: external-secrets-operator-system
   spec:
     channel: stable
     name: external-secrets-operator
     source: eso-custom-index
     sourceNamespace: openshift-marketplace
   ```

## Troubleshooting

### Common Issues

1. **Permission denied errors**: Ensure you have push access to the registry
2. **CatalogSource not ready**: Check network connectivity and image pull permissions
3. **Build failures**: Ensure all dependencies are available and up to date

### Debugging Commands

```bash
# Check catalog source status
oc describe catalogsource eso-custom-index -n openshift-marketplace

# Check operator installation
oc get csv -n external-secrets-operator-system
oc get pods -n external-secrets-operator-system

# Check logs
oc logs -n openshift-marketplace deployment/eso-custom-index
```

## Contributing

When modifying the script, please:

1. Test with `--dry-run` first
2. Update this documentation if adding new options
3. Ensure error handling is maintained
4. Test with both `podman` and `docker` if possible
