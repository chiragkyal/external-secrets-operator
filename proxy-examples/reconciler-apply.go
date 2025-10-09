package controller

import (
	appsv1 "k8s.io/api/apps/v1"
)

// START APPLY OMIT
func applyProxyToDeployment(deployment *appsv1.Deployment,
	proxy *ProxyConfig, caConfigMapName string) {

	addTrustedCAVolume(deployment, caConfigMapName)

	// Apply to all containers // HL
	for i := range deployment.Spec.Template.Spec.Containers {
		setProxyEnvVars(&deployment.Spec.Template.Spec.Containers[i], proxy)
		addTrustedCAVolumeMount(&deployment.Spec.Template.Spec.Containers[i])
	}

	// Don't forget init containers! // HL
	for i := range deployment.Spec.Template.Spec.InitContainers {
		setProxyEnvVars(&deployment.Spec.Template.Spec.InitContainers[i], proxy)
		addTrustedCAVolumeMount(&deployment.Spec.Template.Spec.InitContainers[i])
	}
}

// END APPLY OMIT
