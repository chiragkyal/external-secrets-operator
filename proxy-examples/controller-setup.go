package controller

import (
	corev1 "k8s.io/api/core/v1"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/builder"
	"sigs.k8s.io/controller-runtime/pkg/handler"
	"sigs.k8s.io/controller-runtime/pkg/predicate"
)

// START SETUP OMIT
func (r *Reconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&myv1.MyCustomResource{}).
		// Watch ConfigMap METADATA only // HL
		WatchesMetadata( // HL
			&corev1.ConfigMap{},
			handler.EnqueueRequestsFromMapFunc(r.findOwner),
			builder.WithPredicates(
				predicate.LabelChangedPredicate{}, // Label changes only // HL
				r.managedResourcePredicate(),      // Our resources only // HL
			),
		).
		Complete(r)
}

// END SETUP OMIT
