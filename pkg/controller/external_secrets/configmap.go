package external_secrets

import (
	"context"
	"fmt"

	corev1 "k8s.io/api/core/v1"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/types"

	operatorv1alpha1 "github.com/openshift/external-secrets-operator/api/v1alpha1"
)

// ensureTrustedCABundleConfigMap creates or ensures the trusted CA bundle ConfigMap exists
// in the operand namespace when proxy configuration is present. The ConfigMap is labeled
// with the injection label required by the Cluster Network Operator (CNO), which watches
// for this label and injects the cluster's trusted CA bundle into the ConfigMap's data.
// This function ensures the correct labels are present so that CNO can manage the CA bundle
// content as expected.
func (r *Reconciler) ensureTrustedCABundleConfigMap(esc *operatorv1alpha1.ExternalSecretsConfig, resourceLabels map[string]string) error {
	proxyConfig := r.getProxyConfiguration(esc)

	// Only create ConfigMap if proxy is configured
	if proxyConfig == nil {
		return nil
	}

	namespace := getNamespace(esc)
	expectedLabels := getTrustedCABundleLabels(resourceLabels)

	configMap := &corev1.ConfigMap{
		ObjectMeta: metav1.ObjectMeta{
			Name:      trustedCABundleConfigMapName,
			Namespace: namespace,
			Labels:    expectedLabels,
		},
		Data: map[string]string{
			// CNO will inject the actual CA bundle content
			// We initialize with empty content
		},
	}

	// Check if the ConfigMap already exists
	existingConfigMap := &corev1.ConfigMap{}
	err := r.Get(context.TODO(), types.NamespacedName{Name: trustedCABundleConfigMapName, Namespace: namespace}, existingConfigMap)

	if err != nil {
		if apierrors.IsNotFound(err) {
			// Create the ConfigMap
			if err := r.Create(context.TODO(), configMap); err != nil {
				return fmt.Errorf("failed to create trusted CA bundle ConfigMap: %w", err)
			}
			return nil
		}
		return fmt.Errorf("failed to get trusted CA bundle ConfigMap: %w", err)
	}

	// ConfigMap exists, ensure it has the correct labels
	// Do not update the data of the ConfigMap since it is managed by CNO
	if existingConfigMap.Labels == nil {
		existingConfigMap.Labels = make(map[string]string)
	}

	expectedLabels = getTrustedCABundleLabels(resourceLabels)
	needsUpdate := false
	for k, expectedValue := range expectedLabels {
		if existingConfigMap.Labels[k] != expectedValue {
			existingConfigMap.Labels[k] = expectedValue
			needsUpdate = true
		}
	}

	// Update the ConfigMap if any labels changed
	if needsUpdate {
		if err := r.Update(context.TODO(), existingConfigMap); err != nil {
			return fmt.Errorf("failed to update trusted CA bundle ConfigMap labels: %w", err)
		}
	}

	return nil
}

// getTrustedCABundleLabels merges resource labels with the injection label
func getTrustedCABundleLabels(resourceLabels map[string]string) map[string]string {
	labels := make(map[string]string)
	for k, v := range resourceLabels {
		labels[k] = v
	}
	labels[trustedCABundleInjectLabel] = "true"
	return labels
}
