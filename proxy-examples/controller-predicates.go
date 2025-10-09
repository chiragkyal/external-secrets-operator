package controller

import (
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/predicate"
)

// START PREDICATE OMIT
func (r *Reconciler) managedResourcePredicate() predicate.Predicate {
	return predicate.NewPredicateFuncs(func(obj client.Object) bool {
		labels := obj.GetLabels()
		// Only watch ConfigMaps with our app label // HL
		return labels != nil && labels["app"] == "my-application"
	})
}

// END PREDICATE OMIT
