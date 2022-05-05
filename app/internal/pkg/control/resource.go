package control

import (
	"strings"

	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
)

func ResourceIdentifier(resource unstructured.Unstructured) string {
	sanitise := func(name string) string {
		name = strings.ReplaceAll(name, "/", "_")
		name = strings.ReplaceAll(name, ":", "-")
		return name
	}

	apiVersion := sanitise(resource.GetAPIVersion())
	kind := sanitise(resource.GetKind())
	namespace := sanitise(resource.GetNamespace())
	name := sanitise(resource.GetName())

	parts := []string{}
	if apiVersion != "" {
		parts = append(parts, apiVersion)
	}
	if kind != "" {
		parts = append(parts, kind)
	}
	if namespace != "" {
		parts = append(parts, namespace)
	}
	if name != "" {
		parts = append(parts, name)
	}

	joined := strings.Join(parts, ".")
	return strings.ToLower(joined)
}
