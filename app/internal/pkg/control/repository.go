package control

import (
	"encoding/json"
	"fmt"

	"github.com/arctaruslimited/fractal/app/internal/pkg/models"
	"github.com/arctaruslimited/fractal/app/internal/pkg/nix"
)

// Represents a Fractal repository
type Repository struct {
	flake *nix.Flake
}

func NewRepository(path string) Repository {
	flake := nix.NewFlake(path)
	return Repository{
		flake: &flake,
	}
}

// Returns the properties of a single cluster
func (r Repository) GetClusterProperties(cluster string) (*ClusterProperties, error) {
	out, err := r.flake.Eval(fmt.Sprintf("kube._app.clusters.%s", cluster))
	if err != nil {
		return nil, err
	}

	var result ClusterProperties
	err = json.Unmarshal(out, &result)
	if err != nil {
		return nil, err
	}

	return &result, nil
}

// Returns the properties of all clusters
func (r Repository) GetClustersProperties() (map[string]ClusterProperties, error) {
	out, err := r.flake.Eval("kube._app.clusters")
	if err != nil {
		return nil, err
	}

	var result map[string]ClusterProperties
	err = json.Unmarshal(out, &result)
	if err != nil {
		return nil, err
	}

	return result, nil
}

// Returns all resources defined by a cluster
func (r Repository) GetClusterManifests(cluster string) ([]models.Resource, error) {
	out, err := r.flake.Eval(fmt.Sprintf("kube.clusters.%s.manifests", cluster))
	if err != nil {
		return nil, err
	}

	var results []models.Resource
	err = json.Unmarshal(out, &results)
	if err != nil {
		return nil, err
	}

	return results, nil
}
