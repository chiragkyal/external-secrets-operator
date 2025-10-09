package controller

import (
	"os"

	corev1 "k8s.io/api/core/v1"
)

type ProxyConfig struct {
	HTTPProxy  string
	HTTPSProxy string
	NoProxy    string
}

// START GETPROXY OMIT
func (r *Reconciler) getProxyConfig() *ProxyConfig {
	// Read from OLM-injected environment variables // HL
	return &ProxyConfig{
		HTTPProxy:  os.Getenv("HTTP_PROXY"),
		HTTPSProxy: os.Getenv("HTTPS_PROXY"),
		NoProxy:    os.Getenv("NO_PROXY"),
	}
}

// END GETPROXY OMIT

// START SETENV OMIT
func setProxyEnvVars(container *corev1.Container, proxy *ProxyConfig) {
	// Set both uppercase and lowercase for compatibility // HL
	if proxy.HTTPProxy != "" {
		container.Env = append(container.Env,
			corev1.EnvVar{Name: "HTTP_PROXY", Value: proxy.HTTPProxy},
			corev1.EnvVar{Name: "http_proxy", Value: proxy.HTTPProxy}, // HL
		)
	}
	// ... repeat for HTTPS_PROXY and NO_PROXY
}

// END SETENV OMIT
