package controller

import (
	"context"

	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// START CONFIGMAP OMIT
func (r *Reconciler) ensureTrustedCAConfigMap(ctx context.Context, ns string) error {
	configMap := &corev1.ConfigMap{
		ObjectMeta: metav1.ObjectMeta{
			Name:      "operand-trusted-ca-bundle",
			Namespace: ns,
			Labels: map[string]string{
				"app": "my-application",
				"config.openshift.io/inject-trusted-cabundle": "true", // HL
			},
		},
		Data: map[string]string{}, // Empty - CNO populates // HL
	}

	// Create or update (only labels, never data!) // HL
	return r.createOrUpdate(ctx, configMap)
}

// END CONFIGMAP OMIT
