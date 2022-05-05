package control

import (
	"encoding/json"
	"fmt"

	"github.com/arctaruslimited/fractal/app/internal/pkg/nix"
)

type Repository struct {
	flake *nix.Flake
}

func NewRepository(path string) Repository {
	flake := nix.NewFlake(path)
	return Repository{
		flake: &flake,
	}
}

func (r Repository) GetClusters() (map[string]Cluster, error) {
	out, err := r.flake.Eval("kube._app.clusters")
	if err != nil {
		return nil, err
	}

	var result map[string]Cluster
	err = json.Unmarshal(out, &result)
	if err != nil {
		return nil, err
	}

	return result, nil
}

func (r Repository) ValidateCluster(cluster string) (*ValidationResult, error) {
	out, err := r.flake.Eval(fmt.Sprintf("kube.clusters.%s.validation", cluster))
	if err != nil {
		return nil, err
	}

	var result ValidationResult
	err = json.Unmarshal(out, &result)
	if err != nil {
		return nil, err
	}

	return &result, nil
}
