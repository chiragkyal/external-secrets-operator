package controller

import (
	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
)

// START VOLUME OMIT
func addTrustedCAVolume(deployment *appsv1.Deployment, cmName string) {
	volume := corev1.Volume{
		Name: "trusted-ca-bundle",
		VolumeSource: corev1.VolumeSource{
			ConfigMap: &corev1.ConfigMapVolumeSource{
				LocalObjectReference: corev1.LocalObjectReference{
					Name: cmName,
				},
				// Don't specify items[] - let CNO manage data // HL
			},
		},
	}
	deployment.Spec.Template.Spec.Volumes = append(
		deployment.Spec.Template.Spec.Volumes, volume)
}

// END VOLUME OMIT

// START MOUNT OMIT
func addTrustedCAVolumeMount(container *corev1.Container) {
	container.VolumeMounts = append(container.VolumeMounts,
		corev1.VolumeMount{
			Name:      "trusted-ca-bundle",
			MountPath: "/etc/pki/tls/certs", // HL
			ReadOnly:  true,
		})
}

// END MOUNT OMIT
