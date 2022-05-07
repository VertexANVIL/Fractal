package utils

import "k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"

func PartitionResourcesByAnnotation(annotation string, resources []unstructured.Unstructured) map[string][]unstructured.Unstructured {
	buckets := make(map[string][]unstructured.Unstructured)
	for _, resource := range resources {
		value := "_orphans"
		annotations := resource.GetAnnotations()
		if result, ok := annotations[annotation]; ok {
			value = result
		}

		var bucket []unstructured.Unstructured
		if result, ok := buckets[value]; ok {
			bucket = result
		} else {
			bucket = []unstructured.Unstructured{}
			buckets[value] = bucket
		}

		// strip the annotation
		delete(annotations, annotation)
		if len(annotations) > 0 {
			resource.SetAnnotations(annotations)
		} else {
			resource.SetAnnotations(nil)
		}

		// append the resource
		buckets[value] = append(bucket, resource)
	}

	return buckets
}
