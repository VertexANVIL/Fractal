package models

import (
	"encoding/json"
	"strings"

	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
)

type ResourceValidation struct {
	// Type of the result (warning or error)
	Type string `json:"type"`

	// Output from the validator, if present
	Message string `json:"message"`
}

type Resource struct {
	unstructured.Unstructured
}

func (r Resource) Identifier() string {
	sanitise := func(name string) string {
		name = strings.ReplaceAll(name, "/", "_")
		name = strings.ReplaceAll(name, ":", "-")
		return name
	}

	apiVersion := sanitise(r.GetAPIVersion())
	kind := sanitise(r.GetKind())
	namespace := sanitise(r.GetNamespace())
	name := sanitise(r.GetName())

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

func (r Resource) Validation() ResourceValidation {
	var result ResourceValidation
	bytes, _ := json.Marshal(r.Object["_validation"])
	json.Unmarshal(bytes, &result)
	return result
}

// Returns the resource stripped of control fields
func (r Resource) Minified() map[string]interface{} {
	object := r.Object
	delete(object, "_validation")

	return object
}
