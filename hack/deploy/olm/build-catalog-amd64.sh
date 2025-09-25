#!/usr/bin/env bash

# Alternative script to build catalog for amd64 specifically
# This can be used if the main script doesn't work

set -euo pipefail

# Configuration
BUNDLE_IMG=${1:-"quay.io/ckyal/external-secrets-operator-bundle:v1.0.0"}
CATALOG_IMG=${2:-"quay.io/ckyal/external-secrets-operator-catalog:v1.0.0"}
PLATFORM=${3:-"linux/amd64"}

echo "Building catalog image for $PLATFORM"
echo "Bundle: $BUNDLE_IMG"
echo "Catalog: $CATALOG_IMG"

# Method 1: Use Docker buildx if available
if command -v docker &> /dev/null && docker buildx version &> /dev/null; then
    echo "Using Docker buildx for cross-platform build..."
    
    # Create temporary builder
    docker buildx create --name catalog-builder --use || true
    
    # Create temporary Dockerfile that uses opm
    cat > /tmp/catalog-build.Dockerfile << EOF
FROM quay.io/operator-framework/opm:latest as opm
WORKDIR /build
RUN opm index add --bundles $BUNDLE_IMG --tag catalog --generate
FROM scratch
COPY --from=opm /build/index.yaml /index.yaml
COPY --from=opm /build/database /database
ENTRYPOINT ["/bin/opm"]
CMD ["serve", "/build"]
EOF
    
    # Build for specific platform
    docker buildx build --platform $PLATFORM -f /tmp/catalog-build.Dockerfile -t $CATALOG_IMG --push .
    
    # Cleanup
    docker buildx rm catalog-builder || true
    rm -f /tmp/catalog-build.Dockerfile
    
# Method 2: Use emulation with podman/docker
elif command -v podman &> /dev/null; then
    echo "Using podman with platform emulation..."
    
    # Enable emulation if needed
    if [[ "$PLATFORM" != "$(uname -m)" ]]; then
        echo "Warning: Building for different architecture, this may be slow"
    fi
    
    # Build temporary catalog
    temp_catalog="temp-catalog-$(date +%s)"
    
    # Use podman to run opm in a container for the target platform
    podman run --rm --platform $PLATFORM \
        -v $(pwd):/workspace:Z \
        -w /workspace \
        quay.io/operator-framework/opm:latest \
        index add --bundles $BUNDLE_IMG --tag $temp_catalog --container-tool podman
    
    # Tag and push
    podman tag $temp_catalog $CATALOG_IMG
    podman push $CATALOG_IMG
    podman rmi $temp_catalog || true
    
else
    echo "Error: Neither docker nor podman found"
    exit 1
fi

echo "Catalog image built successfully: $CATALOG_IMG"
echo "Verify architecture with: podman inspect $CATALOG_IMG --format '{{.Architecture}}'"
