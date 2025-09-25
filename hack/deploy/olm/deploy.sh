#!/usr/bin/env bash

# External Secrets Operator OLM Build and Deploy Script
# This script builds and deploys the External Secrets Operator using OLM (Operator Lifecycle Manager)
#
# Configuration is done via environment variables. See hack/deploy/olm/config.env for an example.
# Usage:
#   source hack/deploy/olm/config.env
#   ./hack/deploy/olm/deploy.sh

set -euo pipefail

# Configuration via environment variables
QUAY_USER_ID="${QUAY_USER_ID}"
CATALOG_NAME="${CATALOG_NAME:-eso-custom-index}"
VERSION="${VERSION:-1.0.0}"
CATALOG_IMG="${CATALOG_IMG:-quay.io/${QUAY_USER_ID}/external-secrets-operator-catalog:v${VERSION}}"
IMAGE_TAG_BASE="${IMAGE_TAG_BASE:-quay.io/${QUAY_USER_ID}/external-secrets-operator}"
IMG="${IMG:-quay.io/${QUAY_USER_ID}/external-secrets-operator:v${VERSION}}"
NAMESPACE="${NAMESPACE:-openshift-marketplace}"
PUBLISHER="${PUBLISHER:-Red Hat Stage Testing}"
CONTAINER_TOOL="${CONTAINER_TOOL:-podman}"
PLATFORM="${PLATFORM:-linux/amd64}"
SKIP_DEPLOY="${SKIP_DEPLOY:-false}"

# Function to execute commands with description
execute_cmd() {
    local cmd="$1"
    local description="${2:-}"
    
    if [[ -n "$description" ]]; then
        echo "$description"
    fi
    
    echo "Executing: $cmd"
    eval "$cmd"
}

# Function to build operator
build_operator() {
    echo "Building External Secrets Operator..."
    
    # Update and build
    execute_cmd "make update build" "Updating manifests and building operator binary"
    
    # Build and push operator image
    execute_cmd "$CONTAINER_TOOL build --platform $PLATFORM -t $IMG ." "Building operator image for $PLATFORM"
    execute_cmd "make docker-push IMG=$IMG CONTAINER_TOOL=$CONTAINER_TOOL" "Pushing operator image"
    
    # Build and push bundle image
    execute_cmd "make bundle IMAGE_TAG_BASE=$IMAGE_TAG_BASE VERSION=$VERSION IMG=$IMG" "Generating bundle manifests"
    execute_cmd "$CONTAINER_TOOL build --platform $PLATFORM -f bundle.Dockerfile -t $IMAGE_TAG_BASE-bundle:v$VERSION ." "Building bundle image for $PLATFORM"
    execute_cmd "make bundle-push IMAGE_TAG_BASE=$IMAGE_TAG_BASE VERSION=$VERSION CONTAINER_TOOL=$CONTAINER_TOOL" "Pushing bundle image"
    
    # Build and push catalog image
    execute_cmd "make opm" "Ensuring opm tool is available"
    
    # Check current architecture for compatibility warning
    local current_arch=$(uname -m)
    local target_arch=""
    case $PLATFORM in
        "linux/amd64") target_arch="x86_64" ;;
        "linux/arm64") target_arch="aarch64" ;;
        *) target_arch="unknown" ;;
    esac
    
    if [[ "$current_arch" != "$target_arch" && "$target_arch" != "unknown" ]]; then
        echo "Warning: Building catalog on $current_arch for $PLATFORM target"
        echo "This may result in architecture mismatch issues in OpenShift"
        echo "Consider building on a $target_arch machine for best results"
    fi
    
    # Build catalog directly with opm (architecture will match the host)
    if command -v docker &> /dev/null; then
        execute_cmd "./bin/opm index add --container-tool docker --mode semver --tag $CATALOG_IMG --bundles $IMAGE_TAG_BASE-bundle:v$VERSION" "Building catalog image with opm"
    else
        echo "Warning: docker not found, creating temporary docker alias for podman..."
        execute_cmd "ln -sf \$(which podman) /tmp/docker && export PATH=/tmp:\$PATH" "Creating temporary docker alias"
        execute_cmd "./bin/opm index add --container-tool docker --mode semver --tag $CATALOG_IMG --bundles $IMAGE_TAG_BASE-bundle:v$VERSION" "Building catalog image with opm"
        execute_cmd "rm -f /tmp/docker" "Cleaning up temporary docker alias"
    fi
    
    execute_cmd "make catalog-push IMAGE_TAG_BASE=$IMAGE_TAG_BASE VERSION=$VERSION CATALOG_IMG=$CATALOG_IMG CONTAINER_TOOL=$CONTAINER_TOOL" "Pushing catalog image"
    
    echo "Operator build completed successfully"
}

