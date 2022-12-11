package utils

import (
	"github.com/arctaruslimited/fractal/app/internal/pkg/models"
)

func PartitionResourcesByAnnotation(annotation string, resources []models.Resource) map[string][]models.Resource {
	buckets := make(map[string][]models.Resource)
	for _, resource := range resources {
		value := "_orphans"
		annotations := resource.GetAnnotations()
		if result, ok := annotations[annotation]; ok {
			value = result
		}

		var bucket []models.Resource
		if result, ok := buckets[value]; ok {
			bucket = result
		} else {
			bucket = []models.Resource{}
			buckets[value] = bucket
		}

		// append the resource
		buckets[value] = append(bucket, resource)
	}

	return buckets
}
