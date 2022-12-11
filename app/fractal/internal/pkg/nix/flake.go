package nix

import (
	"fmt"
	"os/exec"
	"strings"

	"github.com/arctaruslimited/fractal/app/internal/pkg/models"
)

var Config = models.NixConfig{}

// Wrapper around Nix commands for a flake
type Flake struct {
	path string
}

func NewFlake(path string) Flake {
	return Flake{
		path: path,
	}
}

func (f Flake) invokeNix(args ...string) ([]byte, error) {
	// append our flake overrides to the args
	for key, path := range Config.FlakeOverrides {
		args = append(args, []string{"--override-input", key, path}...)
	}

	out, err := exec.Command(Config.Binary, args...).Output()

	if err != nil {
		if exitError, ok := err.(*exec.ExitError); ok {
			fullCmd := strings.Join(args, " ")
			return nil, fmt.Errorf("invoking Nix with parameters `%s`:\n%s", fullCmd, exitError.Stderr)
		} else {
			return nil, err
		}
	}

	return out, nil
}

// Evaluates a Nix expression
func (f Flake) Eval(key string) ([]byte, error) {
	uri := fmt.Sprintf("%s#%s", f.path, key)
	args := []string{"eval", uri, "--json"}
	out, err := f.invokeNix(args...)
	if err != nil {
		return nil, err
	}

	return out, nil
}
