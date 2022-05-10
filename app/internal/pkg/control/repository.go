package control

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"os"
	"path/filepath"

	helmRepo "helm.sh/helm/v3/pkg/repo"
	"sigs.k8s.io/yaml"

	"github.com/arctaruslimited/fractal/app/internal/pkg/models"
	"github.com/arctaruslimited/fractal/app/internal/pkg/nix"
)

// Represents a Fractal repository
type Repository struct {
	path  string
	flake *nix.Flake
}

type RepositoryHelmChart struct {
	Name    string `json:"name"`
	Version string `json:"version"`
	Source  string `json:"source"`
}

type RepositoryHelmData struct {
	Charts  []RepositoryHelmChart `json:"charts"`
	Sources map[string]string     `json:"sources"`
}

type RepositoryHelmLockVersion struct {
	URLs   []string `json:"urls"`
	Digest string   `json:"digest"`
}

// Map of chart versions
type RepositoryHelmLockChart map[string]RepositoryHelmLockVersion

// Map of charts
type RepositoryHelmLockSource map[string]RepositoryHelmLockChart

// Map of sources
type RepositoryHelmLockFile map[string]RepositoryHelmLockSource

func NewRepository(path string) Repository {
	flake := nix.NewFlake(path)
	return Repository{
		path:  path,
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

func (r Repository) LockHelmSources(force bool) error {
	out, err := r.flake.Eval("kube.helm")
	if err != nil {
		return err
	}

	var result RepositoryHelmData
	err = json.Unmarshal(out, &result)
	if err != nil {
		return err
	}

	// read any existing lock file
	lockFile := RepositoryHelmLockFile{}
	lockPath := filepath.Join(r.path, "helm.lock.json")
	if bytes, err := os.ReadFile(lockPath); err == nil {
		err = json.Unmarshal(bytes, &lockFile)
		if err != nil {
			return fmt.Errorf("parsing lockfile: %s", err)
		}
	} else if !os.IsNotExist(err) {
		return fmt.Errorf("reading lockfile: %s", err)
	}

	// download and parse the manifest for each source
	srcs := map[string]helmRepo.IndexFile{}
	for name, url := range result.Sources {
		r, err := http.Get(fmt.Sprintf("%s/index.yaml", url))
		if err != nil {
			return err
		}
		defer r.Body.Close()

		bytes, err := ioutil.ReadAll(r.Body)
		if err != nil {
			return err
		}

		var result helmRepo.IndexFile
		err = yaml.UnmarshalStrict(bytes, &result)
		if err != nil {
			return err
		}
		result.SortEntries()

		srcs[name] = result
	}

	// process the entries into the lockfile
	for _, chart := range result.Charts {
		id := fmt.Sprintf("(%s/%s, %s)", chart.Source, chart.Name, chart.Version)

		var repoSource helmRepo.IndexFile
		if result, ok := srcs[chart.Source]; ok {
			repoSource = result
		} else {
			return fmt.Errorf("%s: no such source was found", id)
		}

		repoVersion, err := repoSource.Get(chart.Name, chart.Version)
		if err != nil {
			return fmt.Errorf("%s: no such chart was found", id)
		}

		lockSource := RepositoryHelmLockSource{}
		if result, ok := lockFile[chart.Source]; ok {
			lockSource = result
		} else {
			lockFile[chart.Source] = lockSource
		}

		lockChart := RepositoryHelmLockChart{}
		if result, ok := lockSource[chart.Name]; ok {
			lockChart = result
		} else {
			lockSource[chart.Name] = lockChart
		}

		// if version already exists, don't overwrite it unless the force flag is given
		if _, ok := lockChart[chart.Version]; ok && !force {
			continue
		}

		lockVersion := RepositoryHelmLockVersion{
			URLs:   repoVersion.URLs,
			Digest: repoVersion.Digest,
		}
		lockChart[chart.Version] = lockVersion
	}

	// write back the lock file
	bytes, err := json.MarshalIndent(lockFile, "", "  ")
	if err != nil {
		return err
	}

	err = os.WriteFile(lockPath, bytes, os.ModePerm)
	if err != nil {
		return err
	}

	return nil
}