# Function to deploy catalog source
deploy_catalog_source() {
    if [[ "$SKIP_DEPLOY" == "true" ]]; then
        echo "Skipping deployment steps"
        return 0
    fi
    
    echo "Deploying CatalogSource to OpenShift..."
    
    # Determine kubectl command
    local kubectl_cmd="oc"
    if ! command -v oc &> /dev/null; then
        kubectl_cmd="kubectl"
    fi
    
    # Create CatalogSource YAML
    local catalog_yaml=$(cat << EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: $CATALOG_NAME
  namespace: $NAMESPACE
spec:
  sourceType: grpc
  image: $CATALOG_IMG
  displayName: $CATALOG_NAME
  publisher: $PUBLISHER
EOF
)
    
    echo "Applying CatalogSource:"
    echo "$catalog_yaml"
    echo "$catalog_yaml" | $kubectl_cmd apply -f -
    
    # Wait for catalog source to be ready
    echo "Waiting for CatalogSource to be ready..."
    $kubectl_cmd wait --for=condition=Ready catalogsource/$CATALOG_NAME -n $NAMESPACE --timeout=300s || {
        echo "Warning: CatalogSource may not be ready yet. Check status manually with:"
        echo "  $kubectl_cmd get catalogsource $CATALOG_NAME -n $NAMESPACE"
    }
    
    echo "CatalogSource deployment completed"
}

# Function to show post-deployment instructions
show_post_deployment_info() {
    echo "Deployment completed successfully!"
    echo
    echo "Next steps:"
    echo "1. Verify the CatalogSource is ready:"
    echo "   oc get catalogsource $CATALOG_NAME -n $NAMESPACE"
    echo
    echo "2. Check available operators:"
    echo "   oc get packagemanifests | grep external-secrets"
    echo
    echo "3. Install the operator via Subscription:"
    cat << EOF
   
   apiVersion: operators.coreos.com/v1alpha1
   kind: Subscription
   metadata:
     name: external-secrets-operator
     namespace: external-secrets-operator
   spec:
     channel: stable
     name: external-secrets-operator
     source: $CATALOG_NAME
     sourceNamespace: $NAMESPACE

4. Monitor the installation:
   oc get csv -n external-secrets-operator
   oc get pods -n external-secrets-operator

EOF
}

# Function to clean up on error
cleanup_on_error() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        echo "Error: Script failed with exit code $exit_code"
        echo "You may want to clean up any partially created resources"
    fi
    exit $exit_code
}


# Set up error handling
trap cleanup_on_error ERR

# Main execution
main() {
    echo "External Secrets Operator OLM Build and Deploy Script"
    echo "============================================================"
    echo
    echo "Configuration:"
    echo "  Quay User ID:     $QUAY_USER_ID"
    echo "  Catalog Name:     $CATALOG_NAME"
    echo "  Catalog Image:    $CATALOG_IMG"
    echo "  Image Tag Base:   $IMAGE_TAG_BASE"
    echo "  Version:          $VERSION"
    echo "  Operator Image:   $IMG"
    echo "  Namespace:        $NAMESPACE"
    echo "  Publisher:        $PUBLISHER"
    echo "  Container Tool:   $CONTAINER_TOOL"
    echo "  Platform:         $PLATFORM"
    echo "  Skip Deploy:      $SKIP_DEPLOY"
    echo
    
    # Execute main workflow
    build_operator
    deploy_catalog_source
    show_post_deployment_info
}

# Run main function
main
