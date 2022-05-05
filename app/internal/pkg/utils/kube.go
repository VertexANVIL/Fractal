package utils

import "k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"

func PartitionResourcesByAnnotation(annotation string, resources []unstructured.Unstructured) map[string][]unstructured.Unstructured {
	buckets := make(map[string][]unstructured.Unstructured)
	for _, resource := range resources {
		annotations := resource.GetAnnotations()
		if value, ok := annotations[annotation]; ok {
			var bucket []unstructured.Unstructured
			if bucket, ok = buckets[value]; !ok {
				bucket = []unstructured.Unstructured{}
				buckets[value] = bucket
			}

			// strip the annotation
			annotations := resource.GetAnnotations()
			delete(annotations, annotation)
			if len(annotations) > 0 {
				resource.SetAnnotations(annotations)
			} else {
				resource.SetAnnotations(nil)
			}

			// append the resource
			buckets[value] = append(bucket, resource)
		}
	}

	return buckets
}
