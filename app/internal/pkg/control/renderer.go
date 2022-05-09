package control

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"

	"github.com/arctaruslimited/fractal/app/internal/pkg/utils"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"sigs.k8s.io/yaml"
)

func stripResourceAnnotations(resource *unstructured.Unstructured) {
	// strip off any of our meta annotations
	annotations := resource.GetAnnotations()
	delete(annotations, "fractal.k8s.arctarus.net/flux-layer")
	delete(annotations, "fractal.k8s.arctarus.net/flux-path")
	if len(annotations) > 0 {
		resource.SetAnnotations(annotations)
	} else {
		resource.SetAnnotations(nil)
	}
}

func writeResourcesToDir(resources []unstructured.Unstructured, dir string) error {
	for _, resource := range resources {
		id := ResourceIdentifier(resource)
		stripResourceAnnotations(&resource)

		out, err := yaml.Marshal(resource.Object)
		if err != nil {
			return err
		}

		fp := filepath.Join(dir, fmt.Sprintf("%s.yaml", id))
		err = os.WriteFile(fp, out, os.ModePerm)
		if err != nil {
			return err
		}
	}

	return nil
}

func writeResourcesToFile(resources []unstructured.Unstructured, file string) error {
	f, err := os.Create(file)
	if err != nil {
		return err
	}
	defer f.Close()

	// sort resources by their idents
	keys := make([]string, len(resources))
	attrs := map[string]unstructured.Unstructured{}
	for i, r := range resources {
		rid := ResourceIdentifier(r)

		keys[i] = rid
		attrs[rid] = r
	}
	sort.Strings(keys)

	for i, key := range keys {
		resource := attrs[key]
		stripResourceAnnotations(&resource)

		if i != 0 {
			f.WriteString("---\n")
		}

		bytes, err := yaml.Marshal(resource.Object)
		if err != nil {
			return err
		}

		f.Write(bytes)
	}

	return nil
}

func renderResourcesFlux(resources []unstructured.Unstructured, dir string) error {
	// both flux-layer and flux-path are used now
	partitions := utils.PartitionResourcesByAnnotation("fractal.k8s.arctarus.net/flux-path", resources)

	// create a dir per partition
	for name, pr := range partitions {
		path := filepath.Join(dir, name)
		err := os.MkdirAll(path, os.ModePerm)
		if err != nil {
			return err
		}

		err = writeResourcesToDir(pr, path)
		if err != nil {
			return err
		}
	}

	return nil
}

// Renders cluster resources to a specific directory
func RenderResources(resources []unstructured.Unstructured, dir string, mode string) error {
	err := os.RemoveAll(dir)
	if err != nil {
		return err
	}

	err = os.MkdirAll(dir, os.ModePerm)
	if err != nil {
		return err
	}

	if mode == "flat" {
		err = writeResourcesToFile(resources, filepath.Join(dir, "resources.yaml"))
	} else if mode == "flat-dir" {
		err = writeResourcesToDir(resources, dir)
	} else if mode == "flux" {
		err = renderResourcesFlux(resources, dir)
	} else {
		err = fmt.Errorf("unsupported render mode %s", mode)
	}

	return err
}
